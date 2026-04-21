<?php
// generate_assistance_certificate.php
// Custom assistance / tug boat certificate PDF

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

// ── Shared helper functions — guarded so they don't conflict with 2A1 ─────────

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
        return 'BKT/IDBTM/SIS/' . $yearMonth . '/' . str_pad((string) max($id, 1), 5, '0', STR_PAD_LEFT);
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
        $result  = $conn->query("SHOW COLUMNS FROM users LIKE 'signature_data'");
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
        $hash      = substr(hash('sha256', $source), 0, 20);
        $baseUrl   = buildSignatureVerificationBaseUrl();
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
        $pdf->SetFont($font, $style, $size);
        $pdf->SetXY($x, $y);
        $pdf->Cell($width, $height, textOrEmpty($text), 0, 0, $align, false, '', 0, false, 'T', 'M');
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
        while ($fontSize > 6.1 && $pdf->GetStringWidth($text) > $maxWidth) {
            $fontSize -= 0.2;
            $pdf->SetFont('helvetica', $style, $fontSize);
        }
        $pdf->SetXY($x, $y);
        $pdf->Cell($maxWidth, 4, $text, 0, 0, $align, false, '', 0, false, 'T', 'M');
    }
}

if (!function_exists('drawLine')) {
    function drawLine($pdf, float $x1, float $y1, float $x2, float $y2, float $width = 0.18): void
    {
        $pdf->SetLineWidth($width);
        $pdf->Line($x1, $y1, $x2, $y2);
    }
}

// ── 2A2-specific helpers (unique names — no conflict risk) ────────────────────

function hasAssistanceSignatureColumn_2A2($conn): bool
{
    static $checked = null;
    if ($checked !== null) {
        return $checked;
    }
    $result  = $conn->query("SHOW COLUMNS FROM assistance_logs LIKE 'signature'");
    $checked = $result && $result->num_rows > 0;
    return $checked;
}

function tableExists_2A2($conn, string $table): bool
{
    static $checked = [];
    if (array_key_exists($table, $checked)) {
        return $checked[$table];
    }
    $tableName = str_replace(['_', '%'], ['\\_', '\\%'], $conn->real_escape_string($table));
    $result = $conn->query("SHOW TABLES LIKE '{$tableName}'");
    $checked[$table] = $result && $result->num_rows > 0;
    return $checked[$table];
}

function hasActivitySignatureColumn_2A2($conn): bool
{
    static $checked = null;
    if ($checked !== null) {
        return $checked;
    }
    $result  = $conn->query("SHOW COLUMNS FROM activity_logs LIKE 'signature'");
    $checked = $result && $result->num_rows > 0;
    return $checked;
}

function resolveManagerSignatureProfile_2A2($conn, int $requesterUserId, string $requesterRole): ?array
{
    if (!hasUserSignatureColumn($conn)) {
        return null;
    }
    $normalizedRole = strtolower(trim($requesterRole));
    if ($requesterUserId > 0 && in_array($normalizedRole, ['admin', 'superadmin'], true)) {
        $sql  = "SELECT id, name, role, signature_data
                 FROM users
                 WHERE id = ?
                 AND LOWER(TRIM(COALESCE(role, ''))) IN ('admin', 'superadmin')
                 LIMIT 1";
        $stmt = $conn->prepare($sql);
        if ($stmt) {
            $stmt->bind_param("i", $requesterUserId);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                if (textOrEmpty($row['signature_data'] ?? '') !== '') {
                    return $row;
                }
            }
        }
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

function resolveTugSignatureProfile_2A2($conn, string $tugName): ?array
{
    if (!hasUserSignatureColumn($conn)) {
        return null;
    }

    $sqlFallback = "SELECT id, name, role, signature_data
                    FROM users
                    WHERE LOWER(TRIM(COALESCE(role, ''))) = 'tugboat'
                    AND TRIM(COALESCE(signature_data, '')) <> ''
                    ORDER BY id ASC
                    LIMIT 1";

    if (textOrEmpty($tugName) === '') {
        $fallbackResult = $conn->query($sqlFallback);
        if ($fallbackResult && $fallbackResult->num_rows > 0) {
            return $fallbackResult->fetch_assoc();
        }
        return null;
    }

    $sql  = "SELECT id, name, role, signature_data
             FROM users
             WHERE LOWER(TRIM(COALESCE(name, ''))) = LOWER(TRIM(?))
             AND LOWER(TRIM(COALESCE(role, ''))) = 'tugboat'
             LIMIT 1";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param("s", $tugName);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result && $result->num_rows > 0) {
        return $result->fetch_assoc();
    }

    $fallbackResult = $conn->query($sqlFallback);
    if ($fallbackResult && $fallbackResult->num_rows > 0) {
        return $fallbackResult->fetch_assoc();
    }
    return null;
}

