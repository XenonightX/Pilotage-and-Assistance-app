<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require_once "../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$name = $data["name"] ?? '';
$email = $data["email"] ?? '';
$password = $data["password"] ?? '';

if (empty($name) || empty($email) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "Semua field wajib diisi"]);
    exit;
}

// Cek apakah email sudah digunakan
$check = $conn->prepare("SELECT id FROM users WHERE email = ?");
$check->bind_param("s", $email);
$check->execute();
$result = $check->get_result();

if ($result->num_rows > 0) {
    echo json_encode(["status" => "error", "message" => "Email sudah terdaftar"]);
    exit;
}

// Simpan user baru (tanpa hash, bisa diganti password_hash nanti)
$sql = "INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, 'user')";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sss", $name, $email, $password);

if ($stmt->execute()) {
    echo json_encode(["status" => "success", "message" => "Registrasi berhasil"]);
} else {
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan data"]);
}

$conn->close();
?>
