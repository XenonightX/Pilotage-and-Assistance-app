<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
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

    $rawData = file_get_contents("php://input");
    error_log("📥 Raw Input: " . $rawData);

    $data = json_decode($rawData, true);
    error_log("📦 Decoded Data: " . print_r($data, true));

    if (!$data) {
        throw new Exception("Invalid JSON data");
    }

    $id = $data["id"] ?? null;
    if (!$id) {
        throw new Exception("ID is required");
    }

    // Field yang akan diupdate
    $vessel_name = $data["vessel_name"] ?? '';
    $call_sign = $data["call_sign"] ?? null;
    $master_name = $data["master_name"] ?? null;
    $flag = $data["flag"] ?? '';
    $gross_tonnage = $data["gross_tonnage"] ?? '';
    $agency = $data["agency"] ?? '';
    $loa = $data["loa"] ?? '';
    $fore_draft = $data["fore_draft"] ?? null;
    $aft_draft = $data["aft_draft"] ?? null;
    $pilot_name = $data["pilot_name"] ?? '';
    $from_where = $data["from_where"] ?? '';
    $to_where = $data["to_where"] ?? '';
    $last_port = $data["last_port"] ?? '';
    $next_port = $data["next_port"] ?? '';
    $date = $data["date"] ?? '';
    $pilot_on_board = $data["pilot_on_board"] ?? '';
    $pilot_finished = $data["pilot_finished"] ?? null;
    $vessel_start = $data["vessel_start"] ?? null;
    $pilot_get_off = $data["pilot_get_off"] ?? null;
    $status = $data["status"] ?? 'Terjadwal';

    error_log("🔄 Updating ID: $id with from_where: $from_where, to_where: $to_where");

    $sql = "UPDATE pilotage_logs SET 
                vessel_name = ?, 
                call_sign = ?, 
                master_name = ?, 
                flag = ?, 
                gross_tonnage = ?, 
                agency = ?, 
                loa = ?, 
                fore_draft = ?, 
                aft_draft = ?, 
                pilot_name = ?,
                from_where = ?,
                to_where = ?,
                last_port = ?, 
                next_port = ?, 
                date = ?, 
                pilot_on_board = ?,
                pilot_finished = ?,
                vessel_start = ?,
                pilot_get_off = ?,
                status = ?
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    $bind_result = $stmt->bind_param(
        "ssssssssssssssssssssi",
        $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
        $agency, $loa, $fore_draft, $aft_draft, $pilot_name,
        $from_where, $to_where, $last_port, $next_port, $date, $pilot_on_board,
        $pilot_finished, $vessel_start, $pilot_get_off, $status, $id
    );

    if (!$bind_result) {
        throw new Exception("Bind param failed: " . $stmt->error);
    }

    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        error_log("✅ Updated successfully. Affected rows: $affected_rows");
        
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data berhasil diupdate",
            "affected_rows" => $affected_rows
        ]);
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    error_log("❌ Error: " . $e->getMessage());
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}