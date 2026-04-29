<?php
// generate_pilot_certificate.php
// Custom 2A1 layout: Bukti Pemakaian Jasa Pandu

error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

require_once __DIR__ . '/../backend/vendor/autoload.php';
require_once __DIR__ . '/../backend/config/config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (!function_exists('textOrEmpty')) {
    function textOrEmpty($value): string
    {
        if ($value === null) {
            return '';
        }
        $text = trim((string) $value);
        if ($text === '') {
            return '';
        }
        $normalized = preg_replace('/\s+/u', ' ', $text);
        if (is_string($normalized) && $normalized !== '') {
            $text = $normalized;
        }
        $converted = @iconv('UTF-8', 'UTF-8//IGNORE', $text);
        return $converted === false ? $text : $converted;
    }
}

if (!function_exists('upperOrEmpty')) {
    function upperOrEmpty($value): string
    {
        $text = textOrEmpty($value);
        if ($text === '') {
            return '';
        }
        return function_exists('mb_strtoupper')
            ? mb_strtoupper($text, 'UTF-8')
            : strtoupper($text);
    }
}

if (!function_exists('pickValue')) {
    function pickValue(array $data, array $keys, string $default = ''): string
    {
        foreach ($keys as $key) {
            if (array_key_exists($key, $data)) {
                $value = textOrEmpty($data[$key]);
                if ($value !== '') {
                    return $value;
                }
            }
        }
        return $default;
    }
}

if (!function_exists('formatDateValue')) {
    function formatDateValue($value, string $format = 'd-m-Y'): string
    {
        $text = textOrEmpty($value);
        if ($text === '' || $text === '0000-00-00' || $text === '0000-00-00 00:00:00') {
            return '';
        }
        $timestamp = strtotime($text);
        if ($timestamp === false || $timestamp <= 0) {
            return '';
        }
        return date($format, $timestamp);
    }
}

if (!function_exists('formatTimeValue')) {
    function formatTimeValue($value): string
    {
        $text = textOrEmpty($value);
        if ($text === '' || $text === '0000-00-00 00:00:00') {
            return '';
        }
        $timestamp = strtotime($text);
        if ($timestamp === false || $timestamp <= 0) {
            return '';
        }
        return date('H:i', $timestamp);
    }
}

if (!function_exists('appendUnit')) {
    function appendUnit($value, string $unit): string
    {
        $text = textOrEmpty($value);
        if ($text === '') {
            return '';
        }
        if (stripos($text, $unit) !== false) {
            return $text;
        }
        return $text . ' ' . $unit;
    }
}

if (!function_exists('buildCertificateNumber')) {
    function buildCertificateNumber(array $data): string
    {
        $existing = pickValue($data, ['certificate_no', 'document_no', 'doc_no']);
        if ($existing !== '') {
            return $existing;
        }
        $dateValue = pickValue($data, ['date', 'created_at'], date('Y-m-d'));
        $timestamp = strtotime($dateValue) ?: time();
        $yearMonth = date('ym', $timestamp);
        $id = isset($data['id']) ? (int) $data['id'] : 0;
        return 'BKT/PANDU/IDBTM/SIS/' . $yearMonth . '/' . str_pad((string) max($id, 1), 5, '0', STR_PAD_LEFT);
    }
}

if (!function_exists('buildDownloadFilename2A1')) {
    function buildDownloadFilename2A1(array $data): string
    {
        $dateValue = pickValue($data, ['date', 'created_at'], date('Y-m-d'));
        $timestamp = strtotime($dateValue) ?: time();
        $yearMonth = date('ym', $timestamp);
        $id = isset($data['id']) ? (int) $data['id'] : 0;

        return 'BKT_PANDU_IDBTM_SIS_' . $yearMonth . '_' . str_pad((string) max($id, 1), 5, '0', STR_PAD_LEFT) . '.pdf';
    }
}

