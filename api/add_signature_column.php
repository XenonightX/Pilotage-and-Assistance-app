<?php
// Script untuk menambahkan kolom signature ke tabel activity_logs

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

$servername = "localhost";
$username = "root";
$password = "";
$dbname = "pilotage_and_assistance_app";

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Koneksi gagal: " . $conn->connect_error);
    }
    
    // Cek apakah kolom sudah ada
    $result = $conn->query("SHOW COLUMNS FROM activity_logs LIKE 'signature'");
    
    if ($result->num_rows == 0) {
        // Kolom belum ada, tambahkan
        $sql = "ALTER TABLE activity_logs ADD COLUMN signature LONGTEXT NULL";
        
        if ($conn->query($sql) === TRUE) {
            echo json_encode([
                "status" => "success",
                "message" => "Kolom signature berhasil ditambahkan ke tabel activity_logs"
            ]);
        } else {
            throw new Exception("Error menambahkan kolom: " . $conn->error);
        }
    } else {
        echo json_encode([
            "status" => "info",
            "message" => "Kolom signature sudah ada di tabel"
        ]);
    }
    
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
