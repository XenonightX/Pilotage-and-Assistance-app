<?php
// generate_assistance_certificate.php
// Custom assistance/tug boat certificate PDF

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

function formatDateOnly($value): string
{
    $text = textOrEmpty($value);
    if ($text === '' || $text === '0000-00-00' || $text === '0000-00-00 00:00:00') {
        return '';
    }

    $timestamp = strtotime($text);
    if ($timestamp === false || $timestamp <= 0) {
        return '';
    }

    return date('d-m-Y', $timestamp);
}

function formatTimeOnly($value): string
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

    while ($fontSize > 6.1 && $pdf->GetStringWidth($text) > $maxWidth) {
        $fontSize -= 0.2;
        $pdf->SetFont('helvetica', $style, $fontSize);
    }

    $pdf->SetXY($x, $y);
    $pdf->Cell($maxWidth, 4, $text, 0, 0, $align, false, '', 0, false, 'T', 'M');
}

function drawLine($pdf, float $x1, float $y1, float $x2, float $y2, float $width = 0.18): void
{
    $pdf->SetLineWidth($width);
    $pdf->Line($x1, $y1, $x2, $y2);
}

function drawFieldRow($pdf, float $x, float $y, string $labelId, string $labelEn, string $value, float $labelWidth = 28, float $lineWidth = 64, float $valueSize = 8.9): void
{
    putText($pdf, $x, $y, $labelId, 'helvetica', '', 8.6);
    putText($pdf, $x, $y + 4.0, $labelEn, 'helvetica', 'I', 6.5);
    putText($pdf, $x + $labelWidth, $y + 0.5, ':', 'helvetica', '', 9);

    $valueX = $x + $labelWidth + 3;
    drawLine($pdf, $valueX, $y + 7.6, $valueX + $lineWidth, $y + 7.6, 0.15);
    putFitText($pdf, $valueX + 0.8, $y + 0.8, $value, $lineWidth - 1.6, $valueSize);
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

    $parts = array_values(array_filter(array_map('trim', $parts), static function ($item) {
        return $item !== '';
    }));

    return $parts;
}

function buildAssistTugRows(array $data): array
{
    $names = [];
    $powers = [];

    for ($i = 1; $i <= 2; $i++) {
        $name = pickValue($data, ['assist_tug_name_' . $i]);
        $power = pickValue($data, ['engine_power_' . $i]);

        if ($name !== '' || $power !== '') {
            $names[] = $name;
            $powers[] = $power;
        }
    }

    if (empty($names)) {
        $names = parseDelimitedValues(pickValue($data, ['assist_tug_name']));
        $powers = parseDelimitedValues(pickValue($data, ['engine_power']));
    }

    if (empty($names)) {
        $names[] = '';
    }

    $rows = [];
    foreach ($names as $index => $name) {
        $power = $powers[$index] ?? ($powers[0] ?? '');
        $power = appendUnit($power, 'PS');

        $rows[] = [
            'name' => upperOrEmpty($name),
            'power' => $power,
        ];
    }

    return array_slice($rows, 0, 2);
}

function drawTugRow($pdf, float $y, array $tug, string $serviceDate, string $startTime, string $endDate, string $endTime, string $duration): void
{
    drawFieldRow($pdf, 10, $y, 'Nama', 'Name', $tug['name'] ?? '', 28, 64, 8.9);
    drawFieldRow($pdf, 104, $y, 'Tenaga', 'Engine Power', textOrEmpty($tug['power'] ?? ''), 28, 22, 8.5);
    drawFieldRow($pdf, 156, $y, 'Durasi', 'Duration', $duration, 16, 24, 8.4);

    drawFieldRow($pdf, 10, $y + 12, 'Mulai Tunda', 'Tug Start', $serviceDate, 28, 22, 8.4);
    drawFieldRow($pdf, 66, $y + 12, 'Pukul', 'Time', $startTime, 12, 28, 8.4);
    drawFieldRow($pdf, 104, $y + 12, 'Selesai Tunda', 'Tug End', $endDate, 28, 22, 8.4);
    drawFieldRow($pdf, 156, $y + 12, 'Pukul', 'Time', $endTime, 12, 24, 8.4);
}

function drawQrBlock($pdf, float $x, float $y, string $titleId, string $titleEn, string $name, string $qrContent): void
{
    $width = 52;
    putText($pdf, $x, $y, $titleId, 'helvetica', 'B', 8.9, 'C', $width, 4);
    putText($pdf, $x, $y + 4.5, $titleEn, 'helvetica', 'I', 6.5, 'C', $width, 4);

    $style = [
        'border' => 0,
        'padding' => 0,
        'fgcolor' => [0, 0, 0],
        'bgcolor' => false,
    ];

    $qrX = $x + 15;
    $qrY = $y + 10;
    $pdf->write2DBarcode($qrContent, 'QRCODE,H', $qrX, $qrY, 22, 22, $style, 'N');

    $lineY = $y + 40;
    drawLine($pdf, $x + 1, $lineY, $x + $width - 1, $lineY, 0.2);
    putText($pdf, $x, $lineY - 7.5, 'NAMA / NAME', 'helvetica', 'B', 7.1, 'C', $width, 4);
    putFitText($pdf, $x + 2, $lineY + 1.5, $name, $width - 4, 8.3, '', 'C');
}

