<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, PUT, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}

try {
    require_once __DIR__ . "/../backend/config/config.php";

    $data = json_decode(file_get_contents("php://input"), true);

    if (!$data) {
        throw new Exception("Invalid JSON data");
    }

    $id = $data["id"] ?? 0;
    $vessel_name = $data["vessel_name"] ?? '';
    $pilot_name = $data["pilot_name"] ?? '';
    $from_where = $data["from_where"] ?? '';
    $to_where = $data["to_where"] ?? '';
    $tanggal = $data["tanggal"] ?? '';
    $pilot_on_board = $data["pilot_on_board"] ?? '';
    $pilot_finished = $data["pilot_finished"] ?? null;
    $vessel_start = $data["vessel_start"] ?? null;
    $pilot_get_off = $data["pilot_get_off"] ?? null;
    $status = $data["status"] ?? 'Terjadwal';

    if (empty($id) || empty($vessel_name) || empty($pilot_name)) {
        throw new Exception("Data tidak lengkap");
    }

    $sql = "UPDATE pilotage_logs SET 
            vessel_name = ?, 
            pilot_name = ?, 
            from_where = ?, 
            to_where = ?, 
            tanggal = ?, 
            pilot_on_board = ?, 
            pilot_finished = ?, 
            vessel_start = ?, 
            pilot_get_off = ?, 
            status = ? 
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed");

    $stmt->bind_param("ssssssssssi", $vessel_name, $pilot_name, $from_where, $to_where, $tanggal, $pilot_on_board, $pilot_finished, $vessel_start, $pilot_get_off, $status, $id);

    if ($stmt->execute()) {
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data berhasil diupdate"
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