if (!function_exists('buildServiceRequestNumber')) {
    function buildServiceRequestNumber(array $data): string
    {
        $existing = pickValue($data, ['request_no', 'service_request_no', 'permohonan_no', 'job_order_no']);
        if ($existing !== '') {
            return $existing;
        }
        $dateValue = pickValue($data, ['date', 'created_at'], date('Y-m-d'));
        $timestamp = strtotime($dateValue) ?: time();
        $id = isset($data['id']) ? (int) $data['id'] : 0;
        return date('Ymd', $timestamp) . str_pad((string) max($id, 1), 4, '0', STR_PAD_LEFT);
    }
}

if (!function_exists('hasUserSignatureColumn')) {
    function hasUserSignatureColumn($conn): bool
    {
        static $checked = null;
        if ($checked !== null) {
            return $checked;
        }
        $result = $conn->query("SHOW COLUMNS FROM users LIKE 'signature_data'");
        $checked = $result && $result->num_rows > 0;
        return $checked;
    }
}

if (!function_exists('buildQrPayload')) {
    function detectRequestScheme(): string
    {
        $forwardedProto = textOrEmpty($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '');
        if ($forwardedProto !== '') {
            $parts = explode(',', $forwardedProto);
            $proto = strtolower(trim($parts[0]));
            if (in_array($proto, ['http', 'https'], true)) {
                return $proto;
            }
        }

        $https = strtolower((string) ($_SERVER['HTTPS'] ?? ''));
        if ($https !== '' && $https !== 'off' && $https !== '0') {
            return 'https';
        }

        return 'http';
    }

    function buildSignatureVerificationBaseUrl(): string
    {
        $configuredBaseUrl = trim((string) getenv('SIGNATURE_VERIFY_BASE_URL'));
        if ($configuredBaseUrl !== '') {
            return rtrim($configuredBaseUrl, '/');
        }

        if (defined('SIGNATURE_VERIFY_BASE_URL')) {
            $definedBaseUrl = trim((string) constant('SIGNATURE_VERIFY_BASE_URL'));
            if ($definedBaseUrl !== '') {
                return rtrim($definedBaseUrl, '/');
            }
        }

        $host = textOrEmpty($_SERVER['HTTP_X_FORWARDED_HOST'] ?? ($_SERVER['HTTP_HOST'] ?? ''));
        if ($host === '') {
            return '';
        }

        $scriptDir = str_replace('\\', '/', dirname((string) ($_SERVER['SCRIPT_NAME'] ?? '')));
        $projectDir = rtrim(str_replace('\\', '/', dirname($scriptDir)), '/.');
        if ($projectDir === '/') {
            $projectDir = '';
        }

        return detectRequestScheme() . '://' . $host . $projectDir;
    }

    function buildQrPayload(string $documentType, int $documentId, string $slot, string $name, string $role, string $source): string
    {
        $hash = substr(hash('sha256', $source), 0, 20);
        $baseUrl = buildSignatureVerificationBaseUrl();
        if ($baseUrl === '') {
            return implode('|', [
                'SIG',
                $documentType,
                (string) $documentId,
                $slot,
                $hash,
            ]);
        }

        return $baseUrl . '/api/verify_signature.php?' . http_build_query([
            'd' => $documentType,
            'i' => $documentId,
            's' => $slot,
            'k' => $hash,
        ]);
    }
}

if (!function_exists('buildProfileQrPayload')) {
    function buildProfileQrPayload(?array $profile, string $fallbackName, string $fallbackRole, string $documentType, int $documentId, string $slot): string
    {
        $name   = textOrEmpty($profile['name'] ?? $fallbackName);
        $role   = textOrEmpty($profile['role'] ?? $fallbackRole);
        $source = textOrEmpty($profile['signature_data'] ?? '');
        if ($source === '') {
            $source = $name . '|' . $role . '|NOSIG';
        }
        return buildQrPayload($documentType, $documentId, $slot, $name, $role, $source);
    }
}

if (!function_exists('buildActivityQrPayload')) {
    function buildActivityQrPayload(string $name, string $documentType, int $documentId, string $slot, $signatureBase64): string
    {
        $source = textOrEmpty($signatureBase64);
        if ($source === '') {
            $source = $name . '|NOSIG';
        }
        return buildQrPayload($documentType, $documentId, $slot, $name, 'external', $source);
    }
}

