<?php
// ... existing headers ...

$data = json_decode(file_get_contents("php://input"), true);

// Extract data
$tugCount = $data['assist_tug_count'] ?? 1;
$tugName1 = $data['assist_tug_name_1'] ?? null;
$enginePower1 = $data['engine_power_1'] ?? null;
$tugName2 = $data['assist_tug_name_2'] ?? null;
$enginePower2 = $data['engine_power_2'] ?? null;

// Validasi
if (empty($tugName1)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Nama kapal tunda 1 wajib diisi'
    ]);
    exit;
}

if ($tugCount == 2 && empty($tugName2)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Nama kapal tunda 2 wajib diisi'
    ]);
    exit;
}

// Insert query
$sql = "INSERT INTO assistances (
    vessel_name, call_sign, master_name, flag, gross_tonnage, agency, loa,
    fore_draft, aft_draft, from_where, to_where, last_port, next_port,
    date, assistance_start, status,
    assist_tug_count, assist_tug_name_1, engine_power_1, 
    assist_tug_name_2, engine_power_2
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

$stmt = $conn->prepare($sql);
$stmt->bind_param(
    "ssssssssssssssssissii",
    // ... existing parameters ...
    $tugCount,
    $tugName1,
    $enginePower1,
    $tugName2,
    $enginePower2
);