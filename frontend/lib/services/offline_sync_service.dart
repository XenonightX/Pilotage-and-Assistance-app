import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const _boxName = 'pending_add_operations';

  Box? _box;
  StreamSubscription? _connectivitySub;
  bool _isProcessing = false;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;
  int get pendingCount => _box?.length ?? 0;

  // ─────────────────────────────────────────────────────────────────
  // Inisialisasi
  // ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _pendingCountController.add(_box!.length);

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    await _tryProcessQueue();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
  }

  // ─────────────────────────────────────────────────────────────────
  // Cek koneksi
  // ─────────────────────────────────────────────────────────────────
  static Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) _tryProcessQueue();
  }

  // ─────────────────────────────────────────────────────────────────
  // Tambah ke antrian — pakai timestamp sebagai key agar mudah diupdate
  // ─────────────────────────────────────────────────────────────────
  Future<void> enqueue(Map<String, dynamic> data) async {
    if (_box == null) return;

    final pendingId = DateTime.now().millisecondsSinceEpoch.toString();
    final serializable = _toJson(data);
    await _box!.put(pendingId, json.encode(serializable));
    _pendingCountController.add(_box!.length);
  }

  // ─────────────────────────────────────────────────────────────────
  // Ambil semua item pending (untuk ditampilkan di list kegiatan)
  // ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> getPendingItems() {
    if (_box == null || _box!.isEmpty) return [];

    final items = <Map<String, dynamic>>[];
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw == null) continue;
      try {
        final stored = Map<String, dynamic>.from(
          json.decode(raw as String) as Map,
        );
        final displayData = _fromJsonForDisplay(stored);

        // Tambah marker khusus agar UI tahu ini item pending
        displayData['_is_pending'] = true;
        displayData['_pending_id'] = key.toString();
        displayData['_doc_id'] = 'pending_$key';
        displayData['doc_id'] = 'pending_$key';
        displayData['id'] =
            'PENDING-${key.toString().substring(key.toString().length - 4)}';
        displayData['status'] = displayData['status'] ?? 'Terjadwal';
        displayData['_has_pending_writes'] = true;

        items.add(displayData);
      } catch (_) {
        // skip entri rusak
      }
    }
    return items;
  }

  // ─────────────────────────────────────────────────────────────────
  // Update item pending yang sudah ada di Hive
  // ─────────────────────────────────────────────────────────────────
