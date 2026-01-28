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
    // Database connection (sesuai config.php Anda)
    $servername = "localhost";
    $username = "root";
    $password = "";
    $dbname = "pilotage_and_assistance_app";
    
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Database connection failed: " . $conn->connect_error);
    }
    
    $conn->set_charset("utf8mb4");

    // Get parameters
    $status = $_GET['status'] ?? '';
    $search = $_GET['search'] ?? '';
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $limit = isset($_GET['limit']) ? max(1, intval($_GET['limit'])) : 10;
    
    // Calculate offset
    $offset = ($page - 1) * $limit;

    // Build WHERE clause for both queries
    $whereClause = " WHERE 1=1";
    $params = [];
    $types = "";

    if (!empty($status) && $status !== 'Semua') {
        $whereClause .= " AND status = ?";
        $params[] = $status;
        $types .= "s";
    }

    if (!empty($search)) {
        $whereClause .= " AND (vessel_name LIKE ? OR pilot_name LIKE ?)";
        $searchParam = "%$search%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $types .= "ss";
    }

    // Query 1: Count total records
    $countSql = "SELECT COUNT(*) as total FROM activity_logs" . $whereClause;
    $stmtCount = $conn->prepare($countSql);
    
    if (!$stmtCount) {
        throw new Exception("Count prepare failed: " . $conn->error);
    }

    if (!empty($params)) {
        $stmtCount->bind_param($types, ...$params);
    }

    $stmtCount->execute();
    $countResult = $stmtCount->get_result();
    $totalRecords = $countResult->fetch_assoc()['total'];
    $stmtCount->close();

    // Query 2: Get paginated data
    $dataSql = "SELECT * FROM activity_logs" . $whereClause;
    $dataSql .= " ORDER BY date DESC, pilot_on_board DESC, id DESC";
    $dataSql .= " LIMIT ? OFFSET ?";

    $stmtData = $conn->prepare($dataSql);
    if (!$stmtData) {
        throw new Exception("Data prepare failed: " . $conn->error);
    }

    // Bind parameters including LIMIT and OFFSET
    $limitOffsetTypes = $types . "ii"; // Add two integers for LIMIT and OFFSET
    $allParams = array_merge($params, [$limit, $offset]);
    
    if (!empty($allParams)) {
        $stmtData->bind_param($limitOffsetTypes, ...$allParams);
    }

    $stmtData->execute();
    $result = $stmtData->get_result();

    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = $row;
    }

    $stmtData->close();
    $conn->close();

    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => $data,
        "total" => intval($totalRecords),
        "page" => $page,
        "limit" => $limit,
        "total_pages" => ceil($totalRecords / $limit)
    ]);

} catch (Exception $e) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}