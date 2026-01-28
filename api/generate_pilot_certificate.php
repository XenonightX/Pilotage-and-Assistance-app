<?php
// generate_pilot_certificate.php
// Form 2A-1: BUKTI PEMAKAIAN JASA PANDU (PILOT CERTIFICATE)

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
    $pilotageId = isset($_GET['id']) ? (int) $_GET['id'] : null;
    if (!$pilotageId) throw new Exception("ID pilotage tidak ditemukan");

    // Ambil data dari database
    $sql = "SELECT * FROM pilotage_logs WHERE id = ?";
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

    // Helper functions
    function putText($pdf, $x, $y, $text, $font='helvetica', $style='', $size=9, $align='L') {
        $pdf->SetFont($font, $style, $size);
        $pdf->SetXY($x, $y);
        $pdf->Cell(0, 4, $text, 0, 0, $align);
    }

    function safeValue($val) {
        return ($val === null || $val === '') ? '' : mb_strtoupper(trim($val), 'UTF-8');
    }

    // No. BTM (di kanan atas)
    $noBTM = $data['certificate_no'] ?? '6501-3479';
    putText($pdf, 175, 15, $noBTM, 'helvetica', 'B', 10, 'R');

    // VESSEL INFORMATION (kolom kiri)
    putText($pdf, 41, 55, safeValue($data['vessel_name']), 'helvetica', '', 12);
    putText($pdf, 41, 64, safeValue($data['master_name']), 'helvetica', '', 12);
    putText($pdf, 41, 72, safeValue($data['flag']), 'helvetica', '', 12);
    putText($pdf, 41, 82, safeValue($data['last_port']), 'helvetica', '', 12);
    putText($pdf, 41, 90, $data['gross_tonnage'] ?? '', 'helvetica', '', 12);
    putText($pdf, 41, 99, safeValue($data['agency']), 'helvetica', '', 12);

    // VESSEL INFORMATION (kolom kanan)
    putText($pdf, 141, 62, safeValue($data['call_sign']), 'helvetica', '', 12);
    putText($pdf, 141, 71, safeValue($data['next_port']), 'helvetica', '', 12);
    putText($pdf, 141, 80, ($data['loa'] ?? '') . ($data['loa'] ? ' m' : ''), 'helvetica', '', 12);
    putText($pdf, 141, 89, ($data['fore_draft'] ?? '') . ($data['fore_draft'] ? ' m' : ''), 'helvetica', '', 12);
    putText($pdf, 141, 98, ($data['aft_draft'] ?? '') . ($data['aft_draft'] ? ' m' : ''), 'helvetica', '', 12);

    // Tanggal & Jam Berlabuh
    if (!empty($data['anchor_date'])) {
        $anchorDate = date('d-m-Y', strtotime($data['anchor_date']));
        $dateParts = str_split(str_replace('-', '', $anchorDate));
        $xStart = 88;
        foreach ($dateParts as $i => $digit) {
            putText($pdf, $xStart + ($i * 4.5), 95, $digit, 'helvetica', '', 9, 'C');
        }
    }

    if (!empty($data['anchor_time'])) {
        $anchorTime = date('H:i', strtotime($data['anchor_time']));
        $timeParts = str_split(str_replace(':', '', $anchorTime));
        $xStart = 160;
        foreach ($timeParts as $i => $digit) {
            putText($pdf, $xStart + ($i * 4.5), 95, $digit, 'helvetica', '', 9, 'C');
        }
    }

    // PILOT INFORMATION
    putText($pdf, 30, 112, safeValue($data['from_location']), 'helvetica', '', 9);
    putText($pdf, 95, 112, safeValue($data['to_location']), 'helvetica', '', 9);

    // Pilot Details
    putText($pdf, 30, 125, safeValue($data['pilot_name']), 'helvetica', '', 9);
    
    // Ship Start
    if (!empty($data['ship_start'])) {
        putText($pdf, 120, 125, date('d-m-Y H:i', strtotime($data['ship_start'])), 'helvetica', '', 8);
    }

    // Pandu Turun (Pilot Get Off)
    if (!empty($data['pilot_get_off'])) {
        putText($pdf, 120, 133, date('d-m-Y H:i', strtotime($data['pilot_get_off'])), 'helvetica', '', 8);
    }

    // Mooring/Unmooring Unit
    if (!empty($data['mooring_unit'])) {
        putText($pdf, 120, 148, date('H:i', strtotime($data['mooring_unit'])), 'helvetica', '', 8);
    }
    if (!empty($data['unmooring_unit'])) {
        putText($pdf, 165, 148, date('H:i', strtotime($data['unmooring_unit'])), 'helvetica', '', 8);
    }

    // Pada Tanggal (date)
    if (!empty($data['service_date'])) {
        $serviceDate = date('d-m-Y', strtotime($data['service_date']));
        $dateParts = str_split(str_replace('-', '', $serviceDate));
        $xStart = 165;
        foreach ($dateParts as $i => $digit) {
            putText($pdf, $xStart + ($i * 4.5), 148, $digit, 'helvetica', '', 8, 'C');
        }
    }

    // TUG BOAT USAGE (up to 4 tug boats)
    $tugBoats = [
        ['name' => $data['tug_boat_1_name'] ?? '', 'engine_power' => $data['tug_boat_1_power'] ?? '',
         'tk_power' => $data['tug_boat_1_tk_power'] ?? '', 'hp_time' => $data['tug_boat_1_hp_time'] ?? '',
         'up_to' => $data['tug_boat_1_up_to'] ?? ''],
        ['name' => $data['tug_boat_2_name'] ?? '', 'engine_power' => $data['tug_boat_2_power'] ?? '',
         'tk_power' => $data['tug_boat_2_tk_power'] ?? '', 'hp_time' => $data['tug_boat_2_hp_time'] ?? '',
         'up_to' => $data['tug_boat_2_up_to'] ?? ''],
        ['name' => $data['tug_boat_3_name'] ?? '', 'engine_power' => $data['tug_boat_3_power'] ?? '',
         'tk_power' => $data['tug_boat_3_tk_power'] ?? '', 'hp_time' => $data['tug_boat_3_hp_time'] ?? '',
         'up_to' => $data['tug_boat_3_up_to'] ?? ''],
        ['name' => $data['tug_boat_4_name'] ?? '', 'engine_power' => $data['tug_boat_4_power'] ?? '',
         'tk_power' => $data['tug_boat_4_tk_power'] ?? '', 'hp_time' => $data['tug_boat_4_hp_time'] ?? '',
         'up_to' => $data['tug_boat_4_up_to'] ?? '']
    ];

    $yStart = 162;
    $yGap = 9;

    foreach ($tugBoats as $idx => $tug) {
        if (!empty($tug['name'])) {
            $y = $yStart + ($idx * $yGap);
            putText($pdf, 20, $y, safeValue($tug['name']), 'helvetica', '', 8);
            putText($pdf, 70, $y, $tug['engine_power'], 'helvetica', '', 8);
            putText($pdf, 105, $y, $tug['tk_power'], 'helvetica', '', 8);
            putText($pdf, 135, $y, $tug['hp_time'], 'helvetica', '', 8);
            putText($pdf, 165, $y, $tug['up_to'], 'helvetica', '', 8);
        }
    }

    // Checkboxes untuk hari kerja (Isikan)
    // Posisi sekitar y=200

    // CATATAN
    $note = "Jam Kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (" .
            ($data['travel_time_minutes'] ?? '......') . " menit).";
    putText($pdf, 20, 268, $note, 'helvetica', '', 7);
    putText($pdf, 20, 273, "Catatlah dibalik bila ada berita/kejadian yang penting untuk diberitahukan", 'helvetica', '', 7);

    // Output PDF
    $safeName = preg_replace('/[^A-Za-z0-9_\-]/', '_', $data['vessel_name'] ?? 'pilot_certificate');
    $filename = "Pilot_Certificate_{$safeName}_" . date('Ymd_His') . ".pdf";
    $pdf->Output($filename, 'I');

    $stmt->close();
    $conn->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
?>