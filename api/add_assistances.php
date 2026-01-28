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
    error_log("=== START ADD ASSISTANCE ===");
    
    require_once __DIR__ . "/../backend/config/config.php";
    error_log("Config loaded");

    $data = json_decode(file_get_contents("php://input"), true);
    error_log("Data received: " . print_r($data, true));

    if (!$data) {
        throw new Exception("Invalid JSON data");
    }

    $vessel_name = $data["vessel_name"] ?? '';
    $flag = $data["flag"] ?? '';
    $gross_tonnage = $data["gross_tonnage"] ?? '';
    $agency = $data["agency"] ?? '';
    $loa = $data["loa"] ?? '';
    $from_where = $data["from_where"] ?? '';
    $to_where = $data["to_where"] ?? '';
    $last_port = $data["last_port"] ?? '';
    $next_port = $data["next_port"] ?? '';
    $date = $data["date"] ?? '';
    $assistance_start = $data["assistance_start"] ?? '';
    $assist_tug_name_1 = $data["assist_tug_name_1"] ?? '';
    
    $call_sign = $data["call_sign"] ?? '';
    $master_name = $data["master_name"] ?? '';
    $fore_draft = $data["fore_draft"] ?? '';
    $aft_draft = $data["aft_draft"] ?? '';
    $status = $data["status"] ?? 'Terjadwal';
    
    $assist_tug_count = intval($data["assist_tug_count"] ?? 1);
    $engine_power_1 = isset($data["engine_power_1"]) ? intval($data["engine_power_1"]) : 0;
    $assist_tug_name_2 = $data["assist_tug_name_2"] ?? '';
    $engine_power_2 = isset($data["engine_power_2"]) ? intval($data["engine_power_2"]) : 0;
    
    $assist_tug_name = $assist_tug_name_1;
    if ($assist_tug_count == 2 && !empty($assist_tug_name_2)) {
        $assist_tug_name .= ' / ' . $assist_tug_name_2;
    }
    
    $engine_power = '';
    if ($engine_power_1 > 0) {
        $engine_power = strval($engine_power_1);
    }
    if ($assist_tug_count == 2 && $engine_power_2 > 0) {
        $engine_power .= ($engine_power ? ' / ' : '') . strval($engine_power_2);
    }

    error_log("Validation check");
    if (empty($vessel_name) || empty($flag) || empty($gross_tonnage) || 
        empty($agency) || empty($loa) || empty($from_where) || 
        empty($to_where) || empty($last_port) || empty($next_port) || 
        empty($date) || empty($assist_tug_name_1)) {
        throw new Exception("Data tidak lengkap");
    }

    error_log("Preparing SQL");
    $sql = "INSERT INTO assistance_logs (
                vessel_name, call_sign, master_name, flag, gross_tonnage, 
                agency, loa, fore_draft, aft_draft, assist_tug_name,
                from_where, to_where, last_port, next_port, date, assistance_start,
                engine_power, status,
                assist_tug_count, assist_tug_name_1, engine_power_1, 
                assist_tug_name_2, engine_power_2
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        error_log("Prepare failed: " . $conn->error);
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    error_log("Binding parameters");
    $bind_result = $stmt->bind_param(
        "sssssssssssssssssisisi", 
        $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
        $agency, $loa, $fore_draft, $aft_draft, $assist_tug_name,
        $from_where, $to_where, $last_port, $next_port, $date, $assistance_start,
        $engine_power, $status,
        $assist_tug_count, $assist_tug_name_1, $engine_power_1,
        $assist_tug_name_2, $engine_power_2
    );
    
    if (!$bind_result) {
        error_log("Bind failed");
        throw new Exception("Bind param failed");
    }

    error_log("Executing query");
    if ($stmt->execute()) {
        error_log("Success! ID: " . $conn->insert_id);
        ob_end_clean();
        echo json_encode([
            "status" => "success",
            "message" => "Data penundaan berhasil ditambahkan",
            "id" => $conn->insert_id
        ]);
    } else {
        error_log("Execute failed: " . $stmt->error);
        throw new Exception("Execute failed: " . $stmt->error);
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    error_log("ERROR: " . $e->getMessage());
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}