// SESUDAH ✅
Future<void> updatePending(
  String pendingId,
  Map<String, dynamic> data,
) async {
  if (_box == null) return;

  // Ambil data lama dulu, supaya field yang tidak ada di form edit
  // (misal: date, created_at) tidak hilang saat disimpan ulang
  final existingRaw = _box!.get(pendingId);
  final existing = existingRaw != null
      ? Map<String, dynamic>.from(json.decode(existingRaw as String) as Map)
      : <String, dynamic>{};

  final cleaned = Map<String, dynamic>.from(data)
    ..remove('_is_pending')
    ..remove('_pending_id')
    ..remove('_doc_id')
    ..remove('doc_id')
    ..remove('id')
    ..remove('_has_pending_writes');

  // Merge: data lama jadi dasar, ditimpa oleh field baru yang diedit
  final merged = {...existing, ..._toJson(cleaned)};

  await _box!.put(pendingId, json.encode(merged));
  _pendingCountController.add(_box!.length);
}

  // ─────────────────────────────────────────────────────────────────
  // Proses antrian saat online
  // ─────────────────────────────────────────────────────────────────
  Future<void> _tryProcessQueue() async {
    if (_isProcessing || _box == null || _box!.isEmpty) return;
    if (!await isOnline) return;

    _isProcessing = true;
    try {
      final keys = _box!.keys.toList();
      for (final key in keys) {
        final raw = _box!.get(key);
        if (raw == null) continue;

        try {
          final data = Map<String, dynamic>.from(
            json.decode(raw as String) as Map,
          );
          await _addToFirestore(data);
          await _box!.delete(key);
          _pendingCountController.add(_box!.length);
        } catch (_) {
          break; // masih offline atau error — coba lagi nanti
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Kirim ke Firestore (sama logika dengan FirestoreDataService)
  // ─────────────────────────────────────────────────────────────────
// SESUDAH ✅
Future<void> _addToFirestore(Map<String, dynamic> data) async {
  final firestore = FirebaseFirestore.instance;
  final activityLogs = firestore.collection('activity_logs');
  final counters = firestore.collection('counters');
  final doc = activityLogs.doc();

  final yearMonth = _activityYearMonth(data);
  final counterRef = counters.doc('activity_$yearMonth');

  // Bersihkan field internal dan konversi type markers sebelum ke Firestore
  final cleanData = _cleanForFirestore(
    Map<String, dynamic>.from(data)
      ..remove('_is_pending')
      ..remove('_pending_id')
      ..remove('_doc_id')
      ..remove('doc_id')
      ..remove('_has_pending_writes')
      ..remove('synced_from_offline'),
  );

  await firestore.runTransaction((transaction) async {
    final counterSnapshot = await transaction.get(counterRef);
    final nextSequence =
        (_toPositiveInt(counterSnapshot.data()?['last_sequence']) ?? 0) + 1;

    final panduNumber = _buildActivityNumber('PANDU', yearMonth, nextSequence);
    final tundaNumber = _buildActivityNumber('TUNDA', yearMonth, nextSequence);

    transaction.set(counterRef, {
      'last_sequence': nextSequence,
      'sequence_year_month': yearMonth,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    transaction.set(doc, {
      ...cleanData,
      'id': panduNumber,
      'activity_no': panduNumber,
      'document_no': panduNumber,
      'pilot_certificate_no': panduNumber,
      'tug_certificate_no': tundaNumber,
      'sequence_no': nextSequence,
      'sequence_year_month': yearMonth,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'client_created_at': DateTime.now().toIso8601String(),
      'client_updated_at': DateTime.now().toIso8601String(),
      'synced_from_offline': true,
    });
  });
}

// Tambah method baru ini di bawah _fromJsonForDisplay:
/// Bersihkan data dari type marker JSON sebelum dikirim ke Firestore
Map<String, dynamic> _cleanForFirestore(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    final value = entry.value;
    if (value is Map && value['__type'] == 'serverTimestamp') {
      // Gunakan nilai fallback sebagai string biasa
      result[entry.key] = value['fallback'];
    } else if (value is Map<String, dynamic>) {
      result[entry.key] = _cleanForFirestore(value);
    } else {
      result[entry.key] = value;
    }
  }
  return result;
}

  // ─────────────────────────────────────────────────────────────────
  // Serialisasi / deserialisasi FieldValue
  // ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> _toJson(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is FieldValue) {
        result[entry.key] = {
          '__type': 'serverTimestamp',
          'fallback': DateTime.now().toIso8601String(),
        };
      } else if (value is Map<String, dynamic>) {
        result[entry.key] = _toJson(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  /// Konversi JSON kembali ke nilai yang bisa ditampilkan di UI
  Map<String, dynamic> _fromJsonForDisplay(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map && value['__type'] == 'serverTimestamp') {
        result[entry.key] = value['fallback'];
      } else if (value is Map && value['__type'] == 'timestamp') {
        result[entry.key] = value['value'];
      } else if (value is Map<String, dynamic>) {
        result[entry.key] = _fromJsonForDisplay(value);
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────────────
  String _activityYearMonth(Map<String, dynamic> data) {
    final dateStr = data['date']?.toString() ?? '';
    DateTime? dt;
    if (dateStr.isNotEmpty) {
      dt = DateTime.tryParse(dateStr);
      if (dt == null) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          dt = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
        }
      }
    }
    dt ??= DateTime.now();
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$yy$mm';
  }

  String _buildActivityNumber(String type, String yearMonth, int sequence) {
    final t = type.toUpperCase() == 'TUNDA' ? 'TUNDA' : 'PANDU';
    return 'BKT/$t/IDBTM/SIS/$yearMonth/${sequence.toString().padLeft(4, '0')}';
  }

  int? _toPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}
