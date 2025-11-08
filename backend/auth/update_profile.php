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

require_once "../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$userId = $data["user_id"] ?? 0;
$name = $data["name"] ?? '';
$email = $data["email"] ?? '';

// Validasi input
if (empty($userId) || empty($name) || empty($email)) {
    echo json_encode([
        "status" => "error", 
        "message" => "User ID, nama, dan email wajib diisi"
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

// Cek apakah email sudah digunakan oleh user lain
$sqlCheck = "SELECT id FROM users WHERE email = ? AND id != ?";
$stmtCheck = $conn->prepare($sqlCheck);
$stmtCheck->bind_param("si", $email, $userId);
$stmtCheck->execute();
$resultCheck = $stmtCheck->get_result();

if ($resultCheck->num_rows > 0) {
    echo json_encode([
        "status" => "error", 
        "message" => "Email sudah digunakan oleh user lain"
    ]);
    exit;
}

// Update data user
$sql = "UPDATE users SET name = ?, email = ? WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ssi", $name, $email, $userId);

if ($stmt->execute()) {
    // Ambil data user yang sudah diupdate
    $sqlSelect = "SELECT id, name, email, role FROM users WHERE id = ?";
    $stmtSelect = $conn->prepare($sqlSelect);
    $stmtSelect->bind_param("i", $userId);
    $stmtSelect->execute();
    $result = $stmtSelect->get_result();
    
    if ($result->num_rows > 0) {
        $user = $result->fetch_assoc();
        echo json_encode([
            "status" => "success",
            "message" => "Profile berhasil diupdate",
            "data" => [
                "id" => $user['id'],
                "name" => $user['name'],
                "email" => $user['email'],
                "role" => $user['role']
            ]
        ]);
    } else {
        echo json_encode([
            "status" => "error", 
            "message" => "Data user tidak ditemukan"
        ]);
    }
} else {
    echo json_encode([
        "status" => "error", 
        "message" => "Gagal update profile: " . $stmt->error
    ]);
}

$conn->close();
?>