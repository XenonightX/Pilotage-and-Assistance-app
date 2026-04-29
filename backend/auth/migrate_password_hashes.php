<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    echo "This script can only be run from CLI.\n";
    exit(1);
}

require_once __DIR__ . "/../config/config.php";
require_once __DIR__ . "/password_utils.php";

if (!isset($conn) || $conn->connect_error) {
    fwrite(STDERR, "Database connection failed.\n");
    exit(1);
}

$result = $conn->query("SELECT id, password FROM users");
if (!$result) {
    fwrite(STDERR, "Failed to read users: {$conn->error}\n");
    $conn->close();
    exit(1);
}

$updated = 0;
$skipped = 0;
$failed = 0;

while ($row = $result->fetch_assoc()) {
    $userId = (int) ($row['id'] ?? 0);
    $storedPassword = (string) ($row['password'] ?? '');

    if ($userId <= 0 || $storedPassword === '' || isStoredPasswordHash($storedPassword)) {
        $skipped++;
        continue;
    }

    if (upgradeUserPasswordHash($conn, $userId, $storedPassword)) {
        $updated++;
    } else {
        $failed++;
    }
}

$result->close();
$conn->close();

echo "Password hash migration completed.\n";
echo "Updated: {$updated}\n";
echo "Skipped: {$skipped}\n";
echo "Failed : {$failed}\n";
