<?php
// Aktifkan error display untuk debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

header("Content-Type: application/json");

echo "Testing...\n";

// Test 1: Cek file config
if (file_exists("../config/config.php")) {
    echo "✓ config.php exists\n";
} else {
    echo "✗ config.php NOT FOUND\n";
    die();
}

// Test 2: Include config
require_once "../config/config.php";
echo "✓ config.php loaded\n";

// Test 3: Cek koneksi
if (isset($conn)) {
    echo "✓ \$conn variable exists\n";
} else {
    echo "✗ \$conn NOT SET\n";
    die();
}

// Test 4: Cek koneksi database
if ($conn->connect_error) {
    echo "✗ Connection failed: " . $conn->connect_error . "\n";
    die();
} else {
    echo "✓ Database connected\n";
}

// Test 5: Cek tabel
$result = $conn->query("SHOW TABLES LIKE 'pilotage_logs'");
if ($result->num_rows > 0) {
    echo "✓ Table 'pilotage_logs' exists\n";
} else {
    echo "✗ Table 'pilotage_logs' NOT FOUND\n";
    die();
}

// Test 6: Cek isi tabel
$result = $conn->query("SELECT COUNT(*) as total FROM pilotage_logs");
$row = $result->fetch_assoc();
echo "✓ Table has " . $row['total'] . " rows\n";

echo "\nAll tests passed! ✓\n";

$conn->close();