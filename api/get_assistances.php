<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}

try {
    require_once __DIR__ . "/../backend/config/config.php";

    // Get query parameters
    $status = isset($_GET['status']) ? trim($_GET['status']) : '';
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';

    // Base query
    $sql = "SELECT 
                id,
                vessel_name,
                call_sign,
                master_name,
                flag,
                gross_tonnage,
                agency,
                loa,
                fore_draft,
                aft_draft,
                assist_tug_name,
                from_where,
                to_where,
                date as assistance_date,
                assistance_start,
                assistance_end,
                engine_power,
                notes,
                status
            FROM assistance_logs
            WHERE 1=1";

    $params = [];
    $types = "";

    // Add status filter if provided
    if (!empty($status)) {
        $sql .= " AND status = ?";
        $params[] = $status;
        $types .= "s";
    }

    // Add search filter if provided (search in vessel_name, call_sign, agency, tug_name)
    if (!empty($search)) {
        $sql .= " AND (vessel_name LIKE ? OR call_sign LIKE ? OR agency LIKE ? OR assist_tug_name LIKE ?)";
        $searchParam = "%" . $search . "%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $params[] = $searchParam;
        $params[] = $searchParam;
        $types .= "ssss";
    }

    // Order by date descending (newest first)
    $sql .= " ORDER BY date DESC, assistance_start DESC";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    // Bind parameters if any
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $data = [];

    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    $stmt->close();
    $conn->close();

    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => $data,
        "count" => count($data)
    ]);

} catch (Exception $e) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage(),
        "data" => []
    ]);
}