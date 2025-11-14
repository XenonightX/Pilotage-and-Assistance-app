<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

try {
    require_once __DIR__ . "/../backend/config/config.php";

    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    $today = date('Y-m-d');
    
    // ✅ DEBUG: Info lengkap
    $debugInfo = [
        "today" => $today,
        "timezone" => date_default_timezone_get(),
        "current_datetime" => date('Y-m-d H:i:s')
    ];

    // ✅ DEBUG: Cek total semua data di tabel (tanpa filter)
    $sqlCountAll = "SELECT COUNT(*) as total FROM pilotage_logs";
    $resultCountAll = $conn->query($sqlCountAll);
    $debugInfo['total_all_records'] = $resultCountAll->fetch_assoc()['total'];

    // ✅ DEBUG: Cek semua data di tabel dengan detail
    $sqlAllData = "SELECT id, tanggal, DATE(tanggal) as tanggal_only, status FROM pilotage_logs ORDER BY id DESC LIMIT 10";
    $resultAllData = $conn->query($sqlAllData);
    $debugInfo['sample_data'] = [];
    while ($row = $resultAllData->fetch_assoc()) {
        $debugInfo['sample_data'][] = $row;
    }

    // ✅ DEBUG: Cek count per status (tanpa filter tanggal)
    $sqlCountByStatus = "SELECT status, COUNT(*) as count FROM pilotage_logs GROUP BY status";
    $resultCountByStatus = $conn->query($sqlCountByStatus);
    $debugInfo['count_by_status'] = [];
    while ($row = $resultCountByStatus->fetch_assoc()) {
        $debugInfo['count_by_status'][] = $row;
    }

    $sqlTotal = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ?";
    $stmtTotal = $conn->prepare($sqlTotal);
    if (!$stmtTotal) throw new Exception("Prepare failed: " . $conn->error);
    $stmtTotal->bind_param("s", $today);
    $stmtTotal->execute();
    $resultTotal = $stmtTotal->get_result()->fetch_assoc();

    $sqlActive = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Aktif'";
    $stmtActive = $conn->prepare($sqlActive);
    if (!$stmtActive) throw new Exception("Prepare failed: " . $conn->error);
    $stmtActive->bind_param("s", $today);
    $stmtActive->execute();
    $resultActive = $stmtActive->get_result()->fetch_assoc();

    $sqlCompleted = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Selesai'";
    $stmtCompleted = $conn->prepare($sqlCompleted);
    if (!$stmtCompleted) throw new Exception("Prepare failed: " . $conn->error);
    $stmtCompleted->bind_param("s", $today);
    $stmtCompleted->execute();
    $resultCompleted = $stmtCompleted->get_result()->fetch_assoc();

    $sqlScheduled = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Terjadwal'";
    $stmtScheduled = $conn->prepare($sqlScheduled);
    if (!$stmtScheduled) throw new Exception("Prepare failed: " . $conn->error);
    $stmtScheduled->bind_param("s", $today);
    $stmtScheduled->execute();
    $resultScheduled = $stmtScheduled->get_result()->fetch_assoc();

    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => [
            "total" => (int)($resultTotal['total'] ?? 0),
            "active" => (int)($resultActive['total'] ?? 0),
            "completed" => (int)($resultCompleted['total'] ?? 0),
            "scheduled" => (int)($resultScheduled['total'] ?? 0)
        ],
        "debug" => $debugInfo // ✅ Info debug
    ]);

    $stmtTotal->close();
    $stmtActive->close();
    $stmtCompleted->close();
    $stmtScheduled->close();
    $conn->close();

} catch (Exception $e) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}