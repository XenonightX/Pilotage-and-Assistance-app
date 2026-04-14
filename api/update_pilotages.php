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
    $pilot_on_board = $data["pilot_on_board"] ?? null;
    if ($pilot_on_board === '') $pilot_on_board = null;
    $pilot_finished = $data["pilot_finished"] ?? null;
    if ($pilot_finished === '') $pilot_finished = null;
    $vessel_start = $data["vessel_start"] ?? null;
    if ($vessel_start === '') $vessel_start = null;
    $pilot_get_off = $data["pilot_get_off"] ?? null;
    if ($pilot_get_off === '') $pilot_get_off = null;
    $assist_tug_name = $data["assist_tug_name"] ?? '';
    $engine_power = $data["engine_power"] ?? '';
    $bollard_pull_power = $data["bollard_pull_power"] ?? '';
    $status = $data["status"] ?? 'Terjadwal';
    $signature = $data["signature"] ?? null;
    if (is_string($signature)) {
        $signature = trim($signature);
        if ($signature === '') $signature = null;
    }

    // Otomatis set selesai jika pandu turun sudah diisi
    if (!empty($pilot_get_off)) {
        $status = 'Selesai';
    }

    error_log("🔄 Updating ID: $id with from_where: $from_where, to_where: $to_where");

    // Cek dukungan kolom signature (opsional, agar backward compatible)
    $hasSignatureColumn = false;
    $checkSignatureColumn = $conn->query("SHOW COLUMNS FROM activity_logs LIKE 'signature'");
    if ($checkSignatureColumn && $checkSignatureColumn->num_rows > 0) {
        $hasSignatureColumn = true;
    }

    // Jika signature dikirim tetapi kolom belum ada, coba tambahkan otomatis
    if (!$hasSignatureColumn && !empty($signature)) {
        if ($conn->query("ALTER TABLE activity_logs ADD COLUMN signature LONGTEXT NULL") === true) {
            $hasSignatureColumn = true;
            error_log("Signature column created automatically");
        } else {
            error_log("Failed to create signature column: " . $conn->error);
        }
    }

    $sql = "UPDATE activity_logs SET
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
                pilot_on_board = ?,
                pilot_finished = ?,
                vessel_start = ?,
                pilot_get_off = ?,
                assist_tug_name = ?,
                engine_power = ?,
                bollard_pull_power = ?,
                status = ?";

    $withSignature = $hasSignatureColumn && !empty($signature);
    if ($withSignature) {
        $sql .= ",
                signature = ?";
    }

    $sql .= "
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    if ($withSignature) {
        $bind_result = $stmt->bind_param(
            "sssssssssssssssssssssssi",
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $pilot_name,
            $from_where, $to_where, $last_port, $next_port, $pilot_on_board,
            $pilot_finished, $vessel_start, $pilot_get_off, $assist_tug_name,
            $engine_power, $bollard_pull_power, $status, $signature, $id
        );
    } else {
        $bind_result = $stmt->bind_param(
            "ssssssssssssssssssssssi",
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $pilot_name,
            $from_where, $to_where, $last_port, $next_port, $pilot_on_board,
            $pilot_finished, $vessel_start, $pilot_get_off, $assist_tug_name,
            $engine_power, $bollard_pull_power, $status, $id
        );
    }

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