if (!function_exists('putText')) {
    function putText($pdf, float $x, float $y, string $text, string $font = 'helvetica', string $style = '', float $size = 9, string $align = 'L', float $width = 0, float $height = 4): void
    {
        $text = textOrEmpty($text);
        $pdf->SetFont($font, $style, $size);
        $pdf->SetXY($x, $y);
        $pdf->Cell($width, $height, $text, 0, 0, $align, false, '', 0, false, 'T', 'M');
    }
}

if (!function_exists('drawLine')) {
    function drawLine($pdf, float $x1, float $y1, float $x2, float $y2, float $width = 0.2): void
    {
        $pdf->SetLineWidth($width);
        $pdf->Line($x1, $y1, $x2, $y2);
    }
}

if (!function_exists('putFitText')) {
    function putFitText($pdf, float $x, float $y, string $text, float $maxWidth, float $size = 9, string $style = '', string $align = 'L'): void
    {
        $text = textOrEmpty($text);
        if ($text === '') {
            return;
        }
        $fontSize = $size;
        $pdf->SetFont('helvetica', $style, $fontSize);
        while ($fontSize > 6.2 && $pdf->GetStringWidth($text) > $maxWidth) {
            $fontSize -= 0.2;
            $pdf->SetFont('helvetica', $style, $fontSize);
        }
        $pdf->SetXY($x, $y);
        $pdf->Cell($maxWidth, 4, $text, 0, 0, $align, false, '', 0, false, 'T', 'M');
    }
}

if (!function_exists('drawFieldRow')) {
    function drawFieldRow($pdf, float $x, float $y, string $labelId, string $labelEn, string $value, float $labelWidth = 31, float $lineWidth = 63, float $valueSize = 9): void
    {
        putText($pdf, $x, $y, $labelId, 'helvetica', '', 7.9);
        putText($pdf, $x, $y + 4.1, $labelEn, 'helvetica', 'I', 6.7);
        putText($pdf, $x + $labelWidth, $y + 0.8, ':', 'helvetica', '', 9);
        $valueX = $x + $labelWidth + 3.5;
        drawLine($pdf, $valueX, $y + 8.0, $valueX + $lineWidth, $y + 8.0, 0.15);
        putFitText($pdf, $valueX, $y + 1.0, $value, $lineWidth - 1, $valueSize);
    }
}

if (!function_exists('drawEventRow')) {
    function drawEventRow($pdf, float $x, float $y, string $labelId, string $labelEn, $dateTimeValue): void
    {
        $dateText = formatDateValue($dateTimeValue);
        $timeText = formatTimeValue($dateTimeValue);

        putText($pdf, $x, $y, $labelId, 'helvetica', '', 8.7);
        putText($pdf, $x, $y + 4.0, $labelEn, 'helvetica', 'I', 6.7);

        putText($pdf, $x + 29.5, $y + 1.0, ':', 'helvetica', '', 9);
        drawLine($pdf, $x + 32, $y + 8.1, $x + 56.5, $y + 8.1, 0.15);
        putFitText($pdf, $x + 33, $y + 1.1, $dateText, 22.5, 8.3);

        putText($pdf, $x + 57.5, $y, 'Pukul', 'helvetica', '', 8.3);
        putText($pdf, $x + 57.5, $y + 4.0, 'Time', 'helvetica', 'I', 6.5);
        putText($pdf, $x + 72.0, $y + 1.0, ':', 'helvetica', '', 9);
        drawLine($pdf, $x + 74.5, $y + 8.1, $x + 91.5, $y + 8.1, 0.15);
        putFitText($pdf, $x + 75.5, $y + 1.1, $timeText, 14.5, 8.3);
    }
}

