<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require_once __DIR__ . "/../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$name = $data["name"] ?? '';
$email = $data["email"] ?? '';
$password = $data["password"] ?? '';
$role = $data["role"] ?? 'pilot';

// Validasi input
if (empty($name) || empty($email) || empty($password)) {
    echo json_encode(["status" => "error", "message" => "Semua field wajib diisi"]);
    exit;
}

// ✅ Validasi role untuk ENUM
if (!in_array($role, ['superadmin', 'admin', 'pilot', 'tugboat'])) {
    echo json_encode(["status" => "error", "message" => "Role tidak valid"]);
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

// ✅ Simpan user baru dengan role (simple, tanpa vessel_name)
// PENTING: Gunakan password_hash untuk keamanan (opsional tapi sangat disarankan)
// $hashedPassword = password_hash($password, PASSWORD_DEFAULT);

$sql = "INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ssss", $name, $email, $password, $role);

if ($stmt->execute()) {
    echo json_encode([
        "status" => "success", 
        "message" => "Registrasi berhasil sebagai " . ($role == 'pilot' ? 'Pilot' : 'Tugboats')
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan data: " . $stmt->error]);
}

$stmt->close();
$conn->close();