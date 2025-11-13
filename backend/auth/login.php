<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}

try {
    // Path relatif dari backend/auth/ ke config/
    require_once __DIR__ . "/../config/config.php";

    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Database connection failed");
    }

    $data = json_decode(file_get_contents("php://input"), true);

    if (!$data) {
        throw new Exception("Invalid JSON data");
    }

    $email = $data["email"] ?? '';
    $passwordInput = $data["password"] ?? '';

    if (empty($email) || empty($passwordInput)) {
        throw new Exception("Email dan password wajib diisi");
    }

    $sql = "SELECT * FROM users WHERE email = ?";
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare failed");
    }

    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $user = $result->fetch_assoc();

        // Perbandingan plaintext (sesuai dengan kode lama Anda)
        if ($passwordInput === $user['password']) {
            ob_end_clean();
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
            throw new Exception("Password salah");
        }
    } else {
        throw new Exception("Email tidak ditemukan");
    }

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    ob_end_clean();
    http_response_code(401);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}