// FIX: drawQrBlock untuk 2A1 — NAMA/NAME tidak lagi tertimpa QR
// QR: $y+10 s/d $y+32. Label "NAMA/NAME" di $y+34, garis di $y+40, nama di $y+41.
if (!function_exists('drawQrBlock')) {
    function drawQrBlock($pdf, float $x, float $y, string $titleId, string $titleEn, string $name, string $qrPayload): void
    {
        $width = 54;

        // Judul bilingual
        putText($pdf, $x, $y, $titleId, 'helvetica', 'B', 9.2, 'C', $width, 4);
        putText($pdf, $x, $y + 4.6, $titleEn, 'helvetica', 'I', 6.7, 'C', $width, 4);

        // QR code: mulai y+10, tinggi 22 → berakhir y+32
        $style = [
            'border'  => 0,
            'padding' => 0,
            'fgcolor' => [0, 0, 0],
            'bgcolor' => false,
        ];
        $qrX = $x + 16;
        $qrY = $y + 10;
        $pdf->write2DBarcode($qrPayload, 'QRCODE,H', $qrX, $qrY, 22, 22, $style, 'N');

        // Label "NAMA / NAME" — ditempatkan 2mm di bawah QR (y+34), jauh dari area QR
        putText($pdf, $x, $y + 36, 'NAMA / NAME', 'helvetica', 'B', 7.1, 'C', $width, 4);

        // Garis pembatas nama di y+40
        $nameLineY = $y + 42;
        drawLine($pdf, $x + 2, $nameLineY, $x + $width - 2, $nameLineY, 0.2);

        // Teks nama di bawah garis
        putFitText($pdf, $x + 2, $nameLineY + 1.0, $name, $width - 4, 8.1, '', 'C');
    }
}

if (!function_exists('prepareSignatureImageData')) {
    function prepareSignatureImageData($signatureBase64)
    {
        if (!is_string($signatureBase64) || trim($signatureBase64) === '') {
            return false;
        }
        $signatureData = preg_replace('/^data:image\/[a-zA-Z0-9\+\-\.]+;base64,/', '', trim($signatureBase64));
        $signatureData = str_replace(' ', '+', $signatureData);
        $decoded = base64_decode($signatureData, true);
        if ($decoded === false) {
            return false;
        }
        if (!function_exists('imagecreatefromstring') || !function_exists('imagecrop') || !function_exists('imagepng')) {
            return $decoded;
        }
        $img = @imagecreatefromstring($decoded);
        if (!$img) {
            return $decoded;
        }
        $width  = imagesx($img);
        $height = imagesy($img);
        $minX = $width;
        $minY = $height;
        $maxX = -1;
        $maxY = -1;
        for ($y = 0; $y < $height; $y++) {
            for ($x = 0; $x < $width; $x++) {
                $rgba = imagecolorat($img, $x, $y);
                $a = ($rgba & 0x7F000000) >> 24;
                $r = ($rgba >> 16) & 0xFF;
                $g = ($rgba >> 8) & 0xFF;
                $b = $rgba & 0xFF;
                $isTransparent = $a >= 127;
                $isWhite = ($r >= 245 && $g >= 245 && $b >= 245);
                if (!$isTransparent && !$isWhite) {
                    $minX = min($minX, $x);
                    $minY = min($minY, $y);
                    $maxX = max($maxX, $x);
                    $maxY = max($maxY, $y);
                }
            }
        }
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
            'x'      => $cropX,
            'y'      => $cropY,
            'width'  => $cropW,
            'height' => $cropH,
        ]);
        if (!$cropped) {
            imagedestroy($img);
            return $decoded;
        }
        imagealphablending($cropped, false);
        imagesavealpha($cropped, true);
        $croppedWidth  = imagesx($cropped);
        $croppedHeight = imagesy($cropped);
        $transparent   = imagecolorallocatealpha($cropped, 255, 255, 255, 127);
        for ($yy = 0; $yy < $croppedHeight; $yy++) {
            for ($xx = 0; $xx < $croppedWidth; $xx++) {
                $rgba = imagecolorat($cropped, $xx, $yy);
                $a = ($rgba & 0x7F000000) >> 24;
                $r = ($rgba >> 16) & 0xFF;
                $g = ($rgba >> 8) & 0xFF;
                $b = $rgba & 0xFF;
                if ($a < 127 && $r >= 230 && $g >= 230 && $b >= 230) {
                    imagesetpixel($cropped, $xx, $yy, $transparent);
                }
            }
        }
        ob_start();
        imagepng($cropped);
        $croppedData = ob_get_clean();
        imagedestroy($cropped);
        imagedestroy($img);
        return $croppedData !== false ? $croppedData : $decoded;
    }
}

