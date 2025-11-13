<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . "/../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$userId = $data["user_id"] ?? 0;
$oldPassword = $data["old_password"] ?? '';
$newPassword = $data["new_password"] ?? '';

// Validasi input
if (empty($userId) || empty($oldPassword) || empty($newPassword)) {
    echo json_encode([
        "status" => "error", 
        "message" => "User ID, password lama, dan password baru wajib diisi"
    ]);
    exit;
}

// Validasi panjang password baru
if (strlen($newPassword) < 6) {
    echo json_encode([
        "status" => "error", 
        "message" => "Password baru minimal 6 karakter"
    ]);
    exit;
}

// Ambil data user dari database
$sql = "SELECT * FROM users WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $userId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        "status" => "error", 
        "message" => "User tidak ditemukan"
    ]);
    exit;
}

$user = $result->fetch_assoc();

// Verifikasi password lama
// CATATAN: Kode ini untuk plaintext password (seperti sistem kamu sekarang)
// Kalau sudah pakai hash, ganti dengan password_verify()
if ($oldPassword !== $user['password']) {
    echo json_encode([
        "status" => "error", 
        "message" => "Password lama salah"
    ]);
    exit;
}

// Cek apakah password baru sama dengan password lama
if ($oldPassword === $newPassword) {
    echo json_encode([
        "status" => "error", 
        "message" => "Password baru tidak boleh sama dengan password lama"
    ]);
    exit;
}

// Update password
// CATATAN: Ini masih plaintext, sebaiknya pakai password_hash()
// $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
$sqlUpdate = "UPDATE users SET password = ? WHERE id = ?";
$stmtUpdate = $conn->prepare($sqlUpdate);
$stmtUpdate->bind_param("si", $newPassword, $userId);

if ($stmtUpdate->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Password berhasil diubah"
    ]);
} else {
    echo json_encode([
        "status" => "error", 
        "message" => "Gagal mengubah password: " . $stmtUpdate->error
    ]);
}

$conn->close();
?>