<?php
// generate_mooring_certificate.php
// Form 2B-1: BUKTI PEMAKAIAN JASA TUNDA (MOORING CERTIFICATE)

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', '/path/to/error.log');

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
    $pdf->SetTitle('Mooring Certificate - ' . ($data['vessel_name'] ?? ''));
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    $pdf->SetAutoPageBreak(false);
    $pdf->AddPage();

    // Background image
    $bgPath = __DIR__ . '/../backend/assets/form_tunda.jpg';
    if (file_exists($bgPath)) {
        $pdf->Image($bgPath, 0, 0, 210, 297, '', '', '', false, 300, '', false, false, 0);
    }

    // Helper functions
    function putTextMooring($pdf, $x, $y, $text, $font='helvetica', $style='', $size=9, $align='L') {
        $text = (string) $text;
        $text = iconv('UTF-8', 'UTF-8//IGNORE', $text);
        $text = trim(substr($text, 0, 50));
        $pdf->SetFont($font, $style, $size);
        $pdf->SetXY($x, $y);
        $pdf->Cell(0, 4, $text, 0, 0, $align);
    }

    function safeValueMooring($val) {
        if ($val === null || $val === '') return '';
        $val = trim($val);
        $val = iconv('UTF-8', 'UTF-8//IGNORE', $val);
        return mb_strtoupper($val, 'UTF-8');
    }

    // Add signature to PDF if provided
    if (!empty($signatureBase64)) {
        // Remove data:image/png;base64, prefix if present
        $signatureData = $signatureBase64;
        if (strpos($signatureData, 'data:image') !== false) {
            $signatureData = preg_replace('/^data:image\/\w+;base64,/', '', $signatureData);
        }
        
        $signatureImage = base64_decode($signatureData);
        if ($signatureImage !== false) {
            // Add signature image to PDF (adjust coordinates as needed)
            $pdf->Image('@' . $signatureImage, 140, 250, 50, 20, 'PNG', '', '', true, 150, '', false, false, 0);
        }
    }

    // No. BTM (di kanan atas)
    $noBTM = $data['certificate_no'] ?? '6501-3479';
    putTextMooring($pdf, 175, 15, $noBTM, 'helvetica', 'B', 10, 'R');

    // VESSEL INFORMATION (kolom kiri)
    putTextMooring($pdf, 41, 55, safeValueMooring($data['vessel_name']), 'helvetica', '', 12);
    putTextMooring($pdf, 41, 64, safeValueMooring($data['master_name']), 'helvetica', '', 12);
    putTextMooring($pdf, 41, 72, safeValueMooring($data['flag']), 'helvetica', '', 12);
    putTextMooring($pdf, 41, 82, safeValueMooring($data['last_port']), 'helvetica', '', 12);
    putTextMooring($pdf, 41, 90, $data['gross_tonnage'] ?? '', 'helvetica', '', 12);
    putTextMooring($pdf, 41, 99, safeValueMooring($data['agency']), 'helvetica', '', 12);

    // VESSEL INFORMATION (kolom kanan)
    putTextMooring($pdf, 141, 62, safeValueMooring($data['call_sign']), 'helvetica', '', 12);
    putTextMooring($pdf, 141, 71, safeValueMooring($data['next_port']), 'helvetica', '', 12);
    putTextMooring($pdf, 141, 80, ($data['loa'] ?? '') . ($data['loa'] ? ' m' : ''), 'helvetica', '', 12);
    putTextMooring($pdf, 141, 89, ($data['fore_draft'] ?? '') . ($data['fore_draft'] ? ' m' : ''), 'helvetica', '', 12);
    putTextMooring($pdf, 141, 98, ($data['aft_draft'] ?? '') . ($data['aft_draft'] ? ' m' : ''), 'helvetica', '', 12);

    // Tanggal & Jam Berlabuh
    if (!empty($data['date']) && $data['date'] !== '0000-00-00' && $data['date'] !== null) {
        $timestamp = strtotime($data['date']);
        if ($timestamp !== false && $timestamp > 0) {
            $anchorDate = date('dmY', $timestamp);
            if (!empty($anchorDate) && strlen($anchorDate) == 8 && is_numeric($anchorDate)) {
                $dateParts = str_split($anchorDate);
                if (is_array($dateParts) && count($dateParts) == 8) {
                    $xStart = 88;
                    for ($i = 0; $i < 8; $i++) {
                        $digit = isset($dateParts[$i]) ? $dateParts[$i] : '0';
                        if (is_numeric($digit)) {
                            putTextMooring($pdf, $xStart + ($i * 4.5), 95, $digit, 'helvetica', '', 9, 'C');
                        }
                    }
                }
            }
        }
    }

    if (!empty($data['pilot_on_board']) && $data['pilot_on_board'] !== '0000-00-00 00:00:00' && $data['pilot_on_board'] !== null) {
        $timestamp = strtotime($data['pilot_on_board']);
        if ($timestamp !== false && $timestamp > 0) {
            $anchorTime = date('Hi', $timestamp);
            if (!empty($anchorTime) && strlen($anchorTime) == 4 && is_numeric($anchorTime)) {
                $timeParts = str_split($anchorTime);
                if (is_array($timeParts) && count($timeParts) == 4) {
                    $xStart = 160;
                    for ($i = 0; $i < 4; $i++) {
                        $digit = isset($timeParts[$i]) ? $timeParts[$i] : '0';
                        if (is_numeric($digit)) {
                            putTextMooring($pdf, $xStart + ($i * 4.5), 95, $digit, 'helvetica', '', 9, 'C');
                        }
                    }
                }
            }
        }
    }

    // Mooring INFORMATION
    putTextMooring($pdf, 21, 137.8, safeValueMooring($data['from_where']), 'helvetica', '', 7);
    putTextMooring($pdf, 77, 137.8, safeValueMooring($data['to_where']), 'helvetica', '', 7);

    // Mooring Details
    putTextMooring($pdf, 30, 125, safeValueMooring($data['pilot_name']), 'helvetica', '', 9);

    // Ship Start
    if (!empty($data['vessel_start']) && $data['vessel_start'] !== '0000-00-00 00:00:00') {
        $timestamp = strtotime($data['vessel_start']);
        if ($timestamp !== false && $timestamp > 0) {
            $shipStartTime = date('H:i', $timestamp);
            putTextMooring($pdf, 160, 125, $shipStartTime, 'helvetica', '', 8);
        }
    }

    // Tunda Selesai (Mooring Get Off)
    if (!empty($data['pilot_get_off']) && $data['pilot_get_off'] !== '0000-00-00 00:00:00') {
        $timestamp = strtotime($data['pilot_get_off']);
        if ($timestamp !== false && $timestamp > 0) {
            $offDate = date('d-m-Y', $timestamp);
            putTextMooring($pdf, 154, 132, $offDate, 'helvetica', '', 14);
        }
    }

    // Mooring/Unmooring Unit
    if (!empty($data['mooring_unit'])) {
        putTextMooring($pdf, 120, 148, date('H:i', strtotime($data['mooring_unit'])), 'helvetica', '', 8);
    }
    if (!empty($data['unmooring_unit'])) {
        putTextMooring($pdf, 165, 148, date('H:i', strtotime($data['unmooring_unit'])), 'helvetica', '', 8);
    }

    // Pada Tanggal (date)
    if (!empty($data['date']) && $data['date'] !== '0000-00-00') {
        $timestamp = strtotime($data['date']);
        if ($timestamp !== false && $timestamp > 0) {
            $serviceDate = date('dmY', $timestamp);
            if (strlen($serviceDate) >= 6) {
                $serviceDate = str_pad($serviceDate, 8, '0', STR_PAD_LEFT);
                if (strlen($serviceDate) == 8) {
                    $dateParts = str_split($serviceDate);
                    $xStart = 165;
                    foreach ($dateParts as $i => $digit) {
                        putTextMooring($pdf, $xStart + ($i * 4.5), 148, $digit, 'helvetica', '', 8, 'C');
                    }
                }
            }
        }
    }

    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', $data['vessel_name'] ?? 'mooring_certificate');
    $filename = "Mooring_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";
    ob_end_clean();
    $pdf->Output($filename, 'I');

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
