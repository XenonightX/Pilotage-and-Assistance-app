<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
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

    // Field wajib
    $vessel_name = $data["vessel_name"] ?? '';
    $flag = $data["flag"] ?? '';
    $gross_tonnage = $data["gross_tonnage"] ?? '';
    $agency = $data["agency"] ?? '';
    $loa = $data["loa"] ?? '';
    $pilot_name = $data["pilot_name"] ?? '';
    $from_where = $data["from_where"] ?? '';  // Laut/Dermaga
    $to_where = $data["to_where"] ?? '';      // Dermaga/Laut
    $last_port = $data["last_port"] ?? '';    // Pelabuhan asal
    $next_port = $data["next_port"] ?? '';    // Pelabuhan tujuan
    $date = $data["date"] ?? '';
    $pilot_on_board = $data["pilot_on_board"] ?? '';
    
    // Field opsional
    $call_sign = $data["call_sign"] ?? null;
    $master_name = $data["master_name"] ?? null;
    $fore_draft = $data["fore_draft"] ?? null;
    $aft_draft = $data["aft_draft"] ?? null;
    $pilot_finished = $data["pilot_finished"] ?? null;
    $vessel_start = $data["vessel_start"] ?? null;
    $pilot_get_off = $data["pilot_get_off"] ?? null;
    $status = $data["status"] ?? 'Terjadwal';

    // Validasi hanya field wajib
    if (empty($vessel_name) || empty($flag) || empty($gross_tonnage) || 
        empty($agency) || empty($loa) || empty($pilot_name) || 
        empty($from_where) || empty($to_where) ||
        empty($last_port) || empty($next_port) || empty($date)) {
        throw new Exception("Data tidak lengkap");
    }

    $sql = "INSERT INTO pilotage_logs (
                vessel_name, call_sign, master_name, flag, gross_tonnage, 
                agency, loa, fore_draft, aft_draft, pilot_name, 
                from_where, to_where, last_port, next_port, date, pilot_on_board, 
                pilot_finished, vessel_start, pilot_get_off, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);

    $stmt->bind_param(
        "ssssssssssssssssssss", 
        $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
        $agency, $loa, $fore_draft, $aft_draft, $pilot_name,
        $from_where, $to_where, $last_port, $next_port, $date, $pilot_on_board,
        $pilot_finished, $vessel_start, $pilot_get_off, $status
    );

    if ($stmt->execute()) {
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data berhasil ditambahkan",
            "id" => $conn->insert_id
        ]);
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
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