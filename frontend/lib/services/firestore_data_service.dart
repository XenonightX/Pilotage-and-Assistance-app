import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDataService {
  FirestoreDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _activityLogs =>
      _firestore.collection('activity_logs');

  CollectionReference<Map<String, dynamic>> get _counters =>
      _firestore.collection('counters');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return {'uid': doc.id, 'id': doc.id, ...doc.data()!};
  }

  Future<void> setUserProfile(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set({
      ...data,
      'search_tokens': _buildSearchTokens(data),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchUsers({String search = ''}) {
    final normalizedSearch = _normalizeSearch(search);

    return _users.orderBy('name').snapshots(includeMetadataChanges: true).map((
      snapshot,
    ) {
      final rows = snapshot.docs.map(_mapDocument).toList();
      if (normalizedSearch.isEmpty) {
        return rows;
      }
      return rows
          .where((row) => _matchesUserSearch(row, normalizedSearch))
          .toList();
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await setUserProfile(uid, data);
  }

  Future<void> deleteUserProfile(String uid) async {
    await _users.doc(uid).delete();
  }

  Stream<List<Map<String, dynamic>>> watchActivityLogs({
    String status = '',
    String search = '',
    String? startDate,
    String? endDate,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _activityLogs;

    if (status.isNotEmpty && status != 'Semua') {
      query = query.where('status', isEqualTo: status);
    }
    if (startDate != null && startDate.isNotEmpty) {
      query = query.where('date', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      query = query.where('date', isLessThanOrEqualTo: endDate);
    }

    query = query
        .orderBy('date', descending: true)
        .orderBy('pilot_on_board', descending: true)
        .limit(limit);

    final normalizedSearch = _normalizeSearch(search);

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final rows = snapshot.docs.map(_mapActivityDocument).toList();
      if (normalizedSearch.isEmpty) {
        return rows;
      }
      return rows
          .where((row) => _matchesLocalSearch(row, normalizedSearch))
          .toList();
    });
  }

  Stream<Map<String, String>> watchActivityStatsForDate(String date) {
    return _activityLogs.where('date', isEqualTo: date).snapshots().map((
      snapshot,
    ) {
      var active = 0;
      var completed = 0;
      var scheduled = 0;

      for (final doc in snapshot.docs) {
        switch ((doc.data()['status'] ?? '').toString()) {
          case 'Aktif':
            active += 1;
            break;
          case 'Selesai':
            completed += 1;
            break;
          case 'Terjadwal':
            scheduled += 1;
            break;
        }
      }

      return {
        'total': snapshot.docs.length.toString(),
        'active': active.toString(),
        'completed': completed.toString(),
        'scheduled': scheduled.toString(),
      };
    });
  }

  Stream<List<Map<String, dynamic>>> watchPilotUsers() {
    return _users
        .where('role', isEqualTo: 'pilot')
        .orderBy('name')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map(_mapDocument).toList());
  }

  Future<String> addActivityLog(Map<String, dynamic> data) async {
    final doc = _activityLogs.doc();
    final yearMonth = _activityYearMonth(data);
    final counterRef = _counters.doc('activity_$yearMonth');

    await _firestore.runTransaction((transaction) async {
      final counterSnapshot = await transaction.get(counterRef);
      final nextSequence =
          (_toPositiveInt(counterSnapshot.data()?['last_sequence']) ?? 0) + 1;
      final panduNumber = _buildActivityNumber(
        'PANDU',
        yearMonth,
        nextSequence,
      );
      final tundaNumber = _buildActivityNumber(
        'TUNDA',
        yearMonth,
        nextSequence,
      );

      transaction.set(counterRef, {
        'last_sequence': nextSequence,
        'sequence_year_month': yearMonth,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(
        doc,
        _withAuditFields({
          ...data,
          'id': panduNumber,
          'activity_no': panduNumber,
          'document_no': panduNumber,
          'pilot_certificate_no': panduNumber,
          'tug_certificate_no': tundaNumber,
          'sequence_no': nextSequence,
          'sequence_year_month': yearMonth,
        }, isCreate: true),
      );
    });

    return doc.id;
  }

  Future<void> updateActivityLog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _activityLogs
        .doc(docId)
        .set(_withAuditFields(data, isCreate: false), SetOptions(merge: true));
  }

  Future<void> deleteActivityLog(String docId) async {
    await _activityLogs.doc(docId).delete();
  }

  Map<String, dynamic> _withAuditFields(
    Map<String, dynamic> data, {
    required bool isCreate,
  }) {
    final next = Map<String, dynamic>.from(data)
      ..['updated_at'] = FieldValue.serverTimestamp()
      ..['client_updated_at'] = DateTime.now().toIso8601String()
      ..['search_tokens'] = _buildSearchTokens(data);

    if (isCreate) {
      next['created_at'] = FieldValue.serverTimestamp();
      next['client_created_at'] = DateTime.now().toIso8601String();
    }

    return next;
  }

  Map<String, dynamic> _mapDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {
      ...doc.data(),
      'id': doc.id,
      '_has_pending_writes': doc.metadata.hasPendingWrites,
    };
  }

  Map<String, dynamic> _mapActivityDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    final displayId = _activityDisplayNumber(data, doc.id);
    final tundaNumber = _withActivityType(displayId, 'TUNDA');

    return {
      ...data,
      '_doc_id': doc.id,
      'doc_id': doc.id,
      'id': displayId,
      'activity_no': _bktText(data, ['activity_no'], displayId),
      'document_no': _bktText(data, ['document_no'], displayId),
      'pilot_certificate_no': _withActivityType(
        _bktText(data, [
          'pilot_certificate_no',
          'pandu_certificate_no',
        ], displayId),
        'PANDU',
      ),
      'tug_certificate_no': _withActivityType(
        _bktText(data, [
          'tug_certificate_no',
          'tunda_certificate_no',
        ], tundaNumber),
        'TUNDA',
      ),
      '_has_pending_writes': doc.metadata.hasPendingWrites,
    };
  }

  bool _matchesLocalSearch(Map<String, dynamic> row, String search) {
    final fields = [
      row['id'],
      row['activity_no'],
      row['document_no'],
      row['pilot_certificate_no'],
      row['tug_certificate_no'],
      row['vessel_name'],
      row['pilot_name'],
      row['agency'],
      row['flag'],
      row['from_where'],
      row['to_where'],
      row['last_port'],
      row['next_port'],
    ];

    return fields
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .any((value) => value.contains(search));
  }

  bool _matchesUserSearch(Map<String, dynamic> row, String search) {
    final fields = [row['name'], row['email'], row['role']];

    return fields
        .whereType<Object>()
        .map((value) => value.toString().toLowerCase())
        .any((value) => value.contains(search));
  }

  String _normalizeSearch(String search) {
    return search.trim().toLowerCase();
  }

  List<String> _buildSearchTokens(Map<String, dynamic> data) {
    final source = [
      data['vessel_name'],
      data['pilot_name'],
      data['agency'],
      data['flag'],
      data['from_where'],
      data['to_where'],
      data['last_port'],
      data['next_port'],
      data['name'],
      data['email'],
      data['role'],
      data['id'],
      data['activity_no'],
      data['document_no'],
      data['pilot_certificate_no'],
      data['tug_certificate_no'],
      data['sequence_no'],
    ].whereType<Object>().join(' ').toLowerCase();

    final tokens = RegExp(
      r'[a-z0-9]+',
    ).allMatches(source).map((match) => match.group(0)!).toSet();

    return tokens.toList()..sort();
  }

  String _activityDisplayNumber(Map<String, dynamic> data, String docId) {
    final existing = _firstText(data, [
      'activity_no',
      'document_no',
      'pilot_certificate_no',
      'certificate_no',
      'doc_no',
    ]);
    if (_isBktNumber(existing)) {
      return _withActivityType(existing, 'PANDU');
    }

    final yearMonth = _activityYearMonth(data);
    final sequence =
        _toPositiveInt(data['sequence_no']) ??
        _toPositiveInt(data['legacy_id']) ??
        _toPositiveInt(data['id']) ??
        _stableSequenceFromDocId(docId);

    return _buildActivityNumber('PANDU', yearMonth, sequence);
  }

  String _buildActivityNumber(String type, String yearMonth, int sequence) {
    final normalizedType = type.toUpperCase() == 'TUNDA' ? 'TUNDA' : 'PANDU';
    return 'BKT/$normalizedType/IDBTM/SIS/$yearMonth/${sequence.toString().padLeft(4, '0')}';
  }

  String _withActivityType(String number, String type) {
    if (!_isBktNumber(number)) return number;
    final normalizedType = type.toUpperCase() == 'TUNDA' ? 'TUNDA' : 'PANDU';
    return number.replaceFirst(
      RegExp(r'^BKT/(?:PANDU|TUNDA)/', caseSensitive: false),
      'BKT/$normalizedType/',
    );
  }

  bool _isBktNumber(String value) {
    return RegExp(
      r'^BKT/(?:PANDU|TUNDA)/IDBTM/SIS/\d{4}/\d{4}$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  String _activityYearMonth(Map<String, dynamic> data) {
    final date = _toDateTime(data['date']) ?? _toDateTime(data['created_at']);
    final dt = date ?? DateTime.now();
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$yy$mm';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final dateMatch = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(text);
    if (dateMatch == null) return null;

    return DateTime(
      int.parse(dateMatch.group(3)!),
      int.parse(dateMatch.group(2)!),
      int.parse(dateMatch.group(1)!),
    );
  }

  int? _toPositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  int _stableSequenceFromDocId(String docId) {
    var hash = 0;
    for (final codeUnit in docId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return (hash % 9999) + 1;
  }

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys, [
    String fallback = '',
  ]) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '-') return value;
    }
    return fallback;
  }

  String _bktText(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    final value = _firstText(data, keys);
    return _isBktNumber(value) ? value : fallback;
  }
}
