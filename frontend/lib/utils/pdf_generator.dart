import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

class PdfGenerator {
  static const String _signatureVerifyBaseUrl = String.fromEnvironment(
    'SIGNATURE_VERIFY_BASE_URL',
  );

  static Future<File?> generatePemanduanPdf(Map<String, dynamic> data) async {
    final formType = _text(data['form_type']).toLowerCase() == 'tunda'
        ? 'tunda'
        : 'pandu';
    final fonts = _PdfFonts();
    final logo = await _loadLogo();
    final pdf = pw.Document(
      title:
          '${formType == 'tunda' ? 'Assistance' : 'Pilot'} Certificate - ${_text(data['vessel_name'])}',
      author: 'PT. SNEPAC INDO SERVICE',
      creator: 'PT. SNEPAC INDO SERVICE',
    );

    if (formType == 'tunda') {
      final tugs = _displayAssistTugs(data);
      for (var i = 0; i < tugs.length; i++) {
        pdf.addPage(_buildAssistancePage(data, tugs[i], i, fonts, logo));
      }
    } else {
      pdf.addPage(_buildPilotPage(data, fonts, logo));
    }

    try {
      final output = await _getDownloadPath();
      if (output == null) return null;

      final fileName = _downloadFilename(data, formType);
      final file = File('${output.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      // Keep the app flow non-fatal if storage is unavailable.
      debugPrint('Error saving PDF: $e');
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/NO-BG-LOGO-SIS.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Page _buildPilotPage(
    Map<String, dynamic> data,
    _PdfFonts fonts,
    pw.MemoryImage? logo,
  ) {
    final id = _id(data);
    final certificateNumber = _certificateNumber(data, 'pandu');
    final requestNumber = _serviceRequestNumber(data);
    final pilotCode = _pick(data, [
      'pilot_code',
      'pilot_license_no',
      'pilot_nip',
      'pilot_identifier',
    ], '-');
    final description = _pick(data, [
      'description',
      'keterangan',
      'remarks',
    ], '-');
    final managerName = _upper('MOHAMMAD ADAM');
    final pilotDisplayName = _upper(data['pilot_name']);
    final masterOrAgency = _upper(_pick(data, ['master_name', 'agency']));
    final signature = _text(data['signature']);

    final managerQr = _qrPayload(
      '2A1',
      id,
      'MANAGER',
      managerName,
      'admin',
      '$managerName|admin|NOSIG',
    );
    final pilotQr = _qrPayload(
      '2A1',
      id,
      'PILOT',
      pilotDisplayName,
      'pilot',
      '$pilotDisplayName|pilot|NOSIG',
    );
    final masterQr = _qrPayload(
      '2A1',
      id,
      'MASTER_AGENT',
      masterOrAgency,
      'external',
      signature.isEmpty ? '$masterOrAgency|NOSIG' : signature,
    );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) {
        final c = <pw.Widget>[];

        _border(c);
        if (logo != null) {
          _image(c, logo, 11, 11, 28, 18);
          _image(c, logo, 171, 11, 24, 15);
        }

        _putText(
          c,
          fonts,
          45,
          13,
          'PEMANDUAN DAN PENUNDAAN',
          style: 'B',
          size: 13,
          align: 'C',
          width: 120,
          height: 5,
        );
        _putText(
          c,
          fonts,
          45,
          20,
          'DAERAH PERAIRAN WAJIB PANDU BATAM',
          style: 'B',
          size: 11.5,
          align: 'C',
          width: 120,
          height: 5,
        );
        _putText(
          c,
          fonts,
          45,
          26,
          'PT. SNEPAC INDO SERVICE',
          size: 8.7,
          align: 'C',
          width: 120,
          height: 4,
        );
        _line(c, 10, 33, 200, 33, 0.35);

        _putText(
          c,
          fonts,
          20,
          36.5,
          'BUKTI PEMAKAIAN JASA PANDU',
          style: 'B',
          size: 12,
          align: 'C',
          width: 170,
          height: 5,
        );
        _putText(
          c,
          fonts,
          20,
          42.2,
          'PILOTAGE SERVICE',
          style: 'I',
          size: 8.7,
          align: 'C',
          width: 170,
          height: 4,
        );
        _putText(
          c,
          fonts,
          20,
          47,
          'Nomor : $certificateNumber',
          size: 8.8,
          align: 'C',
          width: 170,
          height: 4,
        );

        const leftX = 10.0;
        const rightX = 104.0;
        const rowStartY = 54.0;
        const rowGap = 12.5;
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 0),
          'Nama Kapal',
          'Vessel Name',
          _upper(data['vessel_name']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 9.4,
        );
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 1),
          'Nama Nakhoda',
          'Ship Master',
          _upper(data['master_name']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 9.2,
        );
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 2),
          'Bendera',
          'Flag',
          _upper(data['flag']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 9,
        );
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 3),
          'Datang Dari',
          'Last Port of Call',
          _upper(data['last_port']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.7,
        );
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 4),
          'Isi Kotor',
          'G.R.T.',
          _appendUnit(data['gross_tonnage'], 'Ton'),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.9,
        );
        _fieldRow(
          c,
          fonts,
          leftX,
          rowStartY + (rowGap * 5),
          'Panjang',
          'L.O.A',
          _appendUnit(data['loa'], 'm'),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.9,
        );

        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 0),
          'Panggilan',
          'Call Sign',
          _upper(data['call_sign']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 9.2,
        );
        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 1),
          'Keagenan Kapal',
          'Agency',
          _upper(data['agency']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.4,
        );
        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 2),
          'Keterangan',
          'Description',
          _upper(description),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.4,
        );
        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 3),
          'Tujuan Ke',
          'Next Port Of Call',
          _upper(data['next_port']),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.7,
        );
        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 4),
          'Sarat Muka',
          'Fore Draft',
          _appendUnit(data['fore_draft'], 'm'),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.9,
        );
        _fieldRow(
          c,
          fonts,
          rightX,
          rowStartY + (rowGap * 5),
          'Sarat Belakang',
          'Rear Draft',
          _appendUnit(data['aft_draft'], 'm'),
          labelWidth: 28,
          lineWidth: 60,
          valueSize: 8.9,
        );

        const statementY = 132.0;
        _putFitText(
          c,
          fonts,
          10,
          statementY,
          'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA PANDU NO : $requestNumber',
          190,
          size: 9.1,
          style: 'B',
        );
        _putText(
          c,
          fonts,
          10,
          statementY + 4.6,
          'DECLARES THAT IN ACCORDANCE WITH',
          style: 'I',
          size: 7.1,
        );
        _putText(
          c,
          fonts,
          10,
          statementY + 11,
          'IA TELAH DIPANDU OLEH PANDU',
          style: 'B',
          size: 9.2,
        );
        _putText(
          c,
          fonts,
          10,
          statementY + 15.4,
          'SHE HAS BEEN PILOTED BY THE MARINE PILOT',
          style: 'I',
          size: 7,
        );
        _putText(c, fonts, 70, statementY + 12, ':', size: 9.5);
        _line(c, 73, statementY + 19, 150, statementY + 19, 0.15);
        _putFitText(
          c,
          fonts,
          74,
          statementY + 12.2,
          pilotDisplayName,
          74,
          size: 9.4,
        );
        _putText(c, fonts, 155, statementY + 11, 'Kode', size: 8.8);
        _putText(
          c,
          fonts,
          155,
          statementY + 15.4,
          'Code',
          style: 'I',
          size: 6.7,
        );
        _putText(c, fonts, 168.5, statementY + 12, ':', size: 9.5);
        _line(c, 171, statementY + 19, 194, statementY + 19, 0.15);
        _putFitText(
          c,
          fonts,
          172,
          statementY + 12.2,
          _upper(pilotCode),
          20,
          size: 8.8,
        );

        const routeY = 155.5;
        _fieldRow(
          c,
          fonts,
          10,
          routeY,
          'Dari',
          'From',
          _upper(data['from_where']),
          labelWidth: 14,
          lineWidth: 61,
          valueSize: 8.9,
        );
        _fieldRow(
          c,
          fonts,
          104,
          routeY,
          'Ke',
          'To',
          _upper(data['to_where']),
          labelWidth: 10,
          lineWidth: 80,
          valueSize: 8.9,
        );

        const eventY = 169.0;
        _eventRow(
          c,
          fonts,
          10,
          eventY,
          'Pandu Naik Kapal',
          'Pilot On Board',
          data['pilot_on_board'],
        );
        _eventRow(
          c,
          fonts,
          10,
          eventY + 12,
          'Kapal Bergerak',
          'Ship Start',
          data['vessel_start'],
        );
        _eventRow(
          c,
          fonts,
          108,
          eventY,
          'Selesai Pandu',
          'Pilot Finished',
          data['pilot_finished'],
        );
        _eventRow(
          c,
          fonts,
          108,
          eventY + 12,
          'Pandu Turun',
          'Pilot Get Off',
          data['pilot_get_off'],
        );

        const approvalY = 212.0;
        _qrBlock(
          c,
          fonts,
          12,
          approvalY,
          'MANAGER PANDUAN',
          'PILOT MANAGER',
          managerName,
          managerQr,
        );
        _qrBlock(
          c,
          fonts,
          78,
          approvalY,
          'PANDU',
          'MARINE PILOT',
          pilotDisplayName,
          pilotQr,
        );
        _qrBlock(
          c,
          fonts,
          142,
          approvalY,
          'NAKHODA / AGEN',
          'MASTER / AGENT',
          masterOrAgency,
          masterQr,
        );

        const noteY = 268.0;
        _line(c, 10, noteY - 2, 200, noteY - 2, 0.25);
        _putText(c, fonts, 10, noteY, 'CATATAN', style: 'B', size: 7.4);
        _putText(c, fonts, 10, noteY + 3.8, 'NOTE', style: 'I', size: 6.8);
        _putText(
          c,
          fonts,
          24,
          noteY,
          'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______Menit)',
          size: 6.9,
        );
        _putText(
          c,
          fonts,
          24,
          noteY + 3.8,
          'The working of tug boat is the effective used plus the time for moving and the base again.',
          style: 'I',
          size: 6.5,
        );
        _putText(
          c,
          fonts,
          10,
          noteY + 11.2,
          'Catatlah dibalik bila ada berita / kejadian yang penting untuk diberitahukan',
          size: 6.6,
        );
        _putText(
          c,
          fonts,
          10,
          noteY + 15,
          'Please note over leaf if any important / incident to be reported',
          style: 'I',
          size: 6.4,
        );

        return pw.Stack(children: c);
      },
    );
  }

  static pw.Page _buildAssistancePage(
    Map<String, dynamic> data,
    _AssistTug tug,
    int index,
    _PdfFonts fonts,
    pw.MemoryImage? logo,
  ) {
    final id = _id(data);
    final certificateNumber = _certificateNumber(data, 'tunda');
    final requestNumber = _serviceRequestNumber(data);
    final description = _pick(data, [
      'notes',
      'description',
      'keterangan',
    ], '-');
    final serviceDateValue = _pickRaw(data, [
      'date',
      'assistance_start',
      'vessel_start',
      'pilot_on_board',
    ]);
    final startValue = _pickRaw(data, [
      'assistance_start',
      'vessel_start',
      'pilot_on_board',
    ]);
    final endValue = _pickRaw(data, [
      'assistance_end',
      'pilot_finished',
      'pilot_get_off',
    ]);
    final serviceDate = _formatDateValue(serviceDateValue);
    final startTime = _formatTimeValue(startValue);
    var endDate = _formatDateValue(endValue ?? serviceDateValue);
    if (endDate.isEmpty) endDate = serviceDate;
    final endTime = _formatTimeValue(endValue);
    final duration = _formatDurationValue(
      serviceDateValue,
      startValue,
      endValue,
    );
    final managerName = _upper('MOHAMMAD ADAM');
    final tugMasterName = tug.name.isEmpty
        ? _upper('TUG BOAT MASTER')
        : _upper(tug.name);
    final masterAgentName = _upper(_pick(data, ['master_name', 'agency']));
    final signature = _text(data['signature']);

    final managerQr = _qrPayload(
      '2A2',
      id,
      'MANAGER',
      managerName,
      'admin',
      '$managerName|admin|NOSIG',
    );
    final tugQr = _qrPayload(
      '2A2',
      id,
      'TUG_MASTER_${index + 1}',
      tugMasterName,
      'tugboat',
      '$tugMasterName|tugboat|NOSIG',
    );
    final masterAgentQr = _qrPayload(
      '2A2',
      id,
      'MASTER_AGENT',
      masterAgentName,
      'external',
      signature.isEmpty ? '$masterAgentName|NOSIG' : signature,
    );

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) {
        final c = <pw.Widget>[];

        _border(c);
        if (logo != null) {
          _image(c, logo, 11, 12, 30, 18);
        }

        _putText(
          c,
          fonts,
          42,
          14,
          'BUKTI PEMAKAIAN JASA TUNDA',
          style: 'B',
          size: 12,
          align: 'C',
          width: 125,
          height: 5,
        );
        _putText(
          c,
          fonts,
          42,
          20.2,
          'TUG BOAT CERTIFICATE',
          size: 10,
          align: 'C',
          width: 125,
          height: 4,
        );
        _putText(
          c,
          fonts,
          42,
          25.8,
          'Nomor : $certificateNumber',
          size: 8.7,
          align: 'C',
          width: 125,
          height: 4,
        );
        _line(c, 10, 38, 200, 38, 0.35);

        const leftX = 10.0;
        const rightX = 104.0;
        const rowY = 46.0;
        const gap = 10.3;
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 0),
          'Nama Kapal',
          'Vessel Name',
          _upper(data['vessel_name']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.9,
        );
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 1),
          'Nama Nakhoda',
          'Ship Master',
          _upper(data['master_name']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.9,
        );
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 2),
          'Bendera',
          'Flag',
          _upper(data['flag']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.9,
        );
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 3),
          'Datang Dari',
          'Last Port Of Call',
          _upper(data['last_port']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.5,
        );
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 4),
          'Isi Kotor',
          'G.R.T',
          _appendUnit(data['gross_tonnage'], 'Ton'),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.6,
        );
        _fieldRow2(
          c,
          fonts,
          leftX,
          rowY + (gap * 5),
          'Panjang',
          'L.O.A',
          _appendUnit(data['loa'], 'm'),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.6,
        );

        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 0),
          'Panggilan',
          'Call Sign',
          _upper(data['call_sign']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.9,
        );
        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 1),
          'Keagenan Kapal',
          'Agency',
          _upper(data['agency']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.2,
        );
        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 2),
          'Keterangan',
          'Description',
          _upper(description),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.2,
        );
        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 3),
          'Tujuan Ke',
          'Next Port Of Call',
          _upper(data['next_port']),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.5,
        );
        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 4),
          'Sarat Muka',
          'Fore Draft',
          _appendUnit(data['fore_draft'], 'm'),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.6,
        );
        _fieldRow2(
          c,
          fonts,
          rightX,
          rowY + (gap * 5),
          'Sarat Belakang',
          'Rear Draft',
          _appendUnit(data['aft_draft'], 'm'),
          labelWidth: 28,
          lineWidth: 64,
          valueSize: 8.6,
        );

        const statementY = 108.0;
        _putFitText(
          c,
          fonts,
          10,
          statementY,
          'MENERANGKAN BAHWA SESUAI DENGAN PERMOHONAN PELAYANAN JASA TUNDA NO : $requestNumber',
          190,
          size: 9.1,
          style: 'B',
        );
        _fieldRow2(
          c,
          fonts,
          10,
          statementY + 7.2,
          'Dari',
          'From',
          _upper(data['from_where']),
          labelWidth: 14,
          lineWidth: 63,
          valueSize: 8.7,
        );
        _fieldRow2(
          c,
          fonts,
          104,
          statementY + 7.2,
          'Ke',
          'To',
          _upper(data['to_where']),
          labelWidth: 10,
          lineWidth: 64,
          valueSize: 8.7,
        );

        const tugSectionY = 130.0;
        _putText(
          c,
          fonts,
          10,
          tugSectionY,
          'IA TELAH MENGGUNAKAN KAPAL TUNDA',
          style: 'B',
          size: 9.4,
        );
        _putText(
          c,
          fonts,
          10,
          tugSectionY + 4.4,
          'SHE DULY USED THE TUG BOAT',
          style: 'I',
          size: 6.8,
        );
        _tugRow(
          c,
          fonts,
          140,
          tug,
          serviceDate,
          startTime,
          endDate,
          endTime,
          duration,
        );

        _qrBlock(
          c,
          fonts,
          12,
          212,
          'MANAGER PEMANDUAN',
          'PILOT MANAGER',
          managerName,
          managerQr,
          width: 52,
        );
        _qrBlock(
          c,
          fonts,
          76,
          212,
          'NAHKODA KAPAL TUNDA',
          'TUG BOAT MASTER',
          tugMasterName,
          tugQr,
          width: 52,
        );
        _qrBlock(
          c,
          fonts,
          140,
          212,
          'MASTER/ AGENT',
          'NAKHODA / AGEN',
          masterAgentName,
          masterAgentQr,
          width: 52,
        );

        const footerY = 283.0;
        _line(c, 10, footerY - 2.5, 200, footerY - 2.5, 0.22);
        _putText(c, fonts, 10, footerY, 'CATATAN', style: 'B', size: 7.2);
        _putText(c, fonts, 10, footerY + 3.4, 'NOTE :', style: 'B', size: 7);
        _putText(
          c,
          fonts,
          27,
          footerY,
          'Jam kerja Tug Boat dihitung selama pemakaian efektif ditambah waktu perjalanan dari dan ke pangkalan (______ Menit)',
          size: 6.2,
        );
        _putText(
          c,
          fonts,
          27,
          footerY + 4,
          'The work time of tug boat is the effective use plus the time for moving and the base again.',
          style: 'I',
          size: 5.9,
        );

        return pw.Stack(children: c);
      },
    );
  }

  static void _tugRow(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double y,
    _AssistTug tug,
    String serviceDate,
    String startTime,
    String endDate,
    String endTime,
    String duration,
  ) {
    _fieldRow2(
      c,
      fonts,
      10,
      y,
      'Nama',
      'Name',
      _upper(tug.name),
      labelWidth: 28,
      lineWidth: 64,
      valueSize: 8.9,
    );
    _fieldRow2(
      c,
      fonts,
      104,
      y,
      'Tenaga',
      'Engine Power',
      tug.power,
      labelWidth: 28,
      lineWidth: 22,
      valueSize: 8.5,
    );
    _fieldRow2(
      c,
      fonts,
      156,
      y,
      'Durasi',
      'Duration',
      duration,
      labelWidth: 16,
      lineWidth: 24,
      valueSize: 8.4,
    );
    _fieldRow2(
      c,
      fonts,
      10,
      y + 12,
      'Mulai Tunda',
      'Tug Start',
      serviceDate,
      labelWidth: 28,
      lineWidth: 22,
      valueSize: 8.4,
    );
    _fieldRow2(
      c,
      fonts,
      66,
      y + 12,
      'Pukul',
      'Time',
      startTime,
      labelWidth: 12,
      lineWidth: 28,
      valueSize: 8.4,
    );
    _fieldRow2(
      c,
      fonts,
      104,
      y + 12,
      'Selesai Tunda',
      'Tug End',
      endDate,
      labelWidth: 28,
      lineWidth: 22,
      valueSize: 8.4,
    );
    _fieldRow2(
      c,
      fonts,
      156,
      y + 12,
      'Pukul',
      'Time',
      endTime,
      labelWidth: 12,
      lineWidth: 24,
      valueSize: 8.4,
    );
  }

  static void _fieldRow(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String labelId,
    String labelEn,
    String value, {
    double labelWidth = 31,
    double lineWidth = 63,
    double valueSize = 9,
  }) {
    _putText(c, fonts, x, y, labelId, size: 7.9);
    _putText(c, fonts, x, y + 4.1, labelEn, style: 'I', size: 6.7);
    _putText(c, fonts, x + labelWidth, y + 0.8, ':', size: 9);
    final valueX = x + labelWidth + 3.5;
    _line(c, valueX, y + 8, valueX + lineWidth, y + 8, 0.15);
    _putFitText(c, fonts, valueX, y + 1, value, lineWidth - 1, size: valueSize);
  }

  static void _fieldRow2(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String labelId,
    String labelEn,
    String value, {
    double labelWidth = 28,
    double lineWidth = 64,
    double valueSize = 8.9,
  }) {
    _putText(c, fonts, x, y, labelId, size: 8.6);
    _putText(c, fonts, x, y + 4, labelEn, style: 'I', size: 6.5);
    _putText(c, fonts, x + labelWidth, y + 0.5, ':', size: 9);
    final valueX = x + labelWidth + 3;
    _line(c, valueX, y + 7.6, valueX + lineWidth, y + 7.6, 0.15);
    _putFitText(
      c,
      fonts,
      valueX + 0.8,
      y + 0.8,
      value,
      lineWidth - 1.6,
      size: valueSize,
    );
  }

  static void _eventRow(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String labelId,
    String labelEn,
    dynamic dateTimeValue,
  ) {
    final dateText = _formatDateValue(dateTimeValue);
    final timeText = _formatTimeValue(dateTimeValue);

    _putText(c, fonts, x, y, labelId, size: 8.7);
    _putText(c, fonts, x, y + 4, labelEn, style: 'I', size: 6.7);
    _putText(c, fonts, x + 29.5, y + 1, ':', size: 9);
    _line(c, x + 32, y + 8.1, x + 56.5, y + 8.1, 0.15);
    _putFitText(c, fonts, x + 33, y + 1.1, dateText, 22.5, size: 8.3);
    _putText(c, fonts, x + 57.5, y, 'Pukul', size: 8.3);
    _putText(c, fonts, x + 57.5, y + 4, 'Time', style: 'I', size: 6.5);
    _putText(c, fonts, x + 72, y + 1, ':', size: 9);
    _line(c, x + 74.5, y + 8.1, x + 91.5, y + 8.1, 0.15);
    _putFitText(c, fonts, x + 75.5, y + 1.1, timeText, 14.5, size: 8.3);
  }

  static void _qrBlock(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String titleId,
    String titleEn,
    String name,
    String payload, {
    double width = 54,
  }) {
    final qrX = x + (width == 52 ? 15 : 16);
    _putText(
      c,
      fonts,
      x,
      y,
      titleId,
      style: 'B',
      size: width == 52 ? 8.9 : 9.2,
      align: 'C',
      width: width,
    );
    _putText(
      c,
      fonts,
      x,
      y + 4.5,
      titleEn,
      style: 'I',
      size: width == 52 ? 6.5 : 6.7,
      align: 'C',
      width: width,
    );
    c.add(
      pw.Positioned(
        left: _mm(qrX),
        top: _mm(y + 10),
        child: pw.SizedBox(
          width: _mm(22),
          height: _mm(22),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(
              errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high,
            ),
            data: payload,
            drawText: false,
          ),
        ),
      ),
    );
    _putText(
      c,
      fonts,
      x,
      y + 36,
      'NAMA / NAME',
      style: 'B',
      size: 7.1,
      align: 'C',
      width: width,
    );
    _line(
      c,
      x + (width == 52 ? 1 : 2),
      y + 42,
      x + width - (width == 52 ? 1 : 2),
      y + 42,
      0.2,
    );
    _putFitText(
      c,
      fonts,
      x + 2,
      y + 43,
      name,
      width - 4,
      size: 8.1,
      align: 'C',
    );
  }

  static void _border(List<pw.Widget> c) {
    c.add(
      pw.Positioned(
        left: _mm(5),
        top: _mm(5),
        child: pw.Container(
          width: _mm(200),
          height: _mm(287),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: const PdfColor.fromInt(0xff282828),
              width: _mm(0.35),
            ),
          ),
        ),
      ),
    );
  }

  static void _image(
    List<pw.Widget> c,
    pw.MemoryImage image,
    double x,
    double y,
    double w,
    double h,
  ) {
    c.add(
      pw.Positioned(
        left: _mm(x),
        top: _mm(y),
        child: pw.Image(
          image,
          width: _mm(w),
          height: _mm(h),
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }

  static void _line(
    List<pw.Widget> c,
    double x1,
    double y1,
    double x2,
    double y2,
    double width,
  ) {
    if ((y2 - y1).abs() > 0.01) return;
    c.add(
      pw.Positioned(
        left: _mm(x1),
        top: _mm(y1),
        child: pw.Container(
          width: _mm(x2 - x1),
          height: _mm(width),
          color: const PdfColor.fromInt(0xff282828),
        ),
      ),
    );
  }

  static void _putText(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String text, {
    String style = '',
    double size = 9,
    String align = 'L',
    double width = 0,
    double height = 4,
  }) {
    final child = pw.Container(
      width: width > 0 ? _mm(width) : null,
      height: _mm(height),
      alignment: _alignment(align),
      child: pw.Text(
        _text(text),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        textAlign: _textAlign(align),
        style: pw.TextStyle(font: fonts.byStyle(style), fontSize: size),
      ),
    );
    c.add(pw.Positioned(left: _mm(x), top: _mm(y), child: child));
  }

  static void _putFitText(
    List<pw.Widget> c,
    _PdfFonts fonts,
    double x,
    double y,
    String text,
    double maxWidth, {
    double size = 9,
    String style = '',
    String align = 'L',
    double height = 4,
  }) {
    final value = _text(text);
    if (value.isEmpty) return;
    c.add(
      pw.Positioned(
        left: _mm(x),
        top: _mm(y),
        child: pw.Container(
          width: _mm(maxWidth),
          height: _mm(height),
          alignment: _alignment(align),
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: _alignment(align),
            child: pw.Text(
              value,
              maxLines: 1,
              textAlign: _textAlign(align),
              style: pw.TextStyle(font: fonts.byStyle(style), fontSize: size),
            ),
          ),
        ),
      ),
    );
  }

  static pw.Alignment _alignment(String align) {
    switch (align) {
      case 'C':
        return pw.Alignment.center;
      case 'R':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  static pw.TextAlign _textAlign(String align) {
    switch (align) {
      case 'C':
        return pw.TextAlign.center;
      case 'R':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

  static List<_AssistTug> _displayAssistTugs(Map<String, dynamic> data) {
    final names = <String>[];
    final powers = <String>[];

    for (var i = 1; i <= 3; i++) {
      final name = _pick(data, ['assist_tug_name_$i']);
      final power = _pick(data, ['engine_power_$i']);
      if (name.isNotEmpty || power.isNotEmpty) {
        names.add(name);
        powers.add(power);
      }
    }

    if (names.isEmpty) {
      names.addAll(_parseDelimitedValues(data['assist_tug_name']));
      powers.addAll(_parseDelimitedValues(data['engine_power']));
    }

    if (names.isEmpty) names.add('');

    final rows = <_AssistTug>[];
    for (var i = 0; i < names.length && i < 3; i++) {
      final power = i < powers.length
          ? powers[i]
          : (powers.isNotEmpty ? powers[0] : '');
      rows.add(_AssistTug(_upper(names[i]), _appendUnit(power, 'PS')));
    }

    final display = rows
        .where((tug) => tug.name.isNotEmpty || tug.power.isNotEmpty)
        .toList();
    return display.isEmpty ? [rows.first] : display;
  }

  static List<String> _parseDelimitedValues(dynamic value) {
    final text = _text(value);
    if (text.isEmpty) return [];
    return text
        .split(RegExp(r'\s*(?:/|,)\s*'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _certificateNumber(Map<String, dynamic> data, String type) {
    final prefix = type == 'tunda' ? 'TUNDA' : 'PANDU';
    final typedExisting = _pick(
      data,
      type == 'tunda'
          ? ['tug_certificate_no', 'tunda_certificate_no']
          : ['pilot_certificate_no', 'pandu_certificate_no'],
    );
    if (_isBktNumber(typedExisting)) {
      return _normalizeCertificateType(typedExisting, prefix);
    }

    final existing = _pick(data, [
      'certificate_no',
      'document_no',
      'doc_no',
      'activity_no',
      'id',
    ]);
    if (_isBktNumber(existing)) {
      return _normalizeCertificateType(existing, prefix);
    }

    final ym = _yearMonth(
      _pickRaw(data, ['date', 'created_at']) ?? DateTime.now(),
    );
    return 'BKT/$prefix/IDBTM/SIS/$ym/${_id(data).toString().padLeft(4, '0')}';
  }

  static String _downloadFilename(Map<String, dynamic> data, String type) {
    final stem = _certificateNumber(data, type)
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$stem.pdf';
  }

  static String _serviceRequestNumber(Map<String, dynamic> data) {
    final existing = _pick(data, [
      'request_no',
      'service_request_no',
      'permohonan_no',
      'job_order_no',
    ]);
    if (existing.isNotEmpty) return existing;
    final dt =
        _toDateTime(_pickRaw(data, ['date', 'created_at'])) ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d${_id(data).toString().padLeft(4, '0')}';
  }

  static String _qrPayload(
    String documentType,
    int documentId,
    String slot,
    String name,
    String role,
    String source,
  ) {
    final normalizedSource = _text(source).isEmpty
        ? '$name|$role|NOSIG'
        : source;
    final hash = sha256
        .convert(utf8.encode(normalizedSource))
        .toString()
        .substring(0, 20);
    final baseUrl = _signatureVerifyBaseUrl.trim();
    if (baseUrl.isNotEmpty) {
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final query = Uri(
        queryParameters: {
          'd': documentType,
          'i': documentId.toString(),
          's': slot,
          'k': hash,
        },
      ).query;
      return '$normalizedBase/api/verify_signature.php?$query';
    }
    return 'SIG|$documentType|$documentId|$slot|$hash';
  }

  static String _yearMonth(dynamic value) {
    final dt = _toDateTime(value) ?? DateTime.now();
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$yy$mm';
  }

  static String _formatDateValue(dynamic value) {
    final dt = _toDateTime(value);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year.toString().padLeft(4, '0')}';
  }

  static String _formatTimeValue(dynamic value) {
    if (value == null) return '';
    final dt = _toDateTime(value);
    if (dt != null) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(_text(value));
    if (match == null) return '';
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }

  static String _formatDurationValue(
    dynamic dateValue,
    dynamic startValue,
    dynamic endValue,
  ) {
    final start = _combineDateTimeForDuration(dateValue, startValue);
    final end = _combineDateTimeForDuration(dateValue, endValue);
    if (start == null || end == null || end.isBefore(start)) return '';
    final minutes = end.difference(start).inMinutes.round();
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }

  static DateTime? _combineDateTimeForDuration(
    dynamic dateValue,
    dynamic timeValue,
  ) {
    final direct = _toDateTime(timeValue);
    if (direct != null) return direct;

    final date = _toDateTime(dateValue);
    final timeMatch = RegExp(
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(_text(timeValue));
    if (date == null || timeMatch == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
      int.tryParse(timeMatch.group(3) ?? '0') ?? 0,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final text = _text(value);
    if (text.isEmpty || text == '0000-00-00' || text == '0000-00-00 00:00:00') {
      return null;
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final dateMatch = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(text);
    if (dateMatch != null) {
      return DateTime(
        int.parse(dateMatch.group(3)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(1)!),
      );
    }
    return null;
  }

  static dynamic _pickRaw(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = data[key];
      if (_text(value).isNotEmpty || value is DateTime || value is Timestamp) {
        return value;
      }
    }
    return null;
  }

  static String _pick(
    Map<String, dynamic> data,
    List<String> keys, [
    String defaultValue = '',
  ]) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = _text(data[key]);
      if (value.isNotEmpty) return value;
    }
    return defaultValue;
  }

  static String _appendUnit(dynamic value, String unit) {
    final text = _text(value);
    if (text.isEmpty) return '';
    if (text.toLowerCase().contains(unit.toLowerCase())) return text;
    return '$text $unit';
  }

  static String _upper(dynamic value) => _text(value).toUpperCase();

  static String _text(dynamic value) {
    if (value == null) return '';
    final normalized = value.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized == '-' ? '' : normalized;
  }

  static int _id(Map<String, dynamic> data) {
    for (final key in [
      'sequence_no',
      'activity_sequence',
      'certificate_sequence',
      'legacy_id',
    ]) {
      final sequence = _positiveInt(data[key]);
      if (sequence != null) return sequence;
    }

    final number = _pick(data, [
      'certificate_no',
      'document_no',
      'doc_no',
      'activity_no',
      'pilot_certificate_no',
      'pandu_certificate_no',
      'tug_certificate_no',
      'tunda_certificate_no',
      'id',
    ]);
    final numberMatch = RegExp(r'/(\d{1,})$').firstMatch(number);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!) ?? 1;
    }

    return _positiveInt(data['id']) ?? 1;
  }

  static bool _isBktNumber(String value) {
    return RegExp(
      r'^BKT/(?:PANDU|TUNDA)/IDBTM/SIS/\d{4}/\d+$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static String _normalizeCertificateType(String value, String type) {
    final match = RegExp(
      r'^BKT/(?:PANDU|TUNDA)/IDBTM/SIS/(\d{4})/(\d+)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return value;

    final sequence = int.tryParse(match.group(2)!) ?? 1;
    return 'BKT/$type/IDBTM/SIS/${match.group(1)!}/${sequence.toString().padLeft(4, '0')}';
  }

  static int? _positiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(_text(value));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static double _mm(double value) => value * PdfPageFormat.mm;

  static Future<Directory?> _getDownloadPath() async {
    Directory? directory;

    try {
      if (Platform.isAndroid) {
        if (await _requestPermission(Permission.storage) ||
            await _requestPermission(Permission.manageExternalStorage)) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        }

        directory ??= await getExternalStorageDirectory();
        directory ??= await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error getting download path: $e');
    }

    return directory;
  }

  static Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) return true;
    final result = await permission.request();
    return result == PermissionStatus.granted;
  }

  static Future<void> openPdf(File file) async {
    await OpenFile.open(file.path);
  }

  static Future<void> sharePdf(File file) async {
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: file.path.split(RegExp(r'[\\/]')).last,
    );
  }
}

class _PdfFonts {
  final regular = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final italic = pw.Font.helveticaOblique();
  final boldItalic = pw.Font.helveticaBoldOblique();

  pw.Font byStyle(String style) {
    final isBold = style.contains('B');
    final isItalic = style.contains('I');
    if (isBold && isItalic) return boldItalic;
    if (isBold) return bold;
    if (isItalic) return italic;
    return regular;
  }
}

class _AssistTug {
  const _AssistTug(this.name, this.power);

  final String name;
  final String power;
}
