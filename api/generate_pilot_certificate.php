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

    return 'BKT/IDBTM/SIS/' . $yearMonth . '/' . str_pad((string) max($id, 1), 5, '0', STR_PAD_LEFT);
}

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

function putText($pdf, float $x, float $y, string $text, string $font = 'helvetica', string $style = '', float $size = 9, string $align = 'L', float $width = 0, float $height = 4): void
{
    $text = textOrEmpty($text);
    $pdf->SetFont($font, $style, $size);
    $pdf->SetXY($x, $y);
    $pdf->Cell($width, $height, $text, 0, 0, $align, false, '', 0, false, 'T', 'M');
}

function drawLine($pdf, float $x1, float $y1, float $x2, float $y2, float $width = 0.2): void
{
    $pdf->SetLineWidth($width);
    $pdf->Line($x1, $y1, $x2, $y2);
}

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

function drawFieldRow($pdf, float $x, float $y, string $labelId, string $labelEn, string $value, float $labelWidth = 31, float $lineWidth = 63, float $valueSize = 9): void
{
    putText($pdf, $x, $y, $labelId, 'helvetica', '', 7.9);
    putText($pdf, $x, $y + 4.1, $labelEn, 'helvetica', 'I', 6.7);
    putText($pdf, $x + $labelWidth, $y + 0.8, ':', 'helvetica', '', 9);

    $valueX = $x + $labelWidth + 3.5;
    drawLine($pdf, $valueX, $y + 8.0, $valueX + $lineWidth, $y + 8.0, 0.15);
    putFitText($pdf, $valueX, $y + 1.0, $value, $lineWidth - 1, $valueSize);
}

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

    $width = imagesx($img);
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

    $croppedWidth = imagesx($cropped);
    $croppedHeight = imagesy($cropped);
    $transparent = imagecolorallocatealpha($cropped, 255, 255, 255, 127);

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
            $tmpPng = $tmpFile . '.png';
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

