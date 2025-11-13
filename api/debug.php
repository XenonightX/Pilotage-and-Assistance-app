<?php
// Aktifkan semua error untuk debugging
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h2>Testing PHP Files...</h2>";

// Test 1: Cek PHP berjalan
echo "✓ PHP is working<br>";

// Test 2: Cek file config
echo "<br><b>Test 2: Checking config file...</b><br>";
if (file_exists("../config/config.php")) {
    echo "✓ config.php file exists<br>";
    
    try {
        require_once "../config/config.php";
        echo "✓ config.php loaded successfully<br>";
        
        if (isset($conn)) {
            echo "✓ \$conn variable is set<br>";
            
            if ($conn->connect_error) {
                echo "✗ Connection error: " . $conn->connect_error . "<br>";
            } else {
                echo "✓ Database connected successfully<br>";
                
                // Test 3: Cek tabel
                echo "<br><b>Test 3: Checking table...</b><br>";
                $result = $conn->query("SHOW TABLES LIKE 'pilotage_logs'");
                if ($result && $result->num_rows > 0) {
                    echo "✓ Table 'pilotage_logs' exists<br>";
                    
                    // Test 4: Cek struktur tabel
                    echo "<br><b>Test 4: Table structure...</b><br>";
                    $result = $conn->query("DESCRIBE pilotage_logs");
                    if ($result) {
                        echo "<table border='1' cellpadding='5'>";
                        echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th></tr>";
                        while ($row = $result->fetch_assoc()) {
                            echo "<tr>";
                            echo "<td>" . $row['Field'] . "</td>";
                            echo "<td>" . $row['Type'] . "</td>";
                            echo "<td>" . $row['Null'] . "</td>";
                            echo "<td>" . $row['Key'] . "</td>";
                            echo "</tr>";
                        }
                        echo "</table>";
                    }
                    
                    // Test 5: Cek jumlah data
                    echo "<br><b>Test 5: Count records...</b><br>";
                    $result = $conn->query("SELECT COUNT(*) as total FROM pilotage_logs");
                    if ($result) {
                        $row = $result->fetch_assoc();
                        echo "✓ Total records: " . $row['total'] . "<br>";
                    }
                } else {
                    echo "✗ Table 'pilotage_logs' NOT FOUND<br>";
                    echo "<br><b>Available tables:</b><br>";
                    $result = $conn->query("SHOW TABLES");
                    if ($result) {
                        while ($row = $result->fetch_array()) {
                            echo "- " . $row[0] . "<br>";
                        }
                    }
                }
            }
        } else {
            echo "✗ \$conn variable is NOT set<br>";
        }
    } catch (Exception $e) {
        echo "✗ Error loading config: " . $e->getMessage() . "<br>";
    }
} else {
    echo "✗ config.php file NOT FOUND<br>";
    echo "Looking in: " . realpath("..") . "/config/config.php<br>";
}

echo "<br><b>Test 6: Testing get_stats.php directly...</b><br>";
echo "<a href='get_stats.php' target='_blank'>Click here to test get_stats.php</a><br>";

echo "<br><b>Test 7: Testing get_pilotages.php directly...</b><br>";
echo "<a href='get_pilotages.php' target='_blank'>Click here to test get_pilotages.php</a><br>";

echo "<br><h3>All tests completed!</h3>";