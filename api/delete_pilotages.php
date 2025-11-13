<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}

try {
    require_once __DIR__ . "/../config/config.php";

    $data = json_decode(file_get_contents("php://input"), true);

    if (!$data) {
        throw new Exception("Invalid JSON data");
    }

    $id = $data["id"] ?? 0;

    if (empty($id)) {
        throw new Exception("ID tidak valid");
    }

    $sql = "DELETE FROM pilotage_logs WHERE id = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed");

    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data berhasil dihapus"
        ]);
    } else {
        throw new Exception("Execute failed");
    }

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