function fetchCertificateDataSource_2A2($conn, int $id): array
{
    foreach (['assistance_logs', 'activity_logs'] as $table) {
        if (!tableExists_2A2($conn, $table)) {
            continue;
        }

        $stmt = $conn->prepare("SELECT * FROM `{$table}` WHERE id = ?");
        if (!$stmt) {
            continue;
        }

        $stmt->bind_param('i', $id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result && $result->num_rows > 0) {
            $row = $result->fetch_assoc();
            $stmt->close();
            return [
                'table' => $table,
                'data'  => $row,
            ];
        }

        $stmt->close();
    }

    throw new Exception("Data 2A2 tidak ditemukan");
}

function formatDateOnly_2A2($value): string
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

function formatTimeOnly_2A2($value): string
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

function combineDateTimeForDuration_2A2($dateValue, $timeValue): ?int
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

function formatDurationValue_2A2($dateValue, $startValue, $endValue): string
{
    $startTs = combineDateTimeForDuration_2A2($dateValue, $startValue);
    $endTs   = combineDateTimeForDuration_2A2($dateValue, $endValue);
    if ($startTs === null || $endTs === null || $endTs < $startTs) {
        return '';
    }
    $minutes = (int) round(($endTs - $startTs) / 60);
    $hours   = intdiv($minutes, 60);
    $remain  = $minutes % 60;
    return str_pad((string) $hours, 2, '0', STR_PAD_LEFT) . ':' . str_pad((string) $remain, 2, '0', STR_PAD_LEFT);
}

function parseDelimitedValues_2A2($value): array
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

function buildAssistTugRows_2A2(array $data): array
{
    $names  = [];
    $powers = [];

    for ($i = 1; $i <= 3; $i++) {
        $name  = pickValue($data, ['assist_tug_name_' . $i]);
        $power = pickValue($data, ['engine_power_' . $i]);
        if ($name !== '' || $power !== '') {
            $names[]  = $name;
            $powers[] = $power;
        }
    }

    if (empty($names)) {
        $names  = parseDelimitedValues_2A2(pickValue($data, ['assist_tug_name']));
        $powers = parseDelimitedValues_2A2(pickValue($data, ['engine_power']));
    }

    if (empty($names)) {
        $names[] = '';
    }

    $rows = [];
    foreach ($names as $index => $name) {
        $power  = $powers[$index] ?? ($powers[0] ?? '');
        $power  = appendUnit($power, 'PS');
        $rows[] = [
            'name'  => upperOrEmpty($name),
            'power' => $power,
        ];
    }
    return array_slice($rows, 0, 3);
}

// drawFieldRow for 2A2 — slightly different defaults than 2A1, use unique name
function drawFieldRow_2A2($pdf, float $x, float $y, string $labelId, string $labelEn, string $value, float $labelWidth = 28, float $lineWidth = 64, float $valueSize = 8.9): void
{
    putText($pdf, $x, $y, $labelId, 'helvetica', '', 8.6);
    putText($pdf, $x, $y + 4.0, $labelEn, 'helvetica', 'I', 6.5);
    putText($pdf, $x + $labelWidth, $y + 0.5, ':', 'helvetica', '', 9);
    $valueX = $x + $labelWidth + 3;
    drawLine($pdf, $valueX, $y + 7.6, $valueX + $lineWidth, $y + 7.6, 0.15);
    putFitText($pdf, $valueX + 0.8, $y + 0.8, $value, $lineWidth - 1.6, $valueSize);
}

