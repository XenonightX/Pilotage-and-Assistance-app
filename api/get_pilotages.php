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
    require_once __DIR__ . "/../config/config.php";

    $status = $_GET['status'] ?? '';
    $search = $_GET['search'] ?? '';

    $sql = "SELECT * FROM pilotage_logs WHERE 1=1";
    $params = [];
    $types = "";

    if (!empty($status) && $status !== 'Semua') {
        $sql .= " AND status = ?";
        $params[] = $status;
        $types .= "s";
    }

    if (!empty($search)) {
        $sql .= " AND (vessel_name LIKE ? OR pilot_name LIKE ?)";
        $searchParam = "%$search%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $types .= "ss";
    }

    $sql .= " ORDER BY tanggal DESC, pilot_on_board DESC";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed");

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();

    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => $data
    ]);

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}