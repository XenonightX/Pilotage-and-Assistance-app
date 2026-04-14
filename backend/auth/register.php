<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method tidak diizinkan"]);
    exit;
}

require_once __DIR__ . "/../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$name = trim($data["name"] ?? '');
$email = trim($data["email"] ?? '');
$password = trim($data["password"] ?? '');
$role = strtolower(trim($data["role"] ?? 'pilot'));
$requesterUserId = (int)($data["requester_user_id"] ?? 0);

if ($requesterUserId <= 0) {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Akses ditolak. Hanya superadmin yang dapat menambah user."]);
    exit;
}

$authStmt = $conn->prepare("SELECT role FROM users WHERE id = ? LIMIT 1");
if (!$authStmt) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal validasi akses"]);
    exit;
}
$authStmt->bind_param("i", $requesterUserId);
$authStmt->execute();
$authResult = $authStmt->get_result();
$requester = $authResult->fetch_assoc();
$authStmt->close();

if (!$requester || strtolower(trim($requester["role"] ?? "")) !== "superadmin") {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Akses ditolak. Hanya superadmin yang dapat menambah user."]);
    exit;
}

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
$check = $conn->prepare("SELECT id FROM users WHERE LOWER(email) = LOWER(?)");
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
        "message" => "User berhasil ditambahkan",
        "data" => [
            "id" => $conn->insert_id,
            "name" => $name,
            "email" => $email,
            "role" => $role
        ]
    ]);
} else {
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan data: " . $stmt->error]);
}

$stmt->close();
$conn->close();
