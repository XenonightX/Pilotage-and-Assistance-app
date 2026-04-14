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

function getPilots(mysqli $conn, string $extraWhere = ''): array
{
    $sql = "SELECT id, name FROM users 
            WHERE LOWER(TRIM(COALESCE(role, ''))) IN ('pilot', 'pandu')
            AND TRIM(COALESCE(name, '')) <> ''
            $extraWhere
            ORDER BY name ASC";
    $result = $conn->query($sql);
    if (!$result) {
        throw new Exception("Query failed: " . $conn->error);
    }

    $data = [];
    while ($row = $result->fetch_assoc()) {
        $data[] = [
            "id" => (int) $row["id"],
            "name" => $row["name"],
        ];
    }

    return $data;
}

try {
    require_once __DIR__ . "/../backend/config/config.php";
    $data = getPilots($conn);

    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => $data,
    ]);
} catch (Exception $e) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage(),
    ]);
}
