<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

try {
    require_once __DIR__ . "/../config/config.php";

    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    $today = date('Y-m-d');

    $sqlTotal = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ?";
    $stmtTotal = $conn->prepare($sqlTotal);
    if (!$stmtTotal) throw new Exception("Prepare failed");
    $stmtTotal->bind_param("s", $today);
    $stmtTotal->execute();
    $resultTotal = $stmtTotal->get_result()->fetch_assoc();

    $sqlActive = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Aktif'";
    $stmtActive = $conn->prepare($sqlActive);
    if (!$stmtActive) throw new Exception("Prepare failed");
    $stmtActive->bind_param("s", $today);
    $stmtActive->execute();
    $resultActive = $stmtActive->get_result()->fetch_assoc();

    $sqlCompleted = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Selesai'";
    $stmtCompleted = $conn->prepare($sqlCompleted);
    if (!$stmtCompleted) throw new Exception("Prepare failed");
    $stmtCompleted->bind_param("s", $today);
    $stmtCompleted->execute();
    $resultCompleted = $stmtCompleted->get_result()->fetch_assoc();

    $sqlScheduled = "SELECT COUNT(*) as total FROM pilotage_logs WHERE DATE(tanggal) = ? AND status = 'Terjadwal'";
    $stmtScheduled = $conn->prepare($sqlScheduled);
    if (!$stmtScheduled) throw new Exception("Prepare failed");
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
        ]
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