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

    // Field wajib untuk assistance (tug boat service)
    $vessel_name = $data["vessel_name"] ?? '';
    $flag = $data["flag"] ?? '';
    $gross_tonnage = $data["gross_tonnage"] ?? '';
    $agency = $data["agency"] ?? '';
    $loa = $data["loa"] ?? '';
    $assist_tug_name = $data["assist_tug_name"] ?? '';  // Nama kapal tunda
    $from_where = $data["from_where"] ?? '';  // Dari mana (Laut/Dermaga)
    $to_where = $data["to_where"] ?? '';      // Ke mana (Dermaga/Laut)
    $date = $data["date"] ?? '';
    $assistance_start = $data["assistance_start"] ?? '';  // Waktu mulai penundaan
    
    // Field opsional
    $call_sign = $data["call_sign"] ?? null;
    $master_name = $data["master_name"] ?? null;
    $fore_draft = $data["fore_draft"] ?? null;
    $aft_draft = $data["aft_draft"] ?? null;
    $assistance_end = $data["assistance_end"] ?? null;  // Waktu selesai penundaan
    $engine_power = $data["engine_power"] ?? null;  // Tenaga mesin tunda (HP/BHP)
    $notes = $data["notes"] ?? null;  // Catatan tambahan
    $status = $data["status"] ?? 'Terjadwal';

    // Validasi hanya field wajib
    if (empty($vessel_name) || empty($flag) || empty($gross_tonnage) || 
        empty($agency) || empty($loa) || empty($assist_tug_name) || 
        empty($from_where) || empty($to_where) || 
        empty($date) || empty($assistance_start)) {
        throw new Exception("Data tidak lengkap");
    }

    $sql = "INSERT INTO assistance_logs (
                vessel_name, call_sign, master_name, flag, gross_tonnage, 
                agency, loa, fore_draft, aft_draft, assist_tug_name, 
                from_where, to_where, date, assistance_start, 
                assistance_end, engine_power, notes, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);

    $stmt->bind_param(
        "sssssssssssssssssss", 
        $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
        $agency, $loa, $fore_draft, $aft_draft, $assist_tug_name,
        $from_where, $to_where, $date, $assistance_start,
        $assistance_end, $engine_power, $notes, $status
    );

    if ($stmt->execute()) {
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data penundaan kapal berhasil ditambahkan",
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