function drawTugRow_2A2($pdf, float $y, array $tug, string $serviceDate, string $startTime, string $endDate, string $endTime, string $duration): void
{
    drawFieldRow_2A2($pdf, 10,  $y,      'Nama',         'Name',         $tug['name']  ?? '', 28, 64, 8.9);
    drawFieldRow_2A2($pdf, 104, $y,      'Tenaga',       'Engine Power', textOrEmpty($tug['power'] ?? ''), 28, 22, 8.5);
    drawFieldRow_2A2($pdf, 156, $y,      'Durasi',       'Duration',     $duration,    16, 24, 8.4);

    drawFieldRow_2A2($pdf, 10,  $y + 12, 'Mulai Tunda',  'Tug Start',    $serviceDate, 28, 22, 8.4);
    drawFieldRow_2A2($pdf, 66,  $y + 12, 'Pukul',        'Time',         $startTime,   12, 28, 8.4);
    drawFieldRow_2A2($pdf, 104, $y + 12, 'Selesai Tunda','Tug End',      $endDate,     28, 22, 8.4);
    drawFieldRow_2A2($pdf, 156, $y + 12, 'Pukul',        'Time',         $endTime,     12, 24, 8.4);
}

// FIX: drawQrBlock untuk 2A2 — NAMA/NAME tidak tertimpa QR
// QR: $y+10 s/d $y+32. Label "NAMA/NAME" di $y+34, garis di $y+40, nama di $y+41.
function drawQrBlock_2A2($pdf, float $x, float $y, string $titleId, string $titleEn, string $name, string $qrContent): void
{
    $width = 52;

    // Judul bilingual
    putText($pdf, $x, $y,      $titleId, 'helvetica', 'B', 8.9, 'C', $width, 4);
    putText($pdf, $x, $y + 4.5, $titleEn, 'helvetica', 'I', 6.5, 'C', $width, 4);

    // QR code: mulai y+10, tinggi 22 → berakhir y+32
    $style = [
        'border'  => 0,
        'padding' => 0,
        'fgcolor' => [0, 0, 0],
        'bgcolor' => false,
    ];
    $qrX = $x + 15;
    $qrY = $y + 10;
    $pdf->write2DBarcode($qrContent, 'QRCODE,H', $qrX, $qrY, 22, 22, $style, 'N');

    // Label "NAMA / NAME" — 2mm di bawah QR (y+34)
    putText($pdf, $x, $y + 36, 'NAMA / NAME', 'helvetica', 'B', 7.1, 'C', $width, 4);

    // Garis pembatas di y+40
    $lineY = $y + 42;
    drawLine($pdf, $x + 1, $lineY, $x + $width - 1, $lineY, 0.2);

    // Nama di bawah garis
    putFitText($pdf, $x + 2, $lineY + 1.0, $name, $width - 4, 8.1, '', 'C');
}

function drawQrRow_2A2($pdf, float $y, array $blocks): void
{
    $blocks = array_values($blocks);
    $count = count($blocks);
    if ($count === 0) {
        return;
    }

    if ($count === 1) {
        $xPositions = [76];
    } elseif ($count === 2) {
        $xPositions = [44, 108];
    } else {
        $xPositions = [12, 76, 140];
    }

    foreach ($blocks as $index => $block) {
        drawQrBlock_2A2(
            $pdf,
            $xPositions[$index] ?? 12,
            $y,
            textOrEmpty($block['title_id'] ?? ''),
            textOrEmpty($block['title_en'] ?? ''),
            textOrEmpty($block['name'] ?? ''),
            textOrEmpty($block['payload'] ?? '')
        );
    }
}

function addQrContinuationPage_2A2($pdf, string $certificateNumber, string $vesselName): void
{
    $pdf->AddPage();
    $pdf->SetDrawColor(35, 35, 35);
    $pdf->SetTextColor(18, 18, 18);
    $pdf->Rect(5, 5, 200, 287);

    $logoPath = __DIR__ . '/../backend/assets/NO-BG-LOGO-SIS.png';
    if (file_exists($logoPath)) {
        $pdf->Image($logoPath, 12, 12, 26, 16, 'PNG', '', '', true, 300, '', false, false, 0);
    }

    putText($pdf, 40, 14,   'LANJUTAN TANDA TANGAN DIGITAL', 'helvetica', 'B', 11.5, 'C', 120, 5);
    putText($pdf, 40, 20.0, 'DIGITAL SIGNATURE CONTINUATION', 'helvetica', 'I', 8.2, 'C', 120, 4);
    putText($pdf, 10, 33.5, 'Nomor : ' . $certificateNumber, 'helvetica', '', 8.5);
    putFitText($pdf, 10, 39.0, 'Kapal : ' . upperOrEmpty($vesselName), 188, 8.5, '');
    drawLine($pdf, 10, 47.5, 200, 47.5, 0.3);
}

