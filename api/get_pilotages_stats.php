<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

try {
    // ✅ Koneksi database - SAMA dengan get_pilotages.php
    require_once __DIR__ . "/../backend/config/config.php";
    
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    // Set timezone
    date_default_timezone_set('Asia/Jakarta');
    $today = date('Y-m-d');

    // ✅ PILIH SALAH SATU: 
    // Opsi A: Hitung SEMUA data (hapus komentar di bawah)
    $sqlTotal = "SELECT COUNT(*) as total FROM pilotage_logs";
    $sqlActive = "SELECT COUNT(*) as total FROM pilotage_logs WHERE status = 'Aktif'";
    $sqlCompleted = "SELECT COUNT(*) as total FROM pilotage_logs WHERE status = 'Selesai'";
    $sqlScheduled = "SELECT COUNT(*) as total FROM pilotage_logs WHERE status = 'Terjadwal'";

    // Opsi B: Hitung data HARI INI saja (hapus komentar di bawah)
    // $sqlTotal = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = '$today'";
    // $sqlActive = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = '$today' AND status = 'Aktif'";
    // $sqlCompleted = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = '$today' AND status = 'Selesai'";
    // $sqlScheduled = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = '$today' AND status = 'Terjadwal'";

    // Execute queries
    $resultTotal = $conn->query($sqlTotal);
    if (!$resultTotal) throw new Exception("Query error: " . $conn->error);
    $total = $resultTotal->fetch_assoc()['total'];

    $resultActive = $conn->query($sqlActive);
    $active = $resultActive->fetch_assoc()['total'];

    $resultCompleted = $conn->query($sqlCompleted);
    $completed = $resultCompleted->fetch_assoc()['total'];

    $resultScheduled = $conn->query($sqlScheduled);
    $scheduled = $resultScheduled->fetch_assoc()['total'];

    // Response sukses
    echo json_encode([
        "status" => "success",
        "data" => [
            "total" => (int)$total,
            "active" => (int)$active,
            "completed" => (int)$completed,
            "scheduled" => (int)$scheduled
        ],
        "debug" => [
            "today" => $today,
            "query_used" => "all_data" // atau "today_only"
        ]
    ]);

    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}