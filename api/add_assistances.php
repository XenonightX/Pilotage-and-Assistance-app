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

    $legacyAssistTugNames = preg_split('/\s*(?:\/|,)\s*/', trim((string) ($data["assist_tug_name"] ?? '')));
    if (!is_array($legacyAssistTugNames)) {
        $legacyAssistTugNames = [];
    }
    $legacyAssistTugNames = array_values(array_filter(array_map('trim', $legacyAssistTugNames), static function ($value) {
        return $value !== '';
    }));

    $legacyEnginePowers = preg_split('/\s*(?:\/|,)\s*/', trim((string) ($data["engine_power"] ?? '')));
    if (!is_array($legacyEnginePowers)) {
        $legacyEnginePowers = [];
    }
    $legacyEnginePowers = array_values(array_filter(array_map('trim', $legacyEnginePowers), static function ($value) {
        return $value !== '';
    }));

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
    $assist_tug_name_1 = $data["assist_tug_name_1"] ?? ($legacyAssistTugNames[0] ?? '');
    
    $call_sign = $data["call_sign"] ?? '';
    $master_name = $data["master_name"] ?? '';
    $fore_draft = $data["fore_draft"] ?? '';
    $aft_draft = $data["aft_draft"] ?? '';
    $status = $data["status"] ?? 'Terjadwal';
    
    $assist_tug_name_2 = $data["assist_tug_name_2"] ?? ($legacyAssistTugNames[1] ?? '');
    $assist_tug_name_3 = $data["assist_tug_name_3"] ?? ($legacyAssistTugNames[2] ?? '');

    $defaultAssistTugCount = count(array_filter([
        trim((string) $assist_tug_name_1),
        trim((string) $assist_tug_name_2),
        trim((string) $assist_tug_name_3),
    ], static function ($value) {
        return $value !== '';
    }));
    if ($defaultAssistTugCount < 1 && !empty($legacyAssistTugNames)) {
        $defaultAssistTugCount = count($legacyAssistTugNames);
    }
    if ($defaultAssistTugCount < 1) {
        $defaultAssistTugCount = 1;
    }

    $assist_tug_count = intval($data["assist_tug_count"] ?? $defaultAssistTugCount);
    if ($assist_tug_count < 1) {
        $assist_tug_count = 1;
    }
    if ($assist_tug_count > 3) {
        $assist_tug_count = 3;
    }
    $engine_power_1 = isset($data["engine_power_1"]) ? intval($data["engine_power_1"]) : (int) ($legacyEnginePowers[0] ?? 0);
    $engine_power_2 = isset($data["engine_power_2"]) ? intval($data["engine_power_2"]) : (int) ($legacyEnginePowers[1] ?? 0);
    $engine_power_3 = isset($data["engine_power_3"]) ? intval($data["engine_power_3"]) : (int) ($legacyEnginePowers[2] ?? 0);
    
    $assistTugNames = [];
    $assistTugPowers = [];
    foreach ([
        ['name' => $assist_tug_name_1, 'power' => $engine_power_1],
        ['name' => $assist_tug_name_2, 'power' => $engine_power_2],
        ['name' => $assist_tug_name_3, 'power' => $engine_power_3],
    ] as $index => $tug) {
        if ($index >= $assist_tug_count) {
            break;
        }
        $name = trim((string) $tug['name']);
        $power = (int) $tug['power'];
        if ($name !== '') {
            $assistTugNames[] = $name;
        }
        if ($power > 0) {
            $assistTugPowers[] = (string) $power;
        }
    }

    $assist_tug_name = implode(' / ', $assistTugNames);
    $engine_power = implode(' / ', $assistTugPowers);

    error_log("Validation check");
    if (empty($vessel_name) || empty($flag) || empty($gross_tonnage) || 
        empty($agency) || empty($loa) || empty($from_where) || 
        empty($to_where) || empty($last_port) || empty($next_port) || 
        empty($date) || empty($assist_tug_name_1)) {
        throw new Exception("Data tidak lengkap");
    }

    error_log("Preparing SQL");
    $hasThirdAssistColumns = false;
    $checkThirdNameColumn = $conn->query("SHOW COLUMNS FROM assistance_logs LIKE 'assist_tug_name_3'");
    $checkThirdPowerColumn = $conn->query("SHOW COLUMNS FROM assistance_logs LIKE 'engine_power_3'");
    if (
        $checkThirdNameColumn && $checkThirdNameColumn->num_rows > 0 &&
        $checkThirdPowerColumn && $checkThirdPowerColumn->num_rows > 0
    ) {
        $hasThirdAssistColumns = true;
    }

    if (!$hasThirdAssistColumns && ($assist_tug_count >= 3 || trim($assist_tug_name_3) !== '' || $engine_power_3 > 0)) {
        if ($conn->query("ALTER TABLE assistance_logs ADD COLUMN assist_tug_name_3 VARCHAR(255) NULL AFTER engine_power_2") === true) {
            $nameColumnAdded = true;
        } else {
            $nameColumnAdded = strpos(strtolower($conn->error), 'duplicate column') !== false;
        }

        if ($conn->query("ALTER TABLE assistance_logs ADD COLUMN engine_power_3 INT NULL AFTER assist_tug_name_3") === true) {
            $powerColumnAdded = true;
        } else {
            $powerColumnAdded = strpos(strtolower($conn->error), 'duplicate column') !== false;
        }

        $hasThirdAssistColumns = $nameColumnAdded && $powerColumnAdded;
    }

    $sql = "INSERT INTO assistance_logs (
                vessel_name, call_sign, master_name, flag, gross_tonnage, 
                agency, loa, fore_draft, aft_draft, assist_tug_name,
                from_where, to_where, last_port, next_port, date, assistance_start,
                engine_power, status,
                assist_tug_count, assist_tug_name_1, engine_power_1, 
                assist_tug_name_2, engine_power_2";
    if ($hasThirdAssistColumns) {
        $sql .= ", assist_tug_name_3, engine_power_3";
    }
    $sql .= "
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?";
    if ($hasThirdAssistColumns) {
        $sql .= ", ?, ?";
    }
    $sql .= ")";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        error_log("Prepare failed: " . $conn->error);
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    error_log("Binding parameters");
    if ($hasThirdAssistColumns) {
        $types = str_repeat('s', 18) . 'isisisi';
        $bind_result = $stmt->bind_param(
            $types,
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $assist_tug_name,
            $from_where, $to_where, $last_port, $next_port, $date, $assistance_start,
            $engine_power, $status,
            $assist_tug_count, $assist_tug_name_1, $engine_power_1,
            $assist_tug_name_2, $engine_power_2,
            $assist_tug_name_3, $engine_power_3
        );
    } else {
        $types = str_repeat('s', 18) . 'isisi';
        $bind_result = $stmt->bind_param(
            $types, 
            $vessel_name, $call_sign, $master_name, $flag, $gross_tonnage,
            $agency, $loa, $fore_draft, $aft_draft, $assist_tug_name,
            $from_where, $to_where, $last_port, $next_port, $date, $assistance_start,
            $engine_power, $status,
            $assist_tug_count, $assist_tug_name_1, $engine_power_1,
            $assist_tug_name_2, $engine_power_2
        );
    }
    
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
