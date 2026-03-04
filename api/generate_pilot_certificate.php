<?php
// generate_pilot_certificate.php

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once __DIR__ . '/../backend/vendor/autoload.php';
require_once __DIR__ . '/../backend/config/config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Accept both GET and POST requests
    $pilotageId = null;
    $signatureBase64 = null;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $pilotageId = isset($input['id']) ? (int) $input['id'] : null;
        $signatureBase64 = isset($input['signature']) ? $input['signature'] : null;
        if (is_string($signatureBase64)) {
            $signatureBase64 = trim($signatureBase64);
            if ($signatureBase64 === '') {
                $signatureBase64 = null;
            }
        }
        
        // Log untuk debugging
        error_log("Received POST request with ID: $pilotageId");
        error_log("Signature received: " . ($signatureBase64 ? "YES" : "NO"));
    } else {
        $pilotageId = isset($_GET['id']) ? (int) $_GET['id'] : null;
    }
    
    if (!$pilotageId) throw new Exception("ID pilotage tidak ditemukan");

    // Ambil data dari database
    $sql = "SELECT * FROM activity_logs WHERE id = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare query gagal: " . $conn->error);
    $stmt->bind_param("i", $pilotageId);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result->num_rows === 0) throw new Exception("Data tidak ditemukan");
    $data = $result->fetch_assoc();

    // Buat PDF
    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    $pdf->SetCreator('PT. SNEPAC INDO SERVICE');
    $pdf->SetAuthor('PT. SNEPAC INDO SERVICE');
    $pdf->SetTitle('Pilot Certificate - ' . ($data['vessel_name'] ?? ''));
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetAutoPageBreak(false);
    $pdf->AddPage();

    // Background image
    $bgPath = __DIR__ . '/../backend/assets/form_pandu.jpg';
    if (file_exists($bgPath)) {
        $pdf->Image($bgPath, 0, 0, 210, 297, '', '', '', false, 300, '', false, false, 0);
    }

    // Helper functions (tetap sama)
    function putText($pdf, $x, $y, $text, $font='helvetica', $style='', $size=9, $align='L') {
        $text = (string) $text;
        $text = iconv('UTF-8', 'UTF-8//IGNORE', $text);
        $text = trim(substr($text, 0, 50));
        $pdf->SetFont($font, $style, $size);
        $pdf->SetXY($x, $y);
        $pdf->Cell(0, 4, $text, 0, 0, $align);
    }

    function safeValue($val) {
        if ($val === null || $val === '') return '';
        $val = trim($val);
        $val = iconv('UTF-8', 'UTF-8//IGNORE', $val);
        return mb_strtoupper($val, 'UTF-8');
    }

    /**
     * Decode signature base64 and crop to non-white/non-transparent strokes.
     * Returns PNG binary data ready for TCPDF Image('@...').
     */
    function prepareSignatureImageData($signatureBase64) {
        if (!is_string($signatureBase64) || trim($signatureBase64) === '') {
            return false;
        }

        $signatureData = preg_replace('/^data:image\/[a-zA-Z0-9\+\-\.]+;base64,/', '', trim($signatureBase64));
        $signatureData = str_replace(' ', '+', $signatureData);
        $decoded = base64_decode($signatureData, true);
        if ($decoded === false) {
            return false;
        }

        // Fallback if GD extension is not available
        if (!function_exists('imagecreatefromstring') || !function_exists('imagecrop') || !function_exists('imagepng')) {
            return $decoded;
        }

        $img = @imagecreatefromstring($decoded);
        if (!$img) {
            return $decoded;
        }

        $width = imagesx($img);
        $height = imagesy($img);
        $minX = $width;
        $minY = $height;
        $maxX = -1;
        $maxY = -1;

        for ($y = 0; $y < $height; $y++) {
            for ($x = 0; $x < $width; $x++) {
                $rgba = imagecolorat($img, $x, $y);
                $a = ($rgba & 0x7F000000) >> 24; // 0 opaque, 127 transparent
                $r = ($rgba >> 16) & 0xFF;
                $g = ($rgba >> 8) & 0xFF;
                $b = $rgba & 0xFF;

                $isTransparent = $a >= 127;
                $isWhite = ($r >= 245 && $g >= 245 && $b >= 245);
                if (!$isTransparent && !$isWhite) {
                    if ($x < $minX) $minX = $x;
                    if ($y < $minY) $minY = $y;
                    if ($x > $maxX) $maxX = $x;
                    if ($y > $maxY) $maxY = $y;
                }
            }
        }

        // No visible strokes found
        if ($maxX < 0 || $maxY < 0) {
            imagedestroy($img);
            return $decoded;
        }

        $padding = 2;
        $cropX = max(0, $minX - $padding);
        $cropY = max(0, $minY - $padding);
        $cropW = min($width - $cropX, ($maxX - $minX + 1) + ($padding * 2));
        $cropH = min($height - $cropY, ($maxY - $minY + 1) + ($padding * 2));

        $cropped = imagecrop($img, [
            'x' => $cropX,
            'y' => $cropY,
            'width' => $cropW,
            'height' => $cropH,
        ]);

        if (!$cropped) {
            imagedestroy($img);
            return $decoded;
        }

        imagealphablending($cropped, false);
        imagesavealpha($cropped, true);

        ob_start();
        imagepng($cropped);
        $croppedData = ob_get_clean();

        imagedestroy($cropped);
        imagedestroy($img);

        return $croppedData !== false ? $croppedData : $decoded;
    }

    // ===============================================
    // TAMBAHKAN TANDA TANGAN KE PDF (LANGSUNG DARI REQUEST)
    // ===============================================
    if (!empty($signatureBase64)) {
        error_log("Processing signature...");
        
        try {
            $signatureImage = prepareSignatureImageData($signatureBase64);
            
            if ($signatureImage === false) {
                error_log("Failed to decode signature base64 (pilot)");
            } else {
                error_log("Signature decoded successfully, size: " . strlen($signatureImage));
                
                // Tambahkan gambar tanda tangan ke PDF
                // Koordinat disesuaikan dengan posisi di form Anda
                $pdf->Image(
                    '@' . $signatureImage,  // @ prefix untuk image dari string
                    140,                     // X position
                    250,                     // Y position
                    50,                      // Width
                    20,                      // Height
                    '',                      // Format autodetect
                    '',                      // Link
                    '',                      // Align
                    true,                    // Resize
                    150,                     // DPI
                    '',                      // Palign
                    false,                   // Ismask
                    false,                   // Imgmask
                    0                        // Border
                );
                
                error_log("Signature added to PDF successfully");
            }
        } catch (Exception $e) {
            error_log("Error adding signature to PDF: " . $e->getMessage());
            // Lanjutkan generate PDF tanpa signature jika error
        }
    } else {
        error_log("No signature provided");
    }

    // Fill data ke PDF (kode existing tetap sama)
    // No. BTM
    $noBTM = $data['certificate_no'] ?? '6501-3479';
    putText($pdf, 175, 15, $noBTM, 'helvetica', 'B', 10, 'R');

    // VESSEL INFORMATION (kolom kiri)
    putText($pdf, 41, 55, safeValue($data['vessel_name']), 'helvetica', '', 12);
    putText($pdf, 41, 64, safeValue($data['master_name']), 'helvetica', '', 12);
    // ... (semua field lainnya tetap sama)

    // Output PDF
    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', $data['vessel_name'] ?? 'pilot_certificate');
    $filename = "Pilot_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";
    
    ob_end_clean();
    
    // Set header untuk download
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Cache-Control: private, max-age=0, must-revalidate');
    header('Pragma: public');
    
    $pdf->Output($filename, 'I');

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    error_log("PDF Generation Error: " . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error', 
        'message' => $e->getMessage()
    ]);
}
?>
