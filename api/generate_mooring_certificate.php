<?php
// generate_mooring_certificate.php
// Form Tunda (2A2) from activity_logs, styled to match generate_pilot_certificate.php

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
        if (preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $text) === 1) {
            return substr($text, 0, 5);
        }
        return '';
    }

    return date('H:i', $timestamp);
}

function combineDateTimeForDuration($dateValue, $timeValue): ?int
{
    $dateText = textOrEmpty($dateValue);
    $timeText = textOrEmpty($timeValue);

    if ($timeText === '' || $timeText === '0000-00-00 00:00:00') {
        return null;
    }

    $timestamp = strtotime($timeText);
    if ($timestamp !== false && $timestamp > 0) {
        return $timestamp;
    }

    if ($dateText === '' || $dateText === '0000-00-00') {
        return null;
    }

    $candidate = strtotime($dateText . ' ' . $timeText);
    return ($candidate !== false && $candidate > 0) ? $candidate : null;
}

function formatDurationValue($dateValue, $startValue, $endValue): string
{
    $startTs = combineDateTimeForDuration($dateValue, $startValue);
    $endTs = combineDateTimeForDuration($dateValue, $endValue);

    if ($startTs === null || $endTs === null || $endTs < $startTs) {
        return '';
    }

    $minutes = (int) round(($endTs - $startTs) / 60);
    $hours = intdiv($minutes, 60);
    $remain = $minutes % 60;

    return str_pad((string) $hours, 2, '0', STR_PAD_LEFT) . ':' . str_pad((string) $remain, 2, '0', STR_PAD_LEFT);
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
    $pdf->SetFont($font, $style, $size);
    $pdf->SetXY($x, $y);
    $pdf->Cell($width, $height, textOrEmpty($text), 0, 0, $align, false, '', 0, false, 'T', 'M');
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

function drawLine($pdf, float $x1, float $y1, float $x2, float $y2, float $width = 0.2): void
{
    $pdf->SetLineWidth($width);
    $pdf->Line($x1, $y1, $x2, $y2);
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

function drawTugUsageRow($pdf, float $x, float $y, string $name, string $power, string $serviceDate, string $startTime, string $endDate, string $endTime, string $duration): void
{
    drawFieldRow($pdf, $x, $y, 'Nama', 'Name', $name, 18, 56, 8.8);
    drawFieldRow($pdf, $x + 95, $y, 'Tenaga', 'Engine Power', $power, 20, 20, 8.3);
    drawFieldRow($pdf, $x + 143, $y, 'Durasi', 'Duration', $duration, 17, 18, 8.1);

    drawFieldRow($pdf, $x, $y + 11.5, 'Mulai Tunda', 'Tug Start', $serviceDate, 25, 18, 8.1);
    drawFieldRow($pdf, $x + 56, $y + 11.5, 'Pukul', 'Time', $startTime, 13, 18, 8.1);
    drawFieldRow($pdf, $x + 95, $y + 11.5, 'Selesai Tunda', 'Tug End', $endDate, 25, 18, 8.1);
    drawFieldRow($pdf, $x + 143, $y + 11.5, 'Pukul', 'Time', $endTime, 13, 18, 8.1);
}

function parseDelimitedValues($value): array
{
    $text = textOrEmpty($value);
    if ($text === '') {
        return [];
    }

    $parts = preg_split('/\s*(?:\/|,)\s*/', $text);
    if (!is_array($parts)) {
        return [];
    }

    return array_values(array_filter(array_map('trim', $parts), static function ($item) {
        return $item !== '';
    }));
}

function buildAssistTugRows(array $data): array
{
    $names = parseDelimitedValues(pickValue($data, ['assist_tug_name']));
    $powers = parseDelimitedValues(pickValue($data, ['engine_power']));

    if (empty($names)) {
        $names[] = '';
    }

    $rows = [];
    foreach ($names as $index => $name) {
        $power = $powers[$index] ?? ($powers[0] ?? '');
        $rows[] = [
            'name' => upperOrEmpty($name),
            'power' => appendUnit($power, 'PS'),
        ];
    }

    return array_slice($rows, 0, 2);
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
        error_log("Inline signature placement failed (mooring): " . $e->getMessage());
    }

    if (!$placed) {
        $tmpFile = tempnam(sys_get_temp_dir(), 'sig_moor_');
        if ($tmpFile !== false) {
            $tmpPng = $tmpFile . '.png';
            @unlink($tmpFile);
            $written = @file_put_contents($tmpPng, $signatureBinary);
            if ($written !== false) {
                try {
                    $pdf->Image($tmpPng, $x, $y, $w, $h, 'PNG', '', '', true, 150, '', false, false, 0);
                    $placed = true;
                } catch (Exception $e) {
                    error_log("Temp signature placement failed (mooring): " . $e->getMessage());
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

function drawApprovalBlock($pdf, float $x, float $y, string $titleId, string $titleEn, string $name, bool $withSignature = false, $signatureBinary = false): void
{
    $width = 54;

    putText($pdf, $x, $y, $titleId, 'helvetica', 'B', 9.2, 'C', $width, 4);
    putText($pdf, $x, $y + 4.6, $titleEn, 'helvetica', 'I', 6.7, 'C', $width, 4);

    if ($withSignature && $signatureBinary !== false) {
        placeSignature($pdf, $signatureBinary, $x + 10, $y + 8, 34, 16);
    }

    $nameLineY = $y + 37;
    drawLine($pdf, $x + 2, $nameLineY, $x + $width - 2, $nameLineY, 0.2);
    putText($pdf, $x, $nameLineY + 2.5, 'NAMA / NAME', 'helvetica', 'B', 7.5, 'C', $width, 4);
    putFitText($pdf, $x + 2, $nameLineY + 7.2, $name, $width - 4, 8.2, '', 'C');
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

    $stmt->bind_param('i', $pilotageId);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("Data pilotage tidak ditemukan");
    }

    $data = $result->fetch_assoc();

    if (empty($signatureBase64) && isset($data['signature']) && !empty($data['signature'])) {
        $signatureBase64 = $data['signature'];
    }

    $assistTugs = buildAssistTugRows($data);
    if (count($assistTugs) < 2) {
        $assistTugs[] = ['name' => '', 'power' => ''];
    }

    $serviceDate = formatDateValue($data['date'] ?? null);
    $startValue = pickValue($data, ['vessel_start', 'pilot_on_board']);
    $endValue = pickValue($data, ['pilot_get_off', 'pilot_finished']);
    $startTime = formatTimeValue($startValue);
    $endTime = formatTimeValue($endValue);
    $endDate = formatDateValue($endValue);
    if ($endDate === '') {
        $endDate = $serviceDate;
    }
    $duration = formatDurationValue($data['date'] ?? null, $startValue, $endValue);
    $certificateNumber = buildCertificateNumber($data);
    $requestNumber = buildServiceRequestNumber($data);
    $description = pickValue($data, ['notes', 'description', 'remarks'], '-');
    $managerName = upperOrEmpty(pickValue($data, ['manager_name', 'supervisor_name'], 'PT. SNEPAC INDO SERVICE'));
    $signatureBinary = !empty($signatureBase64) ? prepareSignatureImageData($signatureBase64) : false;

    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    $pdf->SetCreator('PT. SNEPAC INDO SERVICE');
    $pdf->SetAuthor('PT. SNEPAC INDO SERVICE');
    $pdf->SetTitle('Mooring Certificate - ' . textOrEmpty($data['vessel_name'] ?? ''));
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

    putText($pdf, 20, 36.5, 'BUKTI PEMAKAIAN JASA TUNDA', 'helvetica', 'B', 12, 'C', 170, 5);
    putText($pdf, 20, 42.2, 'TUG BOAT SERVICE', 'helvetica', 'I', 8.7, 'C', 170, 4);
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
    putFitText($pdf, 10, $statementY, 'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA TUNDA NO : ' . $requestNumber, 190, 9.1, 'B');
    putText($pdf, 10, $statementY + 4.6, 'DECLARES THAT IN ACCORDANCE WITH', 'helvetica', 'I', 7.1);

    $routeY = 142;
    drawFieldRow($pdf, 10, $routeY, 'Dari', 'From', upperOrEmpty($data['from_where'] ?? ''), 14, 61, 8.9);
    drawFieldRow($pdf, 104, $routeY, 'Ke', 'To', upperOrEmpty($data['to_where'] ?? ''), 10, 80, 8.9);

    $tugTitleY = 155.5;
    putText($pdf, 10, $tugTitleY, 'IA TELAH MENGGUNAKAN KAPAL TUNDA', 'helvetica', 'B', 9.2);
    putText($pdf, 10, $tugTitleY + 4.4, 'SHE DULY USED THE TUG BOAT', 'helvetica', 'I', 7.0);

    $firstTugY = 166.5;
    drawTugUsageRow(
        $pdf,
        10,
        $firstTugY,
        $assistTugs[0]['name'] ?? '',
        $assistTugs[0]['power'] ?? '',
        $serviceDate,
        $startTime,
        $endDate,
        $endTime,
        $duration
    );

    if (textOrEmpty($assistTugs[1]['name'] ?? '') !== '' || textOrEmpty($assistTugs[1]['power'] ?? '') !== '') {
        $dividerY = $firstTugY + 24.5;
        drawLine($pdf, 10, $dividerY, 200, $dividerY, 0.18);

        drawTugUsageRow(
            $pdf,
            10,
            $firstTugY + 29,
            $assistTugs[1]['name'] ?? '',
            $assistTugs[1]['power'] ?? '',
            $serviceDate,
            $startTime,
            $endDate,
            $endTime,
            $duration
        );
    }

    $approvalY = 224;
    drawApprovalBlock($pdf, 12, $approvalY, 'MANAGER PANDUAN', 'PILOT MANAGER', $managerName, false);

    $tugMasterName = upperOrEmpty($assistTugs[0]['name'] ?? '');
    if ($tugMasterName === '') {
        $tugMasterName = 'TUG BOAT';
    }
    drawApprovalBlock($pdf, 78, $approvalY, 'NAHKODA KAPAL TUNDA', 'TUG BOAT MASTER', $tugMasterName, false);

    $masterAgentName = upperOrEmpty($data['master_name'] ?? '');
    if ($masterAgentName === '') {
        $masterAgentName = upperOrEmpty($data['agency'] ?? '');
    }
    drawApprovalBlock($pdf, 142, $approvalY, 'MASTER / AGENT', 'NAKHODA / AGEN', $masterAgentName, true, $signatureBinary);

    $noteY = 268;
    drawLine($pdf, 10, $noteY - 2, 200, $noteY - 2, 0.25);
    putText($pdf, 10, $noteY, 'CATATAN', 'helvetica', 'B', 7.4);
    putText($pdf, 10, $noteY + 3.8, 'NOTE', 'helvetica', 'I', 6.8);
    putText($pdf, 24, $noteY, 'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______Menit)', 'helvetica', '', 6.9);
    putText($pdf, 24, $noteY + 3.8, 'The working of tug boat is the effective used plus the time for moving and the base again.', 'helvetica', 'I', 6.5);

    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', textOrEmpty($data['vessel_name'] ?? 'mooring_certificate'));
    $filename = "Mooring_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";

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
    error_log("Mooring PDF Generation Error: " . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
    ]);
}
?>
