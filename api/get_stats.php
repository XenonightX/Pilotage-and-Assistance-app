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

    // ✅ DEBUG: Total semua data
    $sqlCountAll = "SELECT COUNT(*) as total FROM pilotage_logs";
    $resultCountAll = $conn->query($sqlCountAll);
    $debugInfo['total_all_records'] = $resultCountAll->fetch_assoc()['total'];

    // ✅ DEBUG: Sample data terbaru
    $sqlAllData = "SELECT id, DATE(date) as date_only, status FROM pilotage_logs ORDER BY id DESC LIMIT 10";
    $resultAllData = $conn->query($sqlAllData);
    $debugInfo['sample_data'] = [];
    while ($row = $resultAllData->fetch_assoc()) {
        $debugInfo['sample_data'][] = $row;
    }

    // ✅ DEBUG: count per status
    $sqlCountByStatus = "SELECT status, COUNT(*) as count FROM pilotage_logs GROUP BY status";
    $resultCountByStatus = $conn->query($sqlCountByStatus);
    $debugInfo['count_by_status'] = [];
    while ($row = $resultCountByStatus->fetch_assoc()) {
        $debugInfo['count_by_status'][] = $row;
    }

    // ======================================================
    //               QUERY MENGGUNAKAN KOLOM "date"
    // ======================================================

    // Total hari ini
    $sqlTotal = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = ?";
    $stmtTotal = $conn->prepare($sqlTotal);
    $stmtTotal->bind_param("s", $today);
    $stmtTotal->execute();
    $resultTotal = $stmtTotal->get_result()->fetch_assoc();

    // Aktif
    $sqlActive = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = ? AND status = 'Aktif'";
    $stmtActive = $conn->prepare($sqlActive);
    $stmtActive->bind_param("s", $today);
    $stmtActive->execute();
    $resultActive = $stmtActive->get_result()->fetch_assoc();

    // Selesai
    $sqlCompleted = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = ? AND status = 'Selesai'";
    $stmtCompleted = $conn->prepare($sqlCompleted);
    $stmtCompleted->bind_param("s", $today);
    $stmtCompleted->execute();
    $resultCompleted = $stmtCompleted->get_result()->fetch_assoc();

    // Terjadwal
    $sqlScheduled = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(date) = ? AND status = 'Terjadwal'";
    $stmtScheduled = $conn->prepare($sqlScheduled);
    $stmtScheduled->bind_param("s", $today);
    $stmtScheduled->execute();
    $resultScheduled = $stmtScheduled->get_result()->fetch_assoc();

    // Output
    ob_end_clean();
    echo json_encode([
        "status" => "success",
        "data" => [
            "total" => (int)($resultTotal['total'] ?? 0),
            "active" => (int)($resultActive['total'] ?? 0),
            "completed" => (int)($resultCompleted['total'] ?? 0),
            "scheduled" => (int)($resultScheduled['total'] ?? 0)
        ],
        "debug" => $debugInfo
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