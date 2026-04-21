<?php
ini_set('display_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

require_once __DIR__ . '/../backend/config/config.php';

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

function normalizeSignatureDataUrl($value): string
{
    $text = textOrEmpty($value);
    if ($text === '') {
        return '';
    }
    if (preg_match('/^data:image\/[a-zA-Z0-9.+-]+;base64,/i', $text) === 1) {
        return $text;
    }
    if (preg_match('/^[A-Za-z0-9+\/=\r\n]+$/', $text) === 1) {
        return 'data:image/png;base64,' . preg_replace('/\s+/', '', $text);
    }
    return '';
}

function html($value): string
{
    return htmlspecialchars(textOrEmpty($value), ENT_QUOTES, 'UTF-8');
}

function signatureHash(string $source): string
{
    return substr(hash('sha256', $source), 0, 20);
}

function tableExists(mysqli $conn, string $table): bool
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

function hasUserSignatureColumn(mysqli $conn): bool
{
    static $checked = null;
    if ($checked !== null) {
        return $checked;
    }
    $result = $conn->query("SHOW COLUMNS FROM users LIKE 'signature_data'");
    $checked = $result && $result->num_rows > 0;
    return $checked;
}

function hasTableColumn(mysqli $conn, string $table, string $column): bool
{
    static $checked = [];
    $cacheKey = $table . '.' . $column;
    if (array_key_exists($cacheKey, $checked)) {
        return $checked[$cacheKey];
    }
    if (!tableExists($conn, $table)) {
        $checked[$cacheKey] = false;
        return false;
    }
    $tableName = str_replace(['_', '%'], ['\\_', '\\%'], $conn->real_escape_string($table));
    $columnName = str_replace(['_', '%'], ['\\_', '\\%'], $conn->real_escape_string($column));
    $result = $conn->query("SHOW COLUMNS FROM `{$table}` LIKE '{$columnName}'");
    $checked[$cacheKey] = $result && $result->num_rows > 0;
    return $checked[$cacheKey];
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

function getAssistTugNames(array $data): array
{
    $names = [];
    for ($i = 1; $i <= 3; $i++) {
        $name = pickValue($data, ['assist_tug_name_' . $i]);
        if ($name !== '') {
            $names[] = $name;
        }
    }
    if (!empty($names)) {
        return array_values(array_unique($names));
    }
    return parseDelimitedValues(pickValue($data, ['assist_tug_name']));
}

function getAssistTugNameByIndex(array $data, int $index): string
{
    $names = getAssistTugNames($data);
    return $names[$index] ?? ($names[0] ?? '');
}

function tugMasterSlotIndex(string $slot): int
{
    if (preg_match('/^TUG_MASTER(?:_(\d+))?$/', $slot, $matches) !== 1) {
        return 0;
    }
    $index = isset($matches[1]) ? (int) $matches[1] : 1;
    return max($index - 1, 0);
}

function fetchRowById(mysqli $conn, string $table, int $id): ?array
{
    if (!tableExists($conn, $table)) {
        return null;
    }
    $stmt = $conn->prepare("SELECT * FROM `{$table}` WHERE id = ?");
    if (!$stmt) {
        return null;
    }
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = ($result && $result->num_rows > 0) ? $result->fetch_assoc() : null;
    $stmt->close();
    return $row ?: null;
}

function fetchUserByNameAndRoles(mysqli $conn, string $name, array $roles, bool $requireSignature = false): ?array
{
    if (!hasUserSignatureColumn($conn) || $name === '' || empty($roles)) {
        return null;
    }

    $normalizedRoles = array_values(array_filter(array_map(static function ($role) {
        return strtolower(trim((string) $role));
    }, $roles), static function ($role) {
        return $role !== '';
    }));
    if (empty($normalizedRoles)) {
        return null;
    }

    $placeholders = implode(',', array_fill(0, count($normalizedRoles), '?'));
    $sql = "SELECT id, name, role, signature_data
            FROM users
            WHERE LOWER(TRIM(COALESCE(name, ''))) = LOWER(TRIM(?))
            AND LOWER(TRIM(COALESCE(role, ''))) IN ({$placeholders})";
    if ($requireSignature) {
        $sql .= " AND TRIM(COALESCE(signature_data, '')) <> ''";
    }
    $sql .= " LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }

    $types = 's' . str_repeat('s', count($normalizedRoles));
    $params = array_merge([$name], $normalizedRoles);

    $refs = [];
    foreach ($params as $index => $param) {
        $refs[$index] = &$params[$index];
    }

    array_unshift($refs, $types);
    call_user_func_array([$stmt, 'bind_param'], $refs);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = ($result && $result->num_rows > 0) ? $result->fetch_assoc() : null;
    $stmt->close();
    return $row ?: null;
}

function fetchUserByIdAndRoles(mysqli $conn, int $userId, array $roles, bool $requireSignature = false): ?array
{
    if (!hasUserSignatureColumn($conn) || $userId <= 0 || empty($roles)) {
        return null;
    }

    $normalizedRoles = array_values(array_filter(array_map(static function ($role) {
        return strtolower(trim((string) $role));
    }, $roles), static function ($role) {
        return $role !== '';
    }));
    if (empty($normalizedRoles)) {
        return null;
    }

    $placeholders = implode(',', array_fill(0, count($normalizedRoles), '?'));
    $sql = "SELECT id, name, role, signature_data
            FROM users
            WHERE id = ?
            AND LOWER(TRIM(COALESCE(role, ''))) IN ({$placeholders})";
    if ($requireSignature) {
        $sql .= " AND TRIM(COALESCE(signature_data, '')) <> ''";
    }
    $sql .= " LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }

    $types = 'i' . str_repeat('s', count($normalizedRoles));
    $params = array_merge([$userId], $normalizedRoles);
    $refs = [];
    foreach ($params as $index => $param) {
        $refs[$index] = &$params[$index];
    }

    array_unshift($refs, $types);
    call_user_func_array([$stmt, 'bind_param'], $refs);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = ($result && $result->num_rows > 0) ? $result->fetch_assoc() : null;
    $stmt->close();
    return $row ?: null;
}

function fetchFirstUserByRoles(mysqli $conn, array $roles, bool $requireSignature = false): ?array
{
    if (!hasUserSignatureColumn($conn) || empty($roles)) {
        return null;
    }

    $normalizedRoles = array_values(array_filter(array_map(static function ($role) {
        return strtolower(trim((string) $role));
    }, $roles), static function ($role) {
        return $role !== '';
    }));
    if (empty($normalizedRoles)) {
        return null;
    }

    $placeholders = implode(',', array_fill(0, count($normalizedRoles), '?'));
    $sql = "SELECT id, name, role, signature_data
            FROM users
            WHERE LOWER(TRIM(COALESCE(role, ''))) IN ({$placeholders})";
    if ($requireSignature) {
        $sql .= " AND TRIM(COALESCE(signature_data, '')) <> ''";
    }
    $sql .= " ORDER BY id ASC LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        return null;
    }

    $types = str_repeat('s', count($normalizedRoles));
    $refs = [];
    foreach ($normalizedRoles as $index => $param) {
        $refs[$index] = &$normalizedRoles[$index];
    }
    array_unshift($refs, $types);
    call_user_func_array([$stmt, 'bind_param'], $refs);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = ($result && $result->num_rows > 0) ? $result->fetch_assoc() : null;
    $stmt->close();
    return $row ?: null;
}

function fetchDocumentContext(mysqli $conn, string $documentType, int $documentId): array
{
    if ($documentType === '2A1') {
        $row = fetchRowById($conn, 'activity_logs', $documentId);
        if (!$row) {
            throw new Exception('Data 2A1 tidak ditemukan');
        }
        return ['table' => 'activity_logs', 'data' => $row];
    }

    if ($documentType === '2A2') {
        $row = fetchRowById($conn, 'assistance_logs', $documentId);
        if ($row) {
            return ['table' => 'assistance_logs', 'data' => $row];
        }

        $row = fetchRowById($conn, 'activity_logs', $documentId);
        if ($row) {
            return ['table' => 'activity_logs', 'data' => $row];
        }

        throw new Exception('Data 2A2 tidak ditemukan');
    }

    throw new Exception('Jenis dokumen tidak dikenal');
}

function resolveSignatureViewData(mysqli $conn, string $documentType, string $slot, array $context): array
{
    $table = $context['table'];
    $data = $context['data'];
    $tableHasSignature = hasTableColumn($conn, $table, 'signature');

    if ($documentType === '2A1' && $slot === 'MANAGER') {
        $candidateName = pickValue($data, ['manager_name', 'supervisor_name']);
        $profile = $candidateName !== ''
            ? fetchUserByNameAndRoles($conn, $candidateName, ['admin', 'superadmin'], true)
            : null;
        if (!$profile) {
            $profile = fetchFirstUserByRoles($conn, ['admin', 'superadmin'], true);
        }

        return [
            'display_name' => upperOrEmpty($profile['name'] ?? ($candidateName !== '' ? $candidateName : 'PT. SNEPAC INDO SERVICE')),
            'display_role' => upperOrEmpty($profile['role'] ?? 'admin'),
            'signature'    => normalizeSignatureDataUrl($profile['signature_data'] ?? ''),
            'kind'         => 'profile',
        ];
    }

    if ($documentType === '2A1' && $slot === 'PILOT') {
        $pilotUserId = isset($data['pilot_user_id']) ? (int) $data['pilot_user_id'] : 0;
        $pilotName = pickValue($data, ['pilot_name']);
        $profile = $pilotUserId > 0
            ? fetchUserByIdAndRoles($conn, $pilotUserId, ['pilot', 'pandu'], false)
            : null;
        if (!$profile) {
            $profile = fetchUserByNameAndRoles($conn, $pilotName, ['pilot', 'pandu'], false);
        }

        return [
            'display_name' => upperOrEmpty($profile['name'] ?? ($pilotName !== '' ? $pilotName : 'MARINE PILOT')),
            'display_role' => upperOrEmpty($profile['role'] ?? 'pilot'),
            'signature'    => normalizeSignatureDataUrl($profile['signature_data'] ?? ''),
            'kind'         => 'profile',
        ];
    }

    if ($documentType === '2A1' && $slot === 'MASTER_AGENT') {
        $displayName = upperOrEmpty(pickValue($data, ['master_name', 'agency'], 'MASTER / AGENT'));
        $signature = $tableHasSignature ? normalizeSignatureDataUrl($data['signature'] ?? '') : '';

        return [
            'display_name' => $displayName,
            'display_role' => 'EXTERNAL',
            'signature'    => $signature,
            'kind'         => 'activity',
        ];
    }

    if ($documentType === '2A2' && $slot === 'MANAGER') {
        $candidateName = pickValue($data, ['manager_name', 'supervisor_name']);
        $profile = $candidateName !== ''
            ? fetchUserByNameAndRoles($conn, $candidateName, ['admin', 'superadmin'], true)
            : null;
        if (!$profile) {
            $profile = fetchFirstUserByRoles($conn, ['admin', 'superadmin'], true);
        }

        return [
            'display_name' => upperOrEmpty($profile['name'] ?? ($candidateName !== '' ? $candidateName : 'PT. SNEPAC INDO SERVICE')),
            'display_role' => upperOrEmpty($profile['role'] ?? 'admin'),
            'signature'    => normalizeSignatureDataUrl($profile['signature_data'] ?? ''),
            'kind'         => 'profile',
        ];
    }

    if ($documentType === '2A2' && preg_match('/^TUG_MASTER(?:_\d+)?$/', $slot) === 1) {
        $tugName = getAssistTugNameByIndex($data, tugMasterSlotIndex($slot));
        $profile = $tugName !== ''
            ? fetchUserByNameAndRoles($conn, $tugName, ['tugboat'], false)
            : null;
        if (!$profile) {
            $profile = fetchFirstUserByRoles($conn, ['tugboat'], true);
        }

        return [
            'display_name' => upperOrEmpty($profile['name'] ?? ($tugName !== '' ? $tugName : 'TUG BOAT MASTER')),
            'display_role' => upperOrEmpty($profile['role'] ?? 'tugboat'),
            'signature'    => normalizeSignatureDataUrl($profile['signature_data'] ?? ''),
            'kind'         => 'profile',
        ];
    }

    if ($documentType === '2A2' && $slot === 'MASTER_AGENT') {
        $displayName = upperOrEmpty(pickValue($data, ['master_name', 'agency'], 'MASTER / AGENT'));
        $signature = $tableHasSignature ? normalizeSignatureDataUrl($data['signature'] ?? '') : '';

        return [
            'display_name' => $displayName,
            'display_role' => 'EXTERNAL',
            'signature'    => $signature,
            'kind'         => 'activity',
        ];
    }

    throw new Exception('Slot tanda tangan tidak dikenal');
}

function buildSourceForHash(array $signatureView): string
{
    $signature = textOrEmpty($signatureView['signature'] ?? '');
    $displayName = textOrEmpty($signatureView['display_name'] ?? '');
    $displayRole = textOrEmpty($signatureView['display_role'] ?? '');
    $kind = textOrEmpty($signatureView['kind'] ?? '');

    if ($signature !== '') {
        return $signature;
    }

    if ($kind === 'activity') {
        return $displayName . '|NOSIG';
    }

    return $displayName . '|' . $displayRole . '|NOSIG';
}

function slotLabel(string $slot): string
{
    if (preg_match('/^TUG_MASTER(?:_(\d+))?$/', $slot, $matches) === 1) {
        $index = isset($matches[1]) ? (int) $matches[1] : 1;
        return $index > 1 ? 'Tug Boat Master ' . $index : 'Tug Boat Master';
    }

    $labels = [
        'MANAGER'      => 'Manager',
        'PILOT'        => 'Marine Pilot',
        'MASTER_AGENT' => 'Master / Agent',
    ];
    return $labels[$slot] ?? $slot;
}

$documentType = strtoupper(textOrEmpty($_GET['d'] ?? ''));
$documentId = (int) ($_GET['i'] ?? 0);
$slot = strtoupper(textOrEmpty($_GET['s'] ?? ''));
$expectedHash = strtolower(textOrEmpty($_GET['k'] ?? ''));

$pageTitle = 'Verifikasi Tanda Tangan';
$errorMessage = '';
$signatureView = null;
$hashStatus = 'unknown';
$documentLabel = $documentType;

try {
    if (!in_array($documentType, ['2A1', '2A2'], true)) {
        throw new Exception('Parameter dokumen tidak valid');
    }
    if ($documentId <= 0) {
        throw new Exception('ID dokumen tidak valid');
    }
    if (
        !in_array($slot, ['MANAGER', 'PILOT', 'MASTER_AGENT'], true)
        && preg_match('/^TUG_MASTER(?:_\d+)?$/', $slot) !== 1
    ) {
        throw new Exception('Parameter slot tidak valid');
    }

    $documentLabel = $documentType === '2A1' ? 'Form Pandu 2A1' : 'Form Tunda 2A2';
    $context = fetchDocumentContext($conn, $documentType, $documentId);
    $signatureView = resolveSignatureViewData($conn, $documentType, $slot, $context);
    $actualHash = signatureHash(buildSourceForHash($signatureView));

    if ($expectedHash !== '') {
        $hashStatus = hash_equals($actualHash, $expectedHash) ? 'match' : 'mismatch';
    }
} catch (Exception $e) {
    $errorMessage = $e->getMessage();
}

header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= html($pageTitle) ?></title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f3f6fb;
      --card: #ffffff;
      --ink: #1b2635;
      --muted: #5e6b7a;
      --line: #d6dee8;
      --accent: #0b5cab;
      --good-bg: #eaf7ef;
      --good-fg: #1d6b3a;
      --warn-bg: #fff4e5;
      --warn-fg: #9a5d00;
      --bad-bg: #fdecec;
      --bad-fg: #a12626;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(180deg, #f7f9fc 0%, var(--bg) 100%);
      color: var(--ink);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 24px;
    }

    .card {
      width: min(720px, 100%);
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 20px;
      box-shadow: 0 16px 40px rgba(21, 40, 70, 0.08);
      overflow: hidden;
    }

    .header {
      padding: 24px 28px 18px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(135deg, #ffffff 0%, #eef5ff 100%);
    }

    .title {
      margin: 0;
      font-size: 28px;
      font-weight: 700;
    }

    .subtitle {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 15px;
    }

    .content {
      padding: 28px;
      display: grid;
      gap: 20px;
    }

    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 14px;
      border-radius: 999px;
      font-size: 14px;
      font-weight: 600;
      width: fit-content;
    }

    .badge.good { background: var(--good-bg); color: var(--good-fg); }
    .badge.warn { background: var(--warn-bg); color: var(--warn-fg); }
    .badge.bad { background: var(--bad-bg); color: var(--bad-fg); }

    .meta {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 14px;
    }

    .meta-item {
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 14px 16px;
      background: #fbfdff;
    }

    .meta-label {
      font-size: 12px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 8px;
    }

    .meta-value {
      font-size: 16px;
      font-weight: 600;
      word-break: break-word;
    }

    .signature-box {
      border: 1px dashed #b9c8d8;
      border-radius: 18px;
      min-height: 240px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(180deg, #ffffff 0%, #f8fbff 100%);
      padding: 20px;
    }

    .signature-box img {
      max-width: 100%;
      max-height: 320px;
      object-fit: contain;
    }

    .empty {
      color: var(--muted);
      text-align: center;
      max-width: 420px;
      line-height: 1.5;
    }

    .error {
      border-radius: 16px;
      background: var(--bad-bg);
      color: var(--bad-fg);
      padding: 18px 20px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <main class="card">
    <section class="header">
      <h1 class="title">Verifikasi Tanda Tangan</h1>
      <p class="subtitle">Halaman ini dibuka dari QR pada sertifikat digital.</p>
    </section>

    <section class="content">
      <?php if ($errorMessage !== ''): ?>
        <div class="error"><?= html($errorMessage) ?></div>
      <?php else: ?>
        <?php if ($hashStatus === 'match'): ?>
          <div class="badge good">Valid dan cocok dengan QR</div>
        <?php elseif ($hashStatus === 'mismatch'): ?>
          <div class="badge warn">Data tanda tangan saat ini berbeda dengan hash di QR</div>
        <?php else: ?>
          <div class="badge warn">Hash QR tidak tersedia untuk divalidasi</div>
        <?php endif; ?>

        <div class="meta">
          <div class="meta-item">
            <div class="meta-label">Dokumen</div>
            <div class="meta-value"><?= html($documentLabel) ?></div>
          </div>
          <div class="meta-item">
            <div class="meta-label">ID Dokumen</div>
            <div class="meta-value"><?= html((string) $documentId) ?></div>
          </div>
          <div class="meta-item">
            <div class="meta-label">Posisi Tanda Tangan</div>
            <div class="meta-value"><?= html(slotLabel($slot)) ?></div>
          </div>
          <div class="meta-item">
            <div class="meta-label">Nama</div>
            <div class="meta-value"><?= html($signatureView['display_name'] ?? '-') ?></div>
          </div>
          <div class="meta-item">
            <div class="meta-label">Role</div>
            <div class="meta-value"><?= html($signatureView['display_role'] ?? '-') ?></div>
          </div>
        </div>

        <div class="signature-box">
          <?php if (textOrEmpty($signatureView['signature'] ?? '') !== ''): ?>
            <img src="<?= html($signatureView['signature']) ?>" alt="Tanda tangan digital">
          <?php else: ?>
            <div class="empty">
              Gambar tanda tangan belum tersedia untuk slot ini.
              Jika ini tanda tangan profile, pastikan user terkait sudah menyimpan `signature_data`.
              Jika ini `MASTER / AGENT`, pastikan tanda tangan tersimpan di data aktivitas.
            </div>
          <?php endif; ?>
        </div>
      <?php endif; ?>
    </section>
  </main>
</body>
</html>
