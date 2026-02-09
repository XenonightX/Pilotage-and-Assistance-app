import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class PdfGenerator {
  static Future<File?> generatePemanduanPdf(
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();

    // Load font untuk mendukung bahasa Indonesia
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LAPORAN PEMANDUAN & PENUNDAAN',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'ID: ${data['id']}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Status Badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(data['status']),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Status: ${data['status'] ?? 'Terjadwal'}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
              ),

              pw.SizedBox(height: 24),

              // Data Kapal Section
              _buildSection(
                'DATA KAPAL',
                [
                  _buildRow('Nama Kapal', data['vessel_name'] ?? '-', fontRegular, fontBold),
                  _buildRow('Call Sign', data['call_sign'] ?? '-', fontRegular, fontBold),
                  _buildRow('Nama Master', data['master_name'] ?? '-', fontRegular, fontBold),
                  _buildRow('Bendera', data['flag'] ?? '-', fontRegular, fontBold),
                  _buildRow('Gross Tonnage', data['gross_tonnage']?.toString() ?? '-', fontRegular, fontBold),
                  _buildRow('Keagenan', data['agency'] ?? '-', fontRegular, fontBold),
                  _buildRow('LOA', data['loa'] != null ? '${data['loa']} m' : '-', fontRegular, fontBold),
                  _buildRow('Sarat Muka', data['fore_draft'] != null ? '${data['fore_draft']} m' : '-', fontRegular, fontBold),
                  _buildRow('Sarat Belakang', data['aft_draft'] != null ? '${data['aft_draft']} m' : '-', fontRegular, fontBold),
                ],
                fontBold,
              ),

              pw.SizedBox(height: 20),

              // Informasi Pemanduan Section
              _buildSection(
                'INFORMASI PEMANDUAN',
                [
                  _buildRow('Pandu', data['pilot_name'] ?? '-', fontRegular, fontBold),
                  _buildRow('Arah Pemanduan', '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}', fontRegular, fontBold),
                  _buildRow('Pelabuhan Asal', data['last_port'] ?? '-', fontRegular, fontBold),
                  _buildRow('Pelabuhan Tujuan', data['next_port'] ?? '-', fontRegular, fontBold),
                  _buildRow('Tanggal', _formatDate(data['date']), fontRegular, fontBold),
                  _buildRow('Pandu Naik Kapal', _formatTimeOnly(data['pilot_on_board']), fontRegular, fontBold),
                  _buildRow('Kapal Bergerak', _formatTimeOnly(data['vessel_start']), fontRegular, fontBold),
                  _buildRow('Pandu Selesai', _formatTimeOnly(data['pilot_finished']), fontRegular, fontBold),
                  _buildRow('Pandu Turun', _formatTimeOnly(data['pilot_get_off']), fontRegular, fontBold),
                ],
                fontBold,
              ),

              pw.SizedBox(height: 20),

              // Assist Tug Section
              _buildSection(
                'ASSIST TUG',
                [
                  _buildRow('Nama Assist Tug', _formatMultipleValues(data['assist_tug_name'] ?? '-'), fontRegular, fontBold),
                  _buildRow('Engine Power', _formatMultipleValues(data['engine_power'] ?? '-'), fontRegular, fontBold),
                  _buildRow('Bollard Pull Power', _formatMultipleValues(data['bollard_pull_power'] ?? '-'), fontRegular, fontBold),
                ],
                fontBold,
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Dokumen ini digenerate secara otomatis pada ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    try {
      final output = await _getDownloadPath();
      if (output == null) return null;

      final fileName =
          'Pemanduan_${data['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');

      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      print('Error saving PDF: $e');
      return null;
    }
  }

  static pw.Widget _buildSection(
    String title,
    List<pw.Widget> rows,
    pw.Font fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: rows,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildRow(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 10,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getStatusColor(String? status) {
    switch (status) {
      case 'Aktif':
        return PdfColors.orange;
      case 'Selesai':
        return PdfColors.green;
      case 'Terjadwal':
        return PdfColors.blue;
      default:
        return PdfColors.grey;
    }
  }

  static String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final dt = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return date;
    }
  }

  static String _formatTimeOnly(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateTime);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm (LT)';
    } catch (e) {
      return dateTime;
    }
  }

  static String _formatMultipleValues(String value) {
    if (value.isEmpty || value == '-') return '-';
    final values = value.split(',');
    if (values.length <= 1) return value;
    return values.map((v) => v.trim()).join(', ');
  }

  static Future<Directory?> _getDownloadPath() async {
    Directory? directory;

    try {
      if (Platform.isAndroid) {
        // Request permission
        if (await _requestPermission(Permission.storage) ||
            await _requestPermission(Permission.manageExternalStorage)) {
          directory = Directory('/storage/emulated/0/Download');

          // Jika folder Download tidak ada, gunakan external storage
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      print("Error getting download path: $e");
    }

    return directory;
  }

  static Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      return result == PermissionStatus.granted;
    }
  }

  static Future<void> openPdf(File file) async {
    await OpenFile.open(file.path);
  }

  // Fungsi untuk share PDF
  static Future<void> sharePdf(File file) async {
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.path.split('/').last,
    );
  }
}