if (!function_exists('placeSignature')) {
    function placeSignature($pdf, $signatureBinary, float $x, float $y, float $w, float $h): bool
    {
        if ($signatureBinary === false || $signatureBinary === null || $signatureBinary === '') {
            return false;
        }
        $placed = false;
        $useBlendMultiply = method_exists($pdf, 'SetAlpha');
        if ($useBlendMultiply) {
            $pdf->SetAlpha(1, 'Multiply');
        }
        try {
            $pdf->Image('@' . $signatureBinary, $x, $y, $w, $h, 'PNG', '', '', true, 150, '', false, false, 0);
            $placed = true;
        } catch (Exception $e) {
            error_log("Inline signature placement failed (pilot): " . $e->getMessage());
        }
        if (!$placed) {
            $tmpFile = tempnam(sys_get_temp_dir(), 'sig_pilot_');
            if ($tmpFile !== false) {
                $tmpPng  = $tmpFile . '.png';
                @unlink($tmpFile);
                $written = @file_put_contents($tmpPng, $signatureBinary);
                if ($written !== false) {
                    try {
                        $pdf->Image($tmpPng, $x, $y, $w, $h, 'PNG', '', '', true, 150, '', false, false, 0);
                        $placed = true;
                    } catch (Exception $e) {
                        error_log("Temp signature placement failed (pilot): " . $e->getMessage());
                    }
                }
                @unlink($tmpPng);
            }
        }
        if ($useBlendMultiply) {
            $pdf->SetAlpha(1, 'Normal');
        }
        return $placed;
    }
}

// Fungsi resolusi signature — unik untuk 2A1, tidak perlu function_exists
function resolveManagerSignatureProfile_2A1($conn, int $requesterUserId, string $requesterRole): ?array
{
    if (!hasUserSignatureColumn($conn)) {
        return null;
    }

    $sql    = "SELECT id, name, role, signature_data
               FROM users
               WHERE LOWER(TRIM(COALESCE(role, ''))) IN ('admin', 'superadmin')
               AND TRIM(COALESCE(signature_data, '')) <> ''
               ORDER BY id ASC
               LIMIT 1";
    $result = $conn->query($sql);
    if ($result && $result->num_rows > 0) {
        return $result->fetch_assoc();
    }
    return null;
}

function resolvePilotSignatureProfile_2A1($conn, int $pilotUserId, string $pilotName): ?array
{
    if (!hasUserSignatureColumn($conn)) {
        return null;
    }

    if ($pilotUserId > 0) {
        $sql  = "SELECT id, name, role, signature_data
                 FROM users
                 WHERE id = ?
                 AND LOWER(TRIM(COALESCE(role, ''))) IN ('pilot', 'pandu')
                 LIMIT 1";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param("i", $pilotUserId);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($result && $result->num_rows > 0) {
                return $result->fetch_assoc();
            }
        }
    }

    if (textOrEmpty($pilotName) === '') {
        return null;
    }

    $sql  = "SELECT id, name, role, signature_data
             FROM users
             WHERE LOWER(TRIM(COALESCE(name, ''))) = LOWER(TRIM(?))
             AND LOWER(TRIM(COALESCE(role, ''))) IN ('pilot', 'pandu')
             LIMIT 1";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param("s", $pilotName);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result && $result->num_rows > 0) {
        return $result->fetch_assoc();
    }
    return null;
}

