<?php
// ✅ Autoload TCPDF dari vendor
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
    $pilotageId = $_GET['id'] ?? null;
    
    if (!$pilotageId) {
        throw new Exception("ID pilotage tidak ditemukan");
    }

    // Query data dari database
    $sql = "SELECT * FROM pilotage_logs WHERE id = ?";
    
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $pilotageId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception("Data tidak ditemukan");
    }
    
    $data = $result->fetch_assoc();

    // ✅ Create PDF
    $pdf = new TCPDF('P', 'mm', 'A4', true, 'UTF-8', false);
    
    // Set document info
    $pdf->SetCreator('PT. SNEPAC INDO SERVICE');
    $pdf->SetAuthor('PT. SNEPAC INDO SERVICE');
    $pdf->SetTitle('Pilot Certificate - ' . $data['vessel_name']);
    
    // Remove header/footer
    $pdf->setPrintHeader(false);
    $pdf->setPrintFooter(false);
    
    // Set margins
    $pdf->SetMargins(15, 15, 15);
    $pdf->SetAutoPageBreak(true, 15);
    
    // Add page
    $pdf->AddPage();
    
    // ===== HEADER DENGAN LOGO =====
    // Logo kiri
    // $pdf->Image('path/to/snepac_logo.png', 15, 10, 35, 0, 'PNG');
    
    $pdf->SetFont('helvetica', 'B', 18);
    $pdf->SetXY(55, 12);
    $pdf->Cell(0, 7, 'PT. SNEPAC INDO SERVICE', 0, 1);
    
    $pdf->SetFont('helvetica', '', 10);
    $pdf->SetX(55);
    $pdf->Cell(0, 5, 'Badan Usaha Pelabuhan', 0, 1);
    
    // Document number (top right)
    $pdf->SetFont('helvetica', '', 9);
    $pdf->SetXY(155, 12);
    $pdf->Cell(0, 5, '/ BTM-2025', 0, 1, 'L');
    $pdf->SetX(155);
    $pdf->Cell(0, 5, '6501-3462', 0, 1, 'L');
    
    $pdf->SetY(32);
    
    // Title
    $pdf->SetFont('helvetica', 'BU', 13);
    $pdf->Cell(0, 7, 'BUKTI PEMAKAIAN JASA PANDU', 0, 1, 'C');
    
    $pdf->SetFont('helvetica', 'B', 12);
    $pdf->Cell(0, 6, 'PILOT CERTIFICATE', 0, 1, 'C');
    
    $pdf->Ln(3);
    
    // Subtitle
    $pdf->SetFont('helvetica', '', 8);
    $pdf->MultiCell(0, 4, 
        "Untuk melaksanakan Pemanduan/Penundaan terhadap kapal tersebut di bawah ini :\n" .
        "To perform Pilotage / Towege for the ship below", 
        0, 'L'
    );
    
    $pdf->Ln(2);
    
    // ===== DATA KAPAL (2 KOLOM) =====
    $pdf->SetFont('helvetica', '', 8);
    
    $leftX = 15;
    $rightX = 115;
    $startY = $pdf->GetY();
    $lineHeight = 4.5;
    
    // === KOLOM KIRI ===
    $pdf->SetXY($leftX, $startY);
    
    // Nama Kapal
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Nama Kapal', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['vessel_name'], 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Vessel', 0, 1);
    
    // Nama Nahkoda
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Nama Nahkoda', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . ($data['master_name'] ?? '-'), 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Master Name', 0, 1);
    
    // Bendera
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Bendera', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['flag'], 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Flag', 0, 1);
    
    // Datang Dari
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Datang Dari', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['last_port'], 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Last Port of Call', 0, 1);
    
    // Isi Kotor / GT
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Isi Kotor', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['gross_tonnage'], 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'GT', 0, 1);
    
    // Keagenan
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Keagenan Kapal', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['agency'], 0, 1);
    
    $pdf->SetX($leftX);
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Agency', 0, 1);
    
    // === KOLOM KANAN ===
    $pdf->SetXY($rightX, $startY);
    
    // Nama Panggilan
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Nama Panggilan', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . ($data['call_sign'] ?? '-'), 0, 1);
    
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Call Sign', 0, 1);
    
    // Tujuan Ke
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Tujuan Ke', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['next_port'], 0, 1);
    
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Next Port of Call', 0, 1);
    
    // Panjang / LOA
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Panjang', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . $data['loa'] . ' m', 0, 1);
    
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'LOA', 0, 1);
    
    // Sarat Muka
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Sarat Muka', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . ($data['fore_draft'] ?? '-') . ' m', 0, 1);
    
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Fore Draft', 0, 1);
    
    // Sarat Belakang
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(25, $lineHeight, 'Sarat Belakang', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, $lineHeight, ': ' . ($data['aft_draft'] ?? '-') . ' m', 0, 1);
    
    $pdf->SetXY($rightX, $pdf->GetY());
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(25, $lineHeight, 'Aft Draft', 0, 1);
    
    $pdf->Ln(3);
    
    // ===== TANGGAL & JAM BERLABUH =====
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(60, 5, 'Tanggal & Jam Berlabuh Di Luar Dam/Ambang', 0, 0);
    $pdf->SetFont('helvetica', '', 8);
    
    $tanggal = date('d-m-Y', strtotime($data['date']));
    $waktu = date('H:i', strtotime($data['pilot_on_board']));
    
    $pdf->Cell(20, 5, 'Tanggal', 0, 0);
    $pdf->Cell(30, 5, ': ' . $tanggal, 'B', 0);
    $pdf->Cell(15, 5, 'Pukul', 0, 0);
    $pdf->Cell(20, 5, ': ' . $waktu, 'B', 1);
    
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(60, 4, 'Anchor Time / Outer Bar', 0, 0);
    $pdf->Cell(20, 4, 'Date', 0, 0);
    $pdf->Cell(30, 4, '', 0, 0);
    $pdf->Cell(15, 4, 'Hour', 0, 1);
    
    $pdf->Ln(2);
    
    // ===== MENERANGKAN BAHWA =====
    $pdf->SetFont('helvetica', 'B', 9);
    $pdf->Cell(0, 5, 'MENERANGKAN BAHWA', 0, 1);
    $pdf->Cell(0, 5, 'D E C L A R E S T H A T', 0, 1);
    
    $pdf->Ln(2);
    
    // Info Pemanduan
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(0, 5, 'IA TELAH DIPANDU OLEH NAMA PANDU', 0, 1);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, 5, 'SHE HAS BEEN DULY PILOTED BY THE HARBOUR PILOT :', 0, 1);
    
    $pdf->Cell(15, 5, 'Dari', 0, 0);
    $pdf->Cell(50, 5, ': ' . $data['from_where'], 0, 0);
    $pdf->Cell(10, 5, 'Ke', 0, 0);
    $pdf->Cell(0, 5, ': ' . $data['to_where'], 0, 1);
    
    $pdf->Cell(15, 5, 'From', 0, 0);
    $pdf->Cell(50, 5, '', 0, 0);
    $pdf->Cell(10, 5, 'To', 0, 1);
    
    $pdf->Ln(1);
    
    // Pandu naik/turun kapal
    $pdf->Cell(35, 5, 'Pandu naik ke Kapal', 0, 0);
    $pdf->Cell(30, 5, ': ' . $waktu, 0, 0);
    $pdf->Cell(25, 5, 'Pada Tanggal', 0, 0);
    $pdf->Cell(0, 5, ': ' . $tanggal, 0, 1);
    
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(35, 4, 'Pilot On Boat', 0, 0);
    $pdf->Cell(30, 4, '', 0, 0);
    $pdf->Cell(25, 4, 'On Date', 0, 1);
    
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(35, 5, 'Selesai di Pandu', 0, 0);
    $pdf->Cell(30, 5, ': -', 0, 0);
    $pdf->Cell(25, 5, 'Kapal Bergerak', 0, 0);
    $pdf->Cell(0, 5, ': -', 0, 1);
    
    $pdf->SetFont('helvetica', '', 7);
    $pdf->Cell(35, 4, 'Pilot Finished', 0, 0);
    $pdf->Cell(30, 4, '', 0, 0);
    $pdf->Cell(25, 4, 'Ship Start', 0, 1);
    
    $pdf->Ln(2);
    
    // ===== UNIT KAPAL (jika ada) =====
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(0, 5, 'IA TELAH MENGGUNAKAN UNIT KAPAL', 0, 1);
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(0, 5, 'SHE DULY EMPLOYED MOORING/UNIT', 0, 1);
    
    $pdf->Ln(8);
    
    // ===== TANDA TANGAN =====
    $pdf->SetFont('helvetica', '', 8);
    
    $pdf->Cell(95, 5, 'MENGETAHUI', 0, 0, 'C');
    $pdf->Cell(95, 5, 'PADA TANGGAL', 0, 1, 'C');
    
    $pdf->Cell(95, 5, 'ASISTEN MENEJER BISNIS', 0, 0, 'C');
    $pdf->Cell(95, 5, 'ON DATE', 0, 1, 'C');
    
    $pdf->Ln(20);
    
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Cell(95, 5, '__________________________', 0, 0, 'C');
    $pdf->Cell(95, 5, '__________________________', 0, 1, 'C');
    
    $pdf->Cell(95, 5, 'PANDU LAUT/ BANDAR', 0, 0, 'C');
    $pdf->Cell(95, 5, 'NAKHODA/AGEN', 0, 1, 'C');
    
    $pdf->SetFont('helvetica', '', 8);
    $pdf->Cell(95, 5, '', 0, 0, 'C');
    $pdf->Cell(95, 5, 'MASTER', 0, 1, 'C');
    
    $pdf->Ln(5);
    
    // ===== CATATAN =====
    $pdf->SetFont('helvetica', 'B', 7);
    $pdf->Cell(0, 4, 'CATATAN', 0, 1);
    
    $pdf->SetFont('helvetica', '', 6);
    $noteText = "Jam Kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan kepangkalan (.................menit)\n";
    $noteText .= "The Work time of Tug Boat is the Effective used plus the time for moving and the base again.\n";
    $noteText .= "Catatan dibalik bila ada berita/kejadian yang penting untuk diberitahukan\n";
    $noteText .= "Please note overleaf if any important/incident to be reported";
    
    $pdf->MultiCell(0, 3, $noteText, 0, 'L');
    
    $pdf->Ln(2);
    $pdf->SetFont('helvetica', 'B', 8);
    $pdf->Rect(15, $pdf->GetY(), 25, 6);
    $pdf->Cell(25, 6, 'Bentuk : 2A - I', 0, 1, 'C');
    
    // Output PDF
    $filename = 'Pilot_Certificate_' . preg_replace('/[^A-Za-z0-9_\-]/', '_', $data['vessel_name']) . '_' . date('Ymd') . '.pdf';
    $pdf->Output($filename, 'I');
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}