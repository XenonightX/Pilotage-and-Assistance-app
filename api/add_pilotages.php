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
    $pilot_user_id = isset($data["pilot_user_id"]) ? (int) $data["pilot_user_id"] : null;
    if ($pilot_user_id !== null && $pilot_user_id <= 0) {
        $pilot_user_id = null;
    }
    $from_where = $data["from_where"] ?? '';
    $to_where = $data["to_where"] ?? '';
    $last_port = $data["last_port"] ?? '';
    $next_port = $data["next_port"] ?? '';
    $date = $data["date"] ?? '';
    $pilot_on_board = $data["pilot_on_board"] ?? '';
    
    // Field opsional
    $call_sign = $data["call_sign"] ?? null;
    $master_name = $data["master_name"] ?? null;
    $fore_draft = $data["fore_draft"] ?? null;
    $aft_draft = $data["aft_draft"] ?? null;
    $assist_tug_name = $data["assist_tug_name"] ?? null;
    $engine_power = $data["engine_power"] ?? null;
    $bollard_pull_power = $data["bollard_pull_power"] ?? 0;
    $status = $data["status"] ?? 'Terjadwal';

    // Validasi field wajib
    if (empty($vessel_name) || empty($flag) || empty($gross_tonnage) || 
        empty($agency) || empty($loa) || empty($pilot_name) ||
        empty($from_where) || empty($to_where) || empty($last_port) || 
        empty($next_port) || empty($date) || empty($pilot_on_board)) {
        throw new Exception("Data tidak lengkap");
    }

    $hasPilotUserIdColumn = false;
    $checkPilotUserIdColumn = $conn->query("SHOW COLUMNS FROM activity_logs LIKE 'pilot_user_id'");
    if ($checkPilotUserIdColumn && $checkPilotUserIdColumn->num_rows > 0) {
        $hasPilotUserIdColumn = true;
    }

    if (!$hasPilotUserIdColumn && $pilot_user_id !== null) {
        if ($conn->query("ALTER TABLE activity_logs ADD COLUMN pilot_user_id INT NULL AFTER pilot_name") === true) {
            $hasPilotUserIdColumn = true;
        }
    }

    $sql = "INSERT INTO activity_logs (
                vessel_name, call_sign, master_name, flag, gross_tonnage,
                agency, loa, fore_draft, aft_draft, pilot_name";
    if ($hasPilotUserIdColumn) {
        $sql .= ", pilot_user_id";
    }
    $sql .= ",
                from_where, to_where, last_port, next_port, date, pilot_on_board,
                assist_tug_name, engine_power, bollard_pull_power, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
    if ($hasPilotUserIdColumn) {
        $sql .= ", ?";
    }
    $sql .= ", ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);

    if ($hasPilotUserIdColumn) {
        $stmt->bind_param(
            "ssssssssssissssssssss",
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $pilot_name, $pilot_user_id,
            $from_where, $to_where, $last_port, $next_port, $date, $pilot_on_board,
            $assist_tug_name, $engine_power, $bollard_pull_power, $status
        );
    } else {
        $stmt->bind_param(
            "ssssssssssssssssssss",
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $pilot_name,
            $from_where, $to_where, $last_port, $next_port, $date, $pilot_on_board,
            $assist_tug_name, $engine_power, $bollard_pull_power, $status
        );
    }

    if ($stmt->execute()) {
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data pemanduan berhasil ditambahkan",
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