function drawQrContinuationPages_2A2($pdf, array $blocks, string $certificateNumber, string $vesselName): void
{
    $remainingBlocks = array_values($blocks);
    while (!empty($remainingBlocks)) {
        addQrContinuationPage_2A2($pdf, $certificateNumber, $vesselName);
        $pageBlocks = array_splice($remainingBlocks, 0, 4);
        $rows = array_chunk($pageBlocks, 2);
        $startY = 66;
        $rowGap = 62;
        foreach ($rows as $rowIndex => $rowBlocks) {
            drawQrRow_2A2($pdf, $startY + ($rowIndex * $rowGap), $rowBlocks);
        }
    }
}

// ─── MAIN ────────────────────────────────────────────────────────────────────
try {
    $assistanceId    = null;
    $input           = [];
    $requesterUserId = 0;
    $requesterName   = '';
    $requesterRole   = '';
    $signatureBase64 = '';

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        if (!is_array($input)) {
            $input = [];
        }
        $assistanceId    = isset($input['id'])                ? (int) $input['id']                : null;
        $requesterUserId = isset($input['requester_user_id']) ? (int) $input['requester_user_id'] : 0;
        $requesterName   = textOrEmpty($input['requester_name'] ?? '');
        $requesterRole   = textOrEmpty($input['requester_role'] ?? '');
        $signatureBase64 = textOrEmpty($input['signature'] ?? '');
    } else {
        $assistanceId = isset($_GET['id']) ? (int) $_GET['id'] : null;
    }

    if (!$assistanceId) {
        throw new Exception("ID assistance tidak ditemukan");
    }

    $certificateSource = fetchCertificateDataSource_2A2($conn, $assistanceId);
    $sourceTable = $certificateSource['table'];
    $data = $certificateSource['data'];

    $hasSourceSignatureColumn = $sourceTable === 'assistance_logs'
        ? hasAssistanceSignatureColumn_2A2($conn)
        : hasActivitySignatureColumn_2A2($conn);
    if ($signatureBase64 === '' && $hasSourceSignatureColumn) {
        $signatureBase64 = textOrEmpty($data['signature'] ?? '');
    }

    // ── Resolve values ────────────────────────────────────────────────────────
    $certificateNumber = buildCertificateNumber($data);
    $requestNumber     = buildServiceRequestNumber($data);
    $serviceDateValue = pickValue($data, ['date', 'assistance_start', 'vessel_start', 'pilot_on_board']);
    $startValue       = pickValue($data, ['assistance_start', 'vessel_start', 'pilot_on_board']);
    $endValue         = pickValue($data, ['assistance_end', 'pilot_finished', 'pilot_get_off']);

    $serviceDate      = formatDateOnly_2A2($serviceDateValue);
    $startTime        = formatTimeOnly_2A2($startValue);
    $endDate          = formatDateOnly_2A2($endValue !== '' ? $endValue : $serviceDateValue);
    if ($endDate === '') {
        $endDate = $serviceDate;
    }
    $endTime     = formatTimeOnly_2A2($endValue);
    $duration    = formatDurationValue_2A2($serviceDateValue, $startValue, $endValue);
    $description = pickValue($data, ['notes', 'description', 'keterangan'], '-');

    $assistTugs = buildAssistTugRows_2A2($data);
    $displayAssistTugs = array_values(array_filter($assistTugs, static function ($tug) {
        return textOrEmpty($tug['name'] ?? '') !== '' || textOrEmpty($tug['power'] ?? '') !== '';
    }));
    if (empty($displayAssistTugs)) {
        $displayAssistTugs[] = $assistTugs[0] ?? ['name' => '', 'power' => ''];
    }

    $managerProfile      = resolveManagerSignatureProfile_2A2($conn, $requesterUserId, $requesterRole);
    $managerFallbackName = pickValue($data, ['manager_name', 'supervisor_name'], '');
    if ($managerFallbackName === '' && in_array(strtolower(trim($requesterRole)), ['admin', 'superadmin'], true)) {
        $managerFallbackName = $requesterName;
    }
    if ($managerFallbackName === '') {
        $managerFallbackName = textOrEmpty($managerProfile['name'] ?? 'PT. SNEPAC INDO SERVICE');
    }
    $managerName = upperOrEmpty($managerFallbackName);

    $masterAgentName = upperOrEmpty($data['master_name'] ?? '');
    if ($masterAgentName === '') {
        $masterAgentName = upperOrEmpty($data['agency'] ?? '');
    }

    // ── PDF init ──────────────────────────────────────────────────────────────
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

    // ── Logo & header ─────────────────────────────────────────────────────────
    $logoPath = __DIR__ . '/../backend/assets/NO-BG-LOGO-SIS.png';
    if (file_exists($logoPath)) {
        $pdf->Image($logoPath, 11, 12, 30, 18, 'PNG', '', '', true, 300, '', false, false, 0);
    }

    $pdf->SetTextColor(24, 112, 196);
    putText($pdf, 163, 14, 'PELINDO', 'helvetica', 'B', 13);
    $pdf->SetTextColor(245, 90, 60);
    putText($pdf, 166.5, 20.5, 'SOLUSI DIGITAL', 'helvetica', 'B', 5.8);
    $pdf->SetTextColor(18, 18, 18);

    putText($pdf, 42, 14,   'BUKTI PEMAKAIAN JASA TUNDA', 'helvetica', 'B', 12,  'C', 125, 5);
    putText($pdf, 42, 20.2, 'TUG BOAT CERTIFICATE',        'helvetica', '',  10,  'C', 125, 4);
    putText($pdf, 42, 25.8, 'Nomor : ' . $certificateNumber, 'helvetica', '', 8.7, 'C', 125, 4);
    drawLine($pdf, 10, 38, 200, 38, 0.35);

    // ── Field rows ────────────────────────────────────────────────────────────
    $leftX = 10;
    $rightX = 104;
    $rowY  = 46;
    $gap   = 10.3;

    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 0), 'Nama Kapal',    'Vessel Name',       upperOrEmpty($data['vessel_name']  ?? ''), 28, 64, 8.9);
    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 1), 'Nama Nakhoda',  'Ship Master',       upperOrEmpty($data['master_name']  ?? ''), 28, 64, 8.9);
    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 2), 'Bendera',       'Flag',              upperOrEmpty($data['flag']         ?? ''), 28, 64, 8.9);
    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 3), 'Datang Dari',   'Last Port Of Call', upperOrEmpty($data['last_port']    ?? ''), 28, 64, 8.5);
    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 4), 'Isi Kotor',     'G.R.T',             appendUnit($data['gross_tonnage']  ?? '', 'Ton'), 28, 64, 8.6);
    drawFieldRow_2A2($pdf, $leftX,  $rowY + ($gap * 5), 'Panjang',       'L.O.A',             appendUnit($data['loa']            ?? '', 'm'),   28, 64, 8.6);

    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 0), 'Panggilan',     'Call Sign',         upperOrEmpty($data['call_sign']    ?? ''), 28, 64, 8.9);
    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 1), 'Keagenan Kapal','Agency',            upperOrEmpty($data['agency']       ?? ''), 28, 64, 8.2);
    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 2), 'Keterangan',    'Description',       upperOrEmpty($description),               28, 64, 8.2);
    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 3), 'Tujuan Ke',     'Next Port Of Call', upperOrEmpty($data['next_port']    ?? ''), 28, 64, 8.5);
    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 4), 'Sarat Muka',    'Fore Draft',        appendUnit($data['fore_draft']     ?? '', 'm'),   28, 64, 8.6);
    drawFieldRow_2A2($pdf, $rightX, $rowY + ($gap * 5), 'Sarat Belakang','Rear Draft',        appendUnit($data['aft_draft']      ?? '', 'm'),   28, 64, 8.6);

    // ── Statement block ───────────────────────────────────────────────────────
    $statementY = 108;
    putFitText($pdf, 10, $statementY, 'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA TUNDA NO : ' . $requestNumber, 190, 9.1, 'B');
    drawFieldRow_2A2($pdf, 10,  $statementY + 7.2, 'Dari', 'From', upperOrEmpty($data['from_where'] ?? ''), 14, 63, 8.7);
    drawFieldRow_2A2($pdf, 104, $statementY + 7.2, 'Ke',   'To',   upperOrEmpty($data['to_where']   ?? ''), 10, 64, 8.7);

    // ── Tug boat section ──────────────────────────────────────────────────────
    $tugSectionY = 130;
    putText($pdf, 10, $tugSectionY,      'IA TELAH MENGGUNAKAN KAPAL TUNDA', 'helvetica', 'B', 9.4);
    putText($pdf, 10, $tugSectionY + 4.4,'SHE DULY USED THE TUG BOAT',       'helvetica', 'I', 6.8);

    $firstRowY = 140;
    $tugRowGap = 26;
    foreach ($displayAssistTugs as $index => $assistTug) {
        $rowY = $firstRowY + ($index * $tugRowGap);
        drawTugRow_2A2($pdf, $rowY, $assistTug, $serviceDate, $startTime, $endDate, $endTime, $duration);
        if ($index < count($displayAssistTugs) - 1) {
            drawLine($pdf, 10, $rowY + 23, 200, $rowY + 23, 0.18);
        }
    }

    // ── QR / Approval block ───────────────────────────────────────────────────
    // Blok QR ~47mm tinggi: judul(9)+QR(22)+label(6)+garis+nama → y+0..y+45
    // Cukup ruang sebelum catatan di y~283
    $qrTopY = max(208, $firstRowY + ((count($displayAssistTugs) - 1) * $tugRowGap) + 22);

    $managerQrPayload = buildProfileQrPayload(
        $managerProfile,
        $managerName,
        textOrEmpty($managerProfile['role'] ?? ($requesterRole !== '' ? $requesterRole : 'admin')),
        '2A2', $assistanceId, 'MANAGER'
    );
    $masterAgentQrPayload = buildActivityQrPayload(
        $masterAgentName,
        '2A2', $assistanceId, 'MASTER_AGENT',
        $signatureBase64
    );

    $tugApprovalBlocks = [];
    foreach ($displayAssistTugs as $index => $assistTug) {
        $slot = 'TUG_MASTER_' . ($index + 1);
        $tugMasterProfile = resolveTugSignatureProfile_2A2($conn, textOrEmpty($assistTug['name'] ?? ''));
        $tugMasterName = upperOrEmpty($assistTug['name'] ?? '');
        if ($tugMasterName === '') {
            $tugMasterName = upperOrEmpty($tugMasterProfile['name'] ?? 'TUG BOAT MASTER');
        }

        $tugApprovalBlocks[] = [
            'title_id' => 'NAHKODA KAPAL TUNDA',
            'title_en' => 'TUG BOAT MASTER',
            'name'     => $tugMasterName,
            'payload'  => buildProfileQrPayload(
                $tugMasterProfile,
                $tugMasterName,
                textOrEmpty($tugMasterProfile['role'] ?? 'tugboat'),
                '2A2',
                $assistanceId,
                $slot
            ),
        ];
    }

    $primaryTugApprovalBlock = $tugApprovalBlocks[0] ?? [
        'title_id' => 'NAHKODA KAPAL TUNDA',
        'title_en' => 'TUG BOAT MASTER',
        'name'     => 'TUG BOAT MASTER',
        'payload'  => buildProfileQrPayload(null, 'TUG BOAT MASTER', 'tugboat', '2A2', $assistanceId, 'TUG_MASTER_1'),
    ];

    drawQrRow_2A2($pdf, $qrTopY, [
        [
            'title_id' => 'MANAGER PEMANDUAN',
            'title_en' => 'PILOT MANAGER',
            'name'     => $managerName,
            'payload'  => $managerQrPayload,
        ],
        $primaryTugApprovalBlock,
        [
            'title_id' => 'MASTER/ AGENT',
            'title_en' => 'NAKHODA / AGEN',
            'name'     => $masterAgentName,
            'payload'  => $masterAgentQrPayload,
        ],
    ]);

    $footerNoteY = 283;
    drawLine($pdf, 10, $footerNoteY - 2.5, 200, $footerNoteY - 2.5, 0.22);
    putText($pdf, 10, $footerNoteY,      'CATATAN',  'helvetica', 'B', 7.2);
    putText($pdf, 10, $footerNoteY + 3.4,'NOTE :',   'helvetica', 'B', 7.0);
    putText($pdf, 27, $footerNoteY,      'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______ Menit)', 'helvetica', '', 6.2);
    putText($pdf, 27, $footerNoteY + 4.0,'The work time of tug boat is the effective use plus the time for moving and the base again.', 'helvetica', 'I', 5.9);

    $overflowQrBlocks = array_slice($tugApprovalBlocks, 1);
    if (!empty($overflowQrBlocks)) {
        drawQrContinuationPages_2A2(
            $pdf,
            $overflowQrBlocks,
            $certificateNumber,
            textOrEmpty($data['vessel_name'] ?? '')
        );
    }

    // ── Footer note ───────────────────────────────────────────────────────────

    // ── Output ────────────────────────────────────────────────────────────────
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

    $conn->close();

} catch (Exception $e) {
    error_log("Assistance PDF Generation Error: " . $e->getMessage());
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status'  => 'error',
        'message' => $e->getMessage(),
    ]);
}
?>