// ─── MAIN ────────────────────────────────────────────────────────────────────
try {
    $pilotageId      = null;
    $signatureBase64 = null;
    $requesterUserId = 0;
    $requesterName   = '';
    $requesterRole   = '';

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $pilotageId      = isset($input['id'])                ? (int) $input['id']                : null;
        $signatureBase64 = isset($input['signature'])         ? $input['signature']               : null;
        $requesterUserId = isset($input['requester_user_id']) ? (int) $input['requester_user_id'] : 0;
        $requesterName   = textOrEmpty($input['requester_name'] ?? '');
        $requesterRole   = textOrEmpty($input['requester_role'] ?? '');

        if (is_string($signatureBase64)) {
            $signatureBase64 = trim($signatureBase64);
            if ($signatureBase64 === '') {
                $signatureBase64 = null;
            }
        }
        error_log("Received POST request with ID: " . ($pilotageId ?? 0));
        error_log("Signature received: " . ($signatureBase64 ? "YES" : "NO"));
    } else {
        $pilotageId = isset($_GET['id']) ? (int) $_GET['id'] : null;
    }

    if (!$pilotageId) {
        throw new Exception("ID pilotage tidak ditemukan");
    }

    $sql  = "SELECT * FROM activity_logs WHERE id = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare query gagal: " . $conn->error);
    }
    $stmt->bind_param("i", $pilotageId);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result->num_rows === 0) {
        throw new Exception("Data tidak ditemukan");
    }
    $data = $result->fetch_assoc();

    if (empty($signatureBase64) && isset($data['signature']) && !empty($data['signature'])) {
        $signatureBase64 = $data['signature'];
        error_log("Using signature from database for ID: $pilotageId");
    }

    // ── PDF init ──────────────────────────────────────────────────────────────
    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    $pdf->SetCreator('PT. SNEPAC INDO SERVICE');
    $pdf->SetAuthor('PT. SNEPAC INDO SERVICE');
    $pdf->SetTitle('Pilot Certificate - ' . textOrEmpty($data['vessel_name'] ?? ''));
    $pdf->SetMargins(0, 0, 0);
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetAutoPageBreak(false);
    $pdf->AddPage();

    $pdf->SetDrawColor(40, 40, 40);
    $pdf->SetTextColor(20, 20, 20);
    $pdf->SetLineWidth(0.35);
    $pdf->Rect(5, 5, 200, 287);

    // ── Logo ──────────────────────────────────────────────────────────────────
    $logoPath = __DIR__ . '/../backend/assets/NO-BG-LOGO-SIS.png';
    if (file_exists($logoPath)) {
        $pdf->Image($logoPath, 11, 11, 28, 18, 'PNG', '', '', true, 300, '', false, false, 0);
        $pdf->Image($logoPath, 171, 11, 24, 15, 'PNG', '', '', true, 300, '', false, false, 0);
    }

    // ── Header ────────────────────────────────────────────────────────────────
    putText($pdf, 45, 13, 'PEMANDUAN DAN PENUNDAAN',                 'helvetica', 'B', 13,   'C', 120, 5);
    putText($pdf, 45, 20, 'DAERAH PERAIRAN WAJIB PANDU BATAM',       'helvetica', 'B', 11.5, 'C', 120, 5);
    putText($pdf, 45, 26, 'PT. SNEPAC INDO SERVICE',                 'helvetica', '',  8.7,  'C', 120, 4);
    drawLine($pdf, 10, 33, 200, 33, 0.35);

    // ── Resolve data ──────────────────────────────────────────────────────────
    $certificateNumber = buildCertificateNumber($data);
    $requestNumber     = buildServiceRequestNumber($data);
    $pilotCode         = pickValue($data, ['pilot_code', 'pilot_license_no', 'pilot_nip', 'pilot_identifier'], '-');
    $description       = pickValue($data, ['description', 'keterangan', 'remarks'], '-');
    $managerProfile    = resolveManagerSignatureProfile_2A1($conn, $requesterUserId, $requesterRole);

    $managerName  = upperOrEmpty('MOHAMMAD ADAM');
    $pilotProfile = resolvePilotSignatureProfile_2A1(
        $conn,
        isset($data['pilot_user_id']) ? (int) $data['pilot_user_id'] : 0,
        textOrEmpty($data['pilot_name'] ?? '')
    );

    // ── Title block ───────────────────────────────────────────────────────────
    putText($pdf, 20, 36.5, 'BUKTI PEMAKAIAN JASA PANDU', 'helvetica', 'B', 12, 'C', 170, 5);
    putText($pdf, 20, 42.2, 'PILOTAGE SERVICE',            'helvetica', 'I', 8.7, 'C', 170, 4);
    putText($pdf, 20, 47.0, 'Nomor : ' . $certificateNumber, 'helvetica', '', 8.8, 'C', 170, 4);

    // ── Field rows ────────────────────────────────────────────────────────────
    $leftX     = 10;
    $rightX    = 104;
    $rowStartY = 54;
    $rowGap    = 12.5;

    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 0), 'Nama Kapal',    'Vessel Name',       upperOrEmpty($data['vessel_name']  ?? ''), 28, 60, 9.4);
    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 1), 'Nama Nakhoda',  'Ship Master',       upperOrEmpty($data['master_name']  ?? ''), 28, 60, 9.2);
    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 2), 'Bendera',       'Flag',              upperOrEmpty($data['flag']         ?? ''), 28, 60, 9.0);
    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 3), 'Datang Dari',   'Last Port of Call', upperOrEmpty($data['last_port']    ?? ''), 28, 60, 8.7);
    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 4), 'Isi Kotor',     'G.R.T.',            appendUnit($data['gross_tonnage']  ?? '', 'Ton'), 28, 60, 8.9);
    drawFieldRow($pdf, $leftX,  $rowStartY + ($rowGap * 5), 'Panjang',       'L.O.A',             appendUnit($data['loa']            ?? '', 'm'),   28, 60, 8.9);

    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 0), 'Panggilan',     'Call Sign',         upperOrEmpty($data['call_sign']    ?? ''), 28, 60, 9.2);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 1), 'Keagenan Kapal','Agency',            upperOrEmpty($data['agency']       ?? ''), 28, 60, 8.4);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 2), 'Keterangan',    'Description',       upperOrEmpty($description),                28, 60, 8.4);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 3), 'Tujuan Ke',     'Next Port Of Call', upperOrEmpty($data['next_port']    ?? ''), 28, 60, 8.7);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 4), 'Sarat Muka',    'Fore Draft',        appendUnit($data['fore_draft']     ?? '', 'm'),   28, 60, 8.9);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 5), 'Sarat Belakang','Rear Draft',        appendUnit($data['aft_draft']      ?? '', 'm'),   28, 60, 8.9);

    // ── Statement block ───────────────────────────────────────────────────────
    $statementY = 132;
    putFitText($pdf, 10, $statementY, 'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA PANDU NO : ' . $requestNumber, 190, 9.1, 'B');
    putText($pdf, 10, $statementY + 4.6, 'DECLARES THAT IN ACCORDANCE WITH', 'helvetica', 'I', 7.1);

    putText($pdf, 10, $statementY + 11,   'IA TELAH DIPANDU OLEH PANDU',             'helvetica', 'B', 9.2);
    putText($pdf, 10, $statementY + 15.4, 'SHE HAS BEEN PILOTED BY THE MARINE PILOT','helvetica', 'I', 7.0);

    putText($pdf, 70, $statementY + 12.0, ':', 'helvetica', '', 9.5);
    drawLine($pdf, 73, $statementY + 19.0, 150, $statementY + 19.0, 0.15);
    putFitText($pdf, 74, $statementY + 12.2, upperOrEmpty($data['pilot_name'] ?? ''), 74, 9.4);

    putText($pdf, 155, $statementY + 11.0, 'Kode', 'helvetica', '', 8.8);
    putText($pdf, 155, $statementY + 15.4, 'Code', 'helvetica', 'I', 6.7);
    putText($pdf, 168.5, $statementY + 12.0, ':', 'helvetica', '', 9.5);
    drawLine($pdf, 171, $statementY + 19.0, 194, $statementY + 19.0, 0.15);
    putFitText($pdf, 172, $statementY + 12.2, upperOrEmpty($pilotCode), 20, 8.8);

    // ── Route ─────────────────────────────────────────────────────────────────
    $routeY = 155.5;
    drawFieldRow($pdf, 10,  $routeY, 'Dari', 'From', upperOrEmpty($data['from_where'] ?? ''), 14, 61, 8.9);
    drawFieldRow($pdf, 104, $routeY, 'Ke',   'To',   upperOrEmpty($data['to_where']   ?? ''), 10, 80, 8.9);

    // ── Events ────────────────────────────────────────────────────────────────
    $eventY = 169;
    drawEventRow($pdf, 10,  $eventY,        'Pandu Naik Kapal', 'Pilot On Board',  $data['pilot_on_board']  ?? null);
    drawEventRow($pdf, 10,  $eventY + 12.0, 'Kapal Bergerak',   'Ship Start',      $data['vessel_start']    ?? null);
    drawEventRow($pdf, 108, $eventY,        'Selesai Pandu',    'Pilot Finished',  $data['pilot_finished']  ?? null);
    drawEventRow($pdf, 108, $eventY + 12.0, 'Pandu Turun',      'Pilot Get Off',   $data['pilot_get_off']   ?? null);

    // ── QR / Approval block ───────────────────────────────────────────────────
    // Blok QR sekarang tingginya ~47mm (y+0 s/d y+47): judul+QR+label+nama
    // Pastikan $approvalTopY memberi cukup ruang sebelum catatan (y=268)
    $approvalTopY    = 212;

    $pilotDisplayName = upperOrEmpty($pilotProfile['name'] ?? ($data['pilot_name'] ?? ''));
    $masterOrAgency   = upperOrEmpty($data['master_name'] ?? '');
    if ($masterOrAgency === '') {
        $masterOrAgency = upperOrEmpty($data['agency'] ?? '');
    }

    $managerQrPayload = buildProfileQrPayload(
        $managerProfile,
        $managerName,
        textOrEmpty($managerProfile['role'] ?? ($requesterRole !== '' ? $requesterRole : 'admin')),
        '2A1', $pilotageId, 'MANAGER'
    );
    $pilotQrPayload = buildProfileQrPayload(
        $pilotProfile,
        $pilotDisplayName,
        textOrEmpty($pilotProfile['role'] ?? 'pilot'),
        '2A1', $pilotageId, 'PILOT'
    );
    $masterQrPayload = buildActivityQrPayload(
        $masterOrAgency,
        '2A1', $pilotageId, 'MASTER_AGENT',
        $signatureBase64
    );

    drawQrBlock($pdf, 12,  $approvalTopY, 'MANAGER PANDUAN', 'PILOT MANAGER',  $managerName,      $managerQrPayload);
    drawQrBlock($pdf, 78,  $approvalTopY, 'PANDU',           'MARINE PILOT',   $pilotDisplayName, $pilotQrPayload);
    drawQrBlock($pdf, 142, $approvalTopY, 'NAKHODA / AGEN',  'MASTER / AGENT', $masterOrAgency,   $masterQrPayload);

    // ── Footer note ───────────────────────────────────────────────────────────
    $noteY = 268;
    drawLine($pdf, 10, $noteY - 2, 200, $noteY - 2, 0.25);
    putText($pdf, 10, $noteY,      'CATATAN', 'helvetica', 'B', 7.4);
    putText($pdf, 10, $noteY + 3.8,'NOTE',    'helvetica', 'I', 6.8);
    putText($pdf, 24, $noteY,      'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______Menit)', 'helvetica', '', 6.9);
    putText($pdf, 24, $noteY + 3.8,'The working of tug boat is the effective used plus the time for moving and the base again.', 'helvetica', 'I', 6.5);
    putText($pdf, 10, $noteY + 11.2,'Catatlah dibalik bila ada berita / kejadian yang penting untuk diberitahukan', 'helvetica', '', 6.6);
    putText($pdf, 10, $noteY + 15.0,'Please note over leaf if any important / incident to be reported', 'helvetica', 'I', 6.4);

    // ── Output ────────────────────────────────────────────────────────────────
    $filename = buildDownloadFilename2A1($data);

    while (ob_get_level() > 0) {
        ob_end_clean();
    }

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
        'status'  => 'error',
        'message' => $e->getMessage(),
    ]);
}
