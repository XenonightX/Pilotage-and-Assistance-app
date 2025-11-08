<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

require_once "../config/config.php";

$data = json_decode(file_get_contents("php://input"), true);
$email = $data["email"] ?? '';
$passwordInput = $data["password"] ?? '';

if (empty($email) || empty($passwordInput)) {
    echo json_encode(["status" => "error", "message" => "Email dan password wajib diisi"]);
    exit;
}

$sql = "SELECT * FROM users WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $user = $result->fetch_assoc();

    // Perbandingan plaintext (TANPA HASH)
    if ($passwordInput === $user['password']) {
        echo json_encode([
            "status"  => "success",
            "message" => "Login berhasil",
            "data"    => [
                "id"    => $user['id'],
                "name"  => $user['name'],
                "email" => $user['email'],
                "role"  => $user['role']
            ]
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "Password salah"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Email tidak ditemukan"]);
}

$conn->close();
?>
