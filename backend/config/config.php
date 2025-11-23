<?php
// CRITICAL: Matikan semua output error HTML
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(0);

// Jangan output apapun sebelum ini!
ob_start();

$servername = "localhost";
$username = "root";
$password = "";
$dbname = "pilotage_and_assistance_app";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        ob_end_clean();
        header('Content-Type: application/json');
        http_response_code(500);
        echo json_encode([
            "status" => "error",
            "message" => "Database connection failed"
        ]);
        exit;
    }
    
    $conn->set_charset("utf8mb4");
    ob_end_clean();
    
} catch (Exception $e) {
    ob_end_clean();
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Config error"
    ]);
    exit;
}