try {
    $assistanceId = null;

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $assistanceId = isset($input['id']) ? (int) $input['id'] : null;
    } else {
        $assistanceId = isset($_GET['id']) ? (int) $_GET['id'] : null;
    }

    if (!$assistanceId) {
        throw new Exception("ID assistance tidak ditemukan");
    }

    $sql = "SELECT * FROM assistance_logs WHERE id = ?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare query gagal: " . $conn->error);
    }

    $stmt->bind_param('i', $assistanceId);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("Data assistance tidak ditemukan");
    }

    $data = $result->fetch_assoc();

    $certificateNumber = buildCertificateNumber($data);
    $requestNumber = buildServiceRequestNumber($data);
    $serviceDate = formatDateOnly($data['date'] ?? null);
    $startTime = formatTimeOnly($data['assistance_start'] ?? null);
    $endDate = formatDateOnly($data['assistance_end'] ?? ($data['date'] ?? null));
    if ($endDate === '') {
        $endDate = $serviceDate;
    }
    $endTime = formatTimeOnly($data['assistance_end'] ?? null);
    $duration = formatDurationValue($data['date'] ?? null, $data['assistance_start'] ?? null, $data['assistance_end'] ?? null);
    $description = pickValue($data, ['notes', 'description', 'keterangan'], '-');
    $managerName = upperOrEmpty(pickValue($data, ['manager_name', 'supervisor_name'], 'MOHAMAD ADAM'));

    $assistTugs = buildAssistTugRows($data);
    if (count($assistTugs) < 2) {
        $assistTugs[] = ['name' => '', 'power' => ''];
    }

    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    $pdf->SetCreator('PT. SNEPAC INDO SERVICE');
    $pdf->SetAuthor('PT. SNEPAC INDO SERVICE');
    $pdf->SetTitle('Assistance Certificate - ' . textOrEmpty($data['vessel_name'] ?? ''));
    $pdf->SetMargins(0, 0, 0);
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetAutoPageBreak(false);
    $pdf->AddPage();

    $pdf->SetDrawColor(35, 35, 35);
    $pdf->SetTextColor(18, 18, 18);
    $pdf->Rect(5, 5, 200, 287);

    $logoPath = __DIR__ . '/../backend/assets/NO-BG-LOGO-SIS.png';
    if (file_exists($logoPath)) {
        $pdf->Image($logoPath, 11, 12, 30, 18, 'PNG', '', '', true, 300, '', false, false, 0);
    }

    $pdf->SetTextColor(24, 112, 196);
    putText($pdf, 163, 14, 'PELINDO', 'helvetica', 'B', 13);
    $pdf->SetTextColor(245, 90, 60);
    putText($pdf, 166.5, 20.5, 'SOLUSI DIGITAL', 'helvetica', 'B', 5.8);
    $pdf->SetTextColor(18, 18, 18);

    putText($pdf, 42, 14, 'BUKTI PEMAKAIAN JASA TUNDA', 'helvetica', 'B', 12, 'C', 125, 5);
    putText($pdf, 42, 20.2, 'TUG BOAT CERTIFICATE', 'helvetica', '', 10, 'C', 125, 4);
    putText($pdf, 42, 25.8, 'Nomor : ' . $certificateNumber, 'helvetica', '', 8.7, 'C', 125, 4);
    drawLine($pdf, 10, 38, 200, 38, 0.35);

    $leftX = 10;
    $rightX = 104;
    $rowY = 46;
    $gap = 10.3;

    drawFieldRow($pdf, $leftX, $rowY + ($gap * 0), 'Nama Kapal', 'Vessel Name', upperOrEmpty($data['vessel_name'] ?? ''), 28, 64, 8.9);
    drawFieldRow($pdf, $leftX, $rowY + ($gap * 1), 'Nama Nakhoda', 'Ship Master', upperOrEmpty($data['master_name'] ?? ''), 28, 64, 8.9);
    drawFieldRow($pdf, $leftX, $rowY + ($gap * 2), 'Bendera', 'Flag', upperOrEmpty($data['flag'] ?? ''), 28, 64, 8.9);
    drawFieldRow($pdf, $leftX, $rowY + ($gap * 3), 'Datang Dari', 'Last Port Of Call', upperOrEmpty($data['last_port'] ?? ''), 28, 64, 8.5);
    drawFieldRow($pdf, $leftX, $rowY + ($gap * 4), 'Isi Kotor', 'G.R.T', appendUnit($data['gross_tonnage'] ?? '', 'Ton'), 28, 64, 8.6);
    drawFieldRow($pdf, $leftX, $rowY + ($gap * 5), 'Panjang', 'L.O.A', appendUnit($data['loa'] ?? '', 'm'), 28, 64, 8.6);

    drawFieldRow($pdf, $rightX, $rowY + ($gap * 0), 'Panggilan', 'Call Sign', upperOrEmpty($data['call_sign'] ?? ''), 28, 64, 8.9);
    drawFieldRow($pdf, $rightX, $rowY + ($gap * 1), 'Keagenan Kapal', 'Agency', upperOrEmpty($data['agency'] ?? ''), 28, 64, 8.2);
    drawFieldRow($pdf, $rightX, $rowY + ($gap * 2), 'Keterangan', 'Description', upperOrEmpty($description), 28, 64, 8.2);
    drawFieldRow($pdf, $rightX, $rowY + ($gap * 3), 'Tujuan Ke', 'Next Port Of Call', upperOrEmpty($data['next_port'] ?? ''), 28, 64, 8.5);
    drawFieldRow($pdf, $rightX, $rowY + ($gap * 4), 'Sarat Muka', 'Fore Draft', appendUnit($data['fore_draft'] ?? '', 'm'), 28, 64, 8.6);
    drawFieldRow($pdf, $rightX, $rowY + ($gap * 5), 'Sarat Belakang', 'Rear Draft', appendUnit($data['aft_draft'] ?? '', 'm'), 28, 64, 8.6);

    $statementY = 108;
    putFitText($pdf, 10, $statementY, 'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA TUNDA NO : ' . $requestNumber, 190, 9.1, 'B');
    drawFieldRow($pdf, 10, $statementY + 7.2, 'Dari', 'From', upperOrEmpty($data['from_where'] ?? ''), 14, 63, 8.7);
    drawFieldRow($pdf, 104, $statementY + 7.2, 'Ke', 'To', upperOrEmpty($data['to_where'] ?? ''), 10, 64, 8.7);

    $tugSectionY = 130;
    putText($pdf, 10, $tugSectionY, 'IA TELAH MENGGUNAKAN KAPAL TUNDA', 'helvetica', 'B', 9.4);
    putText($pdf, 10, $tugSectionY + 4.4, 'SHE DULY USED THE TUG BOAT', 'helvetica', 'I', 6.8);

    $firstRowY = 140;
    drawTugRow($pdf, $firstRowY, $assistTugs[0], $serviceDate, $startTime, $endDate, $endTime, $duration);

    $dividerY = $firstRowY + 23;
    drawLine($pdf, 10, $dividerY, 200, $dividerY, 0.18);

    if (textOrEmpty($assistTugs[1]['name'] ?? '') !== '' || textOrEmpty($assistTugs[1]['power'] ?? '') !== '') {
        drawTugRow($pdf, $firstRowY + 28, $assistTugs[1], $serviceDate, $startTime, $endDate, $endTime, $duration);
    }

    $qrTopY = 224;
    drawQrBlock(
        $pdf,
        12,
        $qrTopY,
        'MANAGER PEMANDUAN',
        'PILOT MANAGER',
        $managerName,
        'ASSISTANCE|MANAGER|' . $assistanceId . '|' . $certificateNumber
    );

    $tugMasterName = upperOrEmpty($assistTugs[0]['name'] ?? '');
    if ($tugMasterName === '') {
        $tugMasterName = 'TUG BOAT MASTER';
    }
    drawQrBlock(
        $pdf,
        76,
        $qrTopY,
        'NAHKODA KAPAL TUNDA',
        'TUG BOAT MASTER',
        $tugMasterName,
        'ASSISTANCE|TUG_MASTER|' . $assistanceId . '|' . $tugMasterName
    );

    $masterAgentName = upperOrEmpty($data['master_name'] ?? '');
    if ($masterAgentName === '') {
        $masterAgentName = upperOrEmpty($data['agency'] ?? '');
    }
    drawQrBlock(
        $pdf,
        140,
        $qrTopY,
        'MASTER/ AGENT',
        'NAHKODA / AGEN',
        $masterAgentName,
        'ASSISTANCE|MASTER_AGENT|' . $assistanceId . '|' . $masterAgentName
    );

    $noteY = 274;
    drawLine($pdf, 10, $noteY - 2.5, 200, $noteY - 2.5, 0.22);
    putText($pdf, 10, $noteY, 'CATATAN', 'helvetica', 'B', 7.2);
    putText($pdf, 10, $noteY + 3.4, 'NOTE :', 'helvetica', 'B', 7.0);
    putText($pdf, 27, $noteY, 'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (________ Menit)', 'helvetica', '', 6.6);
    putText($pdf, 27, $noteY + 4.0, 'The Work time of Tug Boat is the effective used plus the time moving and the base again.', 'helvetica', 'I', 6.2);

    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', textOrEmpty($data['vessel_name'] ?? 'assistance_certificate'));
    $filename = "Assistance_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";

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
    error_log("Assistance PDF Generation Error: " . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
    ]);
}
?>
