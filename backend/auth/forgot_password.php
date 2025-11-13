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

require_once "../../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$email = $data["email"] ?? '';

// Validasi input
if (empty($email)) {
    echo json_encode([
        "status" => "error", 
        "message" => "Email wajib diisi"
    ]);
    exit;
}

// Validasi format email
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        "status" => "error", 
        "message" => "Format email tidak valid"
    ]);
    exit;
}

// Cek apakah email terdaftar
$sql = "SELECT id, name FROM users WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        "status" => "error", 
        "message" => "Email tidak terdaftar"
    ]);
    exit;
}

$user = $result->fetch_assoc();

// Generate reset token (6 digit angka)
$resetToken = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);

// Simpan token ke database dengan expired time (1 jam)
$expiredAt = date('Y-m-d H:i:s', strtotime('+1 hour'));

// Cek apakah tabel password_resets sudah ada, kalau belum buat
$createTableSql = "CREATE TABLE IF NOT EXISTS password_resets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    email VARCHAR(255) NOT NULL,
    token VARCHAR(10) NOT NULL,
    expired_at DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)";
$conn->query($createTableSql);

// Hapus token lama untuk email ini
$deleteSql = "DELETE FROM password_resets WHERE email = ?";
$stmtDelete = $conn->prepare($deleteSql);
$stmtDelete->bind_param("s", $email);
$stmtDelete->execute();

// Insert token baru
$insertSql = "INSERT INTO password_resets (user_id, email, token, expired_at) VALUES (?, ?, ?, ?)";
$stmtInsert = $conn->prepare($insertSql);
$stmtInsert->bind_param("isss", $user['id'], $email, $resetToken, $expiredAt);

if ($stmtInsert->execute()) {
    echo json_encode([
        "status" => "success",
        "message" => "Token reset password berhasil dibuat",
        "reset_token" => $resetToken,
        "user_name" => $user['name']
    ]);
    
    // CATATAN: Untuk production, kirim token via EMAIL, jangan tampilkan di response!
    // Gunakan library seperti PHPMailer untuk kirim email
} else {
    echo json_encode([
        "status" => "error", 
        "message" => "Gagal membuat token reset: " . $stmtInsert->error
    ]);
}

$conn->close();
?>