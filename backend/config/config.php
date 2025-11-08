<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

$servername = "localhost";
$username   = "root";
$password   = "";
$dbname     = "dbsis_app";

// Buat koneksi
$conn = new mysqli($servername, $username, $password, $dbname);

// Cek koneksi
if ($conn->connect_error) {
    echo json_encode([
        "status" => "error",
        "message" => "Koneksi ke database gagal: " . $conn->connect_error
    ]);
    exit;
}
?>