try {
    $pilotageId = null;
    $signatureBase64 = null;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }

        $pilotageId = isset($input['id']) ? (int) $input['id'] : null;
        $signatureBase64 = isset($input['signature']) ? $input['signature'] : null;
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

    $sql = "SELECT * FROM activity_logs WHERE id = ?";
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

    $logoPath = __DIR__ . '/../backend/assets/NO-BG-LOGO-SIS.png';
    if (file_exists($logoPath)) {
        $pdf->Image($logoPath, 11, 11, 28, 18, 'PNG', '', '', true, 300, '', false, false, 0);
        $pdf->Image($logoPath, 171, 11, 24, 15, 'PNG', '', '', true, 300, '', false, false, 0);
    }

    putText($pdf, 45, 13, 'PEMANDUAN DAN PENUNDAAN', 'helvetica', 'B', 13, 'C', 120, 5);
    putText($pdf, 45, 20, 'DAERAH PERAIRAN WAJIB PANDU BATAM', 'helvetica', 'B', 11.5, 'C', 120, 5);
    putText($pdf, 45, 26, 'PT. SNEPAC INDO SERVICE', 'helvetica', '', 8.7, 'C', 120, 4);
    drawLine($pdf, 10, 33, 200, 33, 0.35);

    $certificateNumber = buildCertificateNumber($data);
    $requestNumber = buildServiceRequestNumber($data);
    $pilotCode = pickValue($data, ['pilot_code', 'pilot_license_no', 'pilot_nip', 'pilot_identifier'], '-');
    $description = pickValue($data, ['description', 'keterangan', 'remarks'], '-');
    $managerName = upperOrEmpty(pickValue($data, ['manager_name', 'supervisor_name'], 'PT. SNEPAC INDO SERVICE'));

    putText($pdf, 20, 36.5, 'BUKTI PEMAKAIAN JASA PANDU', 'helvetica', 'B', 12, 'C', 170, 5);
    putText($pdf, 20, 42.2, 'PILOTAGE SERVICE', 'helvetica', 'I', 8.7, 'C', 170, 4);
    putText($pdf, 20, 47.0, 'Nomor : ' . $certificateNumber, 'helvetica', '', 8.8, 'C', 170, 4);

    $leftX = 10;
    $rightX = 104;
    $rowStartY = 54;
    $rowGap = 12.5;

    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 0), 'Nama Kapal', 'Vessel Name', upperOrEmpty($data['vessel_name'] ?? ''), 28, 60, 9.4);
    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 1), 'Nama Nakhoda', 'Ship Master', upperOrEmpty($data['master_name'] ?? ''), 28, 60, 9.2);
    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 2), 'Bendera', 'Flag', upperOrEmpty($data['flag'] ?? ''), 28, 60, 9.0);
    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 3), 'Datang Dari', 'Last Port of Call', upperOrEmpty($data['last_port'] ?? ''), 28, 60, 8.7);
    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 4), 'Isi Kotor', 'G.R.T.', appendUnit($data['gross_tonnage'] ?? '', 'Ton'), 28, 60, 8.9);
    drawFieldRow($pdf, $leftX, $rowStartY + ($rowGap * 5), 'Panjang', 'L.O.A', appendUnit($data['loa'] ?? '', 'm'), 28, 60, 8.9);

    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 0), 'Panggilan', 'Call Sign', upperOrEmpty($data['call_sign'] ?? ''), 28, 60, 9.2);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 1), 'Keagenan Kapal', 'Agency', upperOrEmpty($data['agency'] ?? ''), 28, 60, 8.4);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 2), 'Keterangan', 'Description', upperOrEmpty($description), 28, 60, 8.4);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 3), 'Tujuan Ke', 'Next Port Of Call', upperOrEmpty($data['next_port'] ?? ''), 28, 60, 8.7);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 4), 'Sarat Muka', 'Fore Draft', appendUnit($data['fore_draft'] ?? '', 'm'), 28, 60, 8.9);
    drawFieldRow($pdf, $rightX, $rowStartY + ($rowGap * 5), 'Sarat Belakang', 'Rear Draft', appendUnit($data['aft_draft'] ?? '', 'm'), 28, 60, 8.9);

    $statementY = 132;
    putFitText($pdf, 10, $statementY, 'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA PANDU NO : ' . $requestNumber, 190, 9.1, 'B');
    putText($pdf, 10, $statementY + 4.6, 'DECLARES THAT IN ACCORDANCE WITH', 'helvetica', 'I', 7.1);

    putText($pdf, 10, $statementY + 11, 'IA TELAH DIPANDU OLEH PANDU', 'helvetica', 'B', 9.2);
    putText($pdf, 10, $statementY + 15.4, 'SHE HAS BEEN PILOTED BY THE MARINE PILOT', 'helvetica', 'I', 7.0);

    putText($pdf, 70, $statementY + 12.0, ':', 'helvetica', '', 9.5);
    drawLine($pdf, 73, $statementY + 19.0, 150, $statementY + 19.0, 0.15);
    putFitText($pdf, 74, $statementY + 12.2, upperOrEmpty($data['pilot_name'] ?? ''), 74, 9.4);

    putText($pdf, 155, $statementY + 11.0, 'Kode', 'helvetica', '', 8.8);
    putText($pdf, 155, $statementY + 15.4, 'Code', 'helvetica', 'I', 6.7);
    putText($pdf, 168.5, $statementY + 12.0, ':', 'helvetica', '', 9.5);
    drawLine($pdf, 171, $statementY + 19.0, 194, $statementY + 19.0, 0.15);
    putFitText($pdf, 172, $statementY + 12.2, upperOrEmpty($pilotCode), 20, 8.8);

    $routeY = 155.5;
    drawFieldRow($pdf, 10, $routeY, 'Dari', 'From', upperOrEmpty($data['from_where'] ?? ''), 14, 61, 8.9);
    drawFieldRow($pdf, 104, $routeY, 'Ke', 'To', upperOrEmpty($data['to_where'] ?? ''), 10, 80, 8.9);

    $eventY = 169;
    drawEventRow($pdf, 10, $eventY, 'Pandu Naik Kapal', 'Pilot On Board', $data['pilot_on_board'] ?? null);
    drawEventRow($pdf, 10, $eventY + 12.0, 'Kapal Bergerak', 'Ship Start', $data['vessel_start'] ?? null);
    drawEventRow($pdf, 108, $eventY, 'Selesai Pandu', 'Pilot Finished', $data['pilot_finished'] ?? null);
    drawEventRow($pdf, 108, $eventY + 12.0, 'Pandu Turun', 'Pilot Get Off', $data['pilot_get_off'] ?? null);

    $approvalTopY = 214;
    $blockWidth = 54;
    $signatureBinary = !empty($signatureBase64) ? prepareSignatureImageData($signatureBase64) : false;

    putText($pdf, 12, $approvalTopY, 'MANAGER PANDUAN', 'helvetica', 'B', 9.2, 'C', $blockWidth, 4);
    putText($pdf, 12, $approvalTopY + 4.6, 'PILOT MANAGER', 'helvetica', 'I', 6.7, 'C', $blockWidth, 4);

    putText($pdf, 78, $approvalTopY, 'PANDU', 'helvetica', 'B', 9.2, 'C', $blockWidth, 4);
    putText($pdf, 78, $approvalTopY + 4.6, 'MARINE PILOT', 'helvetica', 'I', 6.7, 'C', $blockWidth, 4);

    putText($pdf, 142, $approvalTopY, 'NAKHODA / AGEN', 'helvetica', 'B', 9.2, 'C', $blockWidth, 4);
    putText($pdf, 142, $approvalTopY + 4.6, 'MASTER / AGENT', 'helvetica', 'I', 6.7, 'C', $blockWidth, 4);

    if ($signatureBinary !== false) {
        if (!placeSignature($pdf, $signatureBinary, 144, $approvalTopY + 8, 48, 20)) {
            error_log("Signature failed to render in PDF (pilot)");
        } else {
            error_log("Signature added to PDF successfully (pilot)");
        }
    } else {
        error_log("No signature provided");
    }

    $nameLineY = $approvalTopY + 37;
    drawLine($pdf, 16, $nameLineY, 64, $nameLineY, 0.2);
    drawLine($pdf, 74, $nameLineY, 136, $nameLineY, 0.2);
    drawLine($pdf, 140, $nameLineY, 196, $nameLineY, 0.2);

    putText($pdf, 12, $nameLineY + 2.5, 'NAMA / NAME', 'helvetica', 'B', 7.5, 'C', $blockWidth, 4);
    putText($pdf, 78, $nameLineY + 2.5, 'NAMA / NAME', 'helvetica', 'B', 7.5, 'C', $blockWidth, 4);
    putText($pdf, 142, $nameLineY + 2.5, 'NAMA / NAME', 'helvetica', 'B', 7.5, 'C', $blockWidth, 4);

    putFitText($pdf, 14, $nameLineY + 7.2, $managerName, 48, 8.8, '', 'C');
    putFitText($pdf, 76, $nameLineY + 7.2, upperOrEmpty($data['pilot_name'] ?? ''), 58, 8.8, '', 'C');

    $masterOrAgency = upperOrEmpty($data['master_name'] ?? '');
    if ($masterOrAgency === '') {
        $masterOrAgency = upperOrEmpty($data['agency'] ?? '');
    }
    putFitText($pdf, 142, $nameLineY + 7.2, $masterOrAgency, 52, 8.2, '', 'C');

    $noteY = 268;
    drawLine($pdf, 10, $noteY - 2, 200, $noteY - 2, 0.25);
    putText($pdf, 10, $noteY, 'CATATAN', 'helvetica', 'B', 7.4);
    putText($pdf, 10, $noteY + 3.8, 'NOTE', 'helvetica', 'I', 6.8);
    putText($pdf, 24, $noteY, 'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______Menit)', 'helvetica', '', 6.9);
    putText($pdf, 24, $noteY + 3.8, 'The working of tug boat is the effective used plus the time for moving and the base again.', 'helvetica', 'I', 6.5);
    putText($pdf, 10, $noteY + 11.2, 'Catatlah dibalik bila ada berita / kejadian yang penting untuk diberitahukan', 'helvetica', '', 6.6);
    putText($pdf, 10, $noteY + 15.0, 'Please note over leaf if any important / incident to be reported', 'helvetica', 'I', 6.4);

    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', textOrEmpty($data['vessel_name'] ?? 'pilot_certificate'));
    $filename = "Pilot_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";

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
        'status' => 'error',
        'message' => $e->getMessage(),
    ]);
}