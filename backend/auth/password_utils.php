<?php

function isStoredPasswordHash(string $storedPassword): bool
{
    $info = password_get_info($storedPassword);
    return !empty($info['algo']);
}

function hashUserPassword(string $plainPassword): string
{
    return password_hash($plainPassword, PASSWORD_DEFAULT);
}

function verifyUserPassword(string $plainPassword, string $storedPassword): bool
{
    if ($storedPassword === '') {
        return false;
    }

    if (isStoredPasswordHash($storedPassword)) {
        return password_verify($plainPassword, $storedPassword);
    }

    return hash_equals($storedPassword, $plainPassword);
}

function shouldUpgradeStoredPassword(string $storedPassword): bool
{
    if ($storedPassword === '') {
        return false;
    }

    if (!isStoredPasswordHash($storedPassword)) {
        return true;
    }

    return password_needs_rehash($storedPassword, PASSWORD_DEFAULT);
}

function upgradeUserPasswordHash(mysqli $conn, int $userId, string $plainPassword): bool
{
    if ($userId <= 0 || $plainPassword === '') {
        return false;
    }

    $hashedPassword = hashUserPassword($plainPassword);
    if ($hashedPassword === false || $hashedPassword === '') {
        return false;
    }

    $stmt = $conn->prepare("UPDATE users SET password = ? WHERE id = ?");
    if (!$stmt) {
        return false;
    }

    $stmt->bind_param("si", $hashedPassword, $userId);
    $success = $stmt->execute();
    $stmt->close();

    return $success;
}
