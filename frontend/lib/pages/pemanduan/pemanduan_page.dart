import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:pilotage_and_assistance_app/pages/pemanduan/tambah_pemanduan_page.dart';
import 'package:pilotage_and_assistance_app/services/firestore_data_service.dart';
import 'package:pilotage_and_assistance_app/utils/pdf_generator.dart';
import 'package:pilotage_and_assistance_app/utils/user_session.dart';
import 'package:pilotage_and_assistance_app/widgets/common/gradient_background.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class PemanduanPage extends StatefulWidget {
  const PemanduanPage({super.key});

  @override
  State<PemanduanPage> createState() => _PemanduanPageState();
}

class _PemanduanPageState extends State<PemanduanPage> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  String _dateFilterText = 'Semua Tanggal';

  // Temporary storage for signature per ID (used for PDF generation - NOT SAVED TO DATABASE)
  final Map<String, String> _pendingSignatures = {};

  final FirestoreDataService _dataService = FirestoreDataService();
  StreamSubscription<List<Map<String, dynamic>>>? _pilotagesSub;
  StreamSubscription<Map<String, String>>? _statsSub;
  List<Map<String, dynamic>> _allPemanduanList = [];
  List<Map<String, dynamic>> _pemanduanList = [];
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'total': '0',
    'active': '0',
    'completed': '0',
    'scheduled': '0',
  };

  // Pagination variables
  int _currentPage = 1;
  int _rowsPerPage = 10;
  int _totalData = 0;
  int _totalPages = 1;

  // User role
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadData();
  }

  @override
  void dispose() {
    _pilotagesSub?.cancel();
    _statsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Load user role from SharedPreferences
  Future<void> _loadUserRole() async {
    await UserSession.loadUser();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = UserSession.userRole ?? prefs.getString('userRole') ?? '';
    });
  }

  bool get _isAdmin {
    final role = _userRole.toLowerCase();
    return role == 'admin' || role == 'superadmin';
  }

  String _activityDocId(Map<String, dynamic> data) {
    for (final key in ['_doc_id', 'doc_id', 'document_id']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '-') return value;
    }
    return data['id']?.toString().trim() ?? '';
  }

  String _activityDisplayId(Map<String, dynamic> data) {
    for (final key in [
      'activity_no',
      'document_no',
      'pilot_certificate_no',
      'certificate_no',
      'doc_no',
      'id',
    ]) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != '-') return value;
    }
    return '-';
  }

  List<String> _activitySignatureKeys(Object id, Map<String, dynamic> data) {
    final keys = <String>{id.toString()};
    final docId = _activityDocId(data);
    final displayId = _activityDisplayId(data);
    if (docId.isNotEmpty) keys.add(docId);
    if (displayId.isNotEmpty && displayId != '-') keys.add(displayId);
    return keys.toList();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchPilotages(), _fetchStats()]);
  }

  Future<void> _fetchPilotages() async {
    setState(() => _isLoading = true);
    await _pilotagesSub?.cancel();

    String? startDate;
    String? endDate;
    if (_selectedDateRange != null) {
      startDate = _formatDateForQuery(_selectedDateRange!.start);
      endDate = _formatDateForQuery(_selectedDateRange!.end);
    }

    _pilotagesSub = _dataService
        .watchActivityLogs(
          status: _selectedFilter != 'Semua' ? _selectedFilter : '',
          search: _searchController.text,
          startDate: startDate,
          endDate: endDate,
          limit: 1000,
        )
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _allPemanduanList = rows;
              _totalData = rows.length;
              _totalPages = _totalData > 0
                  ? ((_totalData / _rowsPerPage).ceil())
                  : 1;
              if (_currentPage > _totalPages) {
                _currentPage = _totalPages;
              }
              _applyPagination();
              _isLoading = false;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
            }
          },
        );
  }

  Future<void> _fetchStats() async {
    final todayStr = _formatDateForQuery(DateTime.now());
    await _statsSub?.cancel();
    _statsSub = _dataService
        .watchActivityStatsForDate(todayStr)
        .listen(
          (data) {
            if (!mounted) return;
            setState(() => _stats = data);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _stats = {
                'total': '0',
                'active': '0',
                'completed': '0',
                'scheduled': '0',
              };
            });
          },
        );
  }

  String _formatDateForQuery(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _applyPagination() {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (start + _rowsPerPage) > _allPemanduanList.length
        ? _allPemanduanList.length
        : start + _rowsPerPage;
    _pemanduanList = start >= _allPemanduanList.length
        ? []
        : _allPemanduanList.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
        _applyPagination();
      });
    }
  }

  void _changeRowsPerPage(int? newRowsPerPage) {
    if (newRowsPerPage != null) {
      setState(() {
        _rowsPerPage = newRowsPerPage;
        _currentPage = 1;
        _totalPages = _totalData > 0 ? ((_totalData / _rowsPerPage).ceil()) : 1;
        _applyPagination();
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromRGBO(0, 40, 120, 1),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _dateFilterText =
            '${picked.start.day}-${picked.start.month}-${picked.start.year} sampai ${picked.end.day}-${picked.end.month}-${picked.end.year}';
        _currentPage = 1;
      });
      _fetchPilotages();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      _dateFilterText = 'Semua Tanggal';
      _currentPage = 1;
    });
    _fetchPilotages();
  }

  Widget _buildPaginationControls() {
    final startIndex = (_currentPage - 1) * _rowsPerPage + 1;
    final endIndex = (_currentPage * _rowsPerPage > _totalData)
        ? _totalData
        : _currentPage * _rowsPerPage;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Tampil:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color.fromRGBO(12, 10, 80, 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      underline: const SizedBox(),
                      items: [10, 25, 50, 100].map((value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value'),
                        );
                      }).toList(),
                      onChanged: _changeRowsPerPage,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Text(
                'Menampilkan $startIndex-$endIndex dari $_totalData',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(12, 10, 80, 1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage > 1
                      ? const Color.fromRGBO(0, 40, 120, 1)
                      : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ..._buildPageNumbers(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                style: IconButton.styleFrom(
                  backgroundColor: _currentPage < _totalPages
                      ? const Color.fromRGBO(0, 40, 120, 1)
                      : Colors.grey[300],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageButtons = [];

    int startPage = (_currentPage - 2).clamp(1, _totalPages);
    int endPage = (_currentPage + 2).clamp(1, _totalPages);

    if (startPage > 1) {
      pageButtons.add(_buildPageButton(1));
      if (startPage > 2) {
        pageButtons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 16)),
          ),
        );
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(_buildPageButton(i));
    }

    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) {
        pageButtons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 16)),
          ),
        );
      }
      pageButtons.add(_buildPageButton(_totalPages));
    }

    return pageButtons;
  }

  Widget _buildPageButton(int pageNumber) {
    final isActive = pageNumber == _currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _goToPage(pageNumber),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? const Color.fromRGBO(0, 40, 120, 1)
                : Colors.white,
            border: Border.all(
              color: isActive
                  ? const Color.fromRGBO(0, 40, 120, 1)
                  : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$pageNumber',
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : const Color.fromRGBO(12, 10, 80, 1),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updatePilotages(Map<String, dynamic> data) async {
    try {
      final docId = _activityDocId(data);
      if (docId.isEmpty) {
        throw Exception('ID dokumen tidak ditemukan');
      }

      final payload = Map<String, dynamic>.from(data)
        ..remove('_doc_id')
        ..remove('doc_id')
        ..remove('_has_pending_writes');

      await _dataService.updateActivityLog(docId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diupdate!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePilotages(Object id) async {
    try {
      await _dataService.deleteActivityLog(id.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil dihapus!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menghapus data: $e')));
      }
    }
  }

  // Show access denied dialog for non-admin users
  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Akses Ditolak'),
          ],
        ),
        content: const Text(
          'Hanya Admin yang dapat menghapus data pemanduan.\n\nSilakan hubungi administrator jika Anda memerlukan bantuan.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isLargeScreen = width > 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackground()),
          Positioned.fill(
            top: 100,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Cards
                          isLargeScreen
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Total Kegiatan',
                                        _stats['total']!,
                                        Icons.assessment,
                                        Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Aktif',
                                        _stats['active']!,
                                        Icons.sailing,
                                        Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Selesai',
                                        _stats['completed']!,
                                        Icons.check_circle,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Terjadwal',
                                        _stats['scheduled']!,
                                        Icons.schedule,
                                        Colors.purple,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            'Total',
                                            _stats['total']!,
                                            Icons.assessment,
                                            Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            'Aktif',
                                            _stats['active']!,
                                            Icons.sailing,
                                            Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatCard(
                                            'Selesai',
                                            _stats['completed']!,
                                            Icons.check_circle,
                                            Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatCard(
                                            'Terjadwal',
                                            _stats['scheduled']!,
                                            Icons.schedule,
                                            Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 30),

                          // Search, Filter, Add Button
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isLargeScreen ? 400 : double.infinity,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Cari nama kapal atau nama pandu...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    Future.delayed(
                                      const Duration(milliseconds: 500),
                                      () {
                                        if (_searchController.text == value) {
                                          setState(() => _currentPage = 1);
                                          _fetchPilotages();
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.filter_list),
                                  items:
                                      ['Semua', 'Aktif', 'Terjadwal', 'Selesai']
                                          .map(
                                            (filter) => DropdownMenuItem(
                                              value: filter,
                                              child: Text(filter),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedFilter = value;
                                        _currentPage = 1;
                                      });
                                      _fetchPilotages();
                                    }
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => _selectDate(context),
                                      child: Row(
                                        children: [
                                          Text(
                                            _dateFilterText,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color.fromRGBO(
                                                12,
                                                10,
                                                80,
                                                1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: Color.fromRGBO(
                                              12,
                                              10,
                                              80,
                                              1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedDateRange != null) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: _clearDateFilter,
                                        child: const Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const TambahPemanduanPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadData();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Kegiatan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    225,
                                    109,
                                    0,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daftar Kegiatan',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                              Text(
                                'Total: $_totalData data',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Table/Card List with Pagination
                          _pemanduanList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.inbox,
                                          size: 80,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tidak ada data',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    isLargeScreen
                                        ? _buildTable()
                                        : _buildCardList(),
                                    const SizedBox(height: 20),
                                    _buildPaginationControls(),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, outerConstraints) {
                    final isNarrow = outerConstraints.maxWidth < 390;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 12 : 20,
                        vertical: 8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showRoleText = constraints.maxWidth >= 430;
                          final iconBox = isNarrow ? 40.0 : 48.0;

                          return Row(
                            children: [
                              IconButton(
                                constraints: BoxConstraints.tightFor(
                                  width: iconBox,
                                  height: 48,
                                ),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Color.fromRGBO(12, 10, 80, 1),
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              SizedBox(width: isNarrow ? 2 : 4),
                              Expanded(
                                child: Text(
                                  "Pemanduan & Penundaan",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color.fromRGBO(12, 10, 80, 1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: isNarrow ? 18 : 20,
                                  ),
                                ),
                              ),
                              if (_userRole.isNotEmpty) ...[
                                SizedBox(width: isNarrow ? 4 : 8),
                                _buildRoleBadge(showText: showRoleText),
                              ],
                              SizedBox(width: isNarrow ? 2 : 4),
                              IconButton(
                                constraints: BoxConstraints.tightFor(
                                  width: iconBox,
                                  height: 48,
                                ),
                                icon: const Icon(Icons.refresh),
                                onPressed: _loadData,
                                tooltip: 'Refresh',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge({required bool showText}) {
    final color = _isAdmin ? Colors.red : Colors.blue;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: showText ? 10 : 8, vertical: 6),
      decoration: BoxDecoration(
        color: color[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isAdmin ? Icons.admin_panel_settings : Icons.person,
            size: 16,
            color: color[700],
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              _userRole,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              // Badge "Hari Ini"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hari Ini',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = date is Timestamp
          ? date.toDate()
          : date is DateTime
          ? date
          : DateTime.parse(date.toString());
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
      return date.toString();
    }
  }

  String _formatTimeOnly(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      final dt = dateTime is Timestamp
          ? dateTime.toDate()
          : dateTime is DateTime
          ? dateTime
          : DateTime.parse(dateTime.toString());
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (e) {
      // Jika parsing gagal, coba extract HH:MM dari string
      final timePattern = RegExp(r'(\d{2}):(\d{2})');
      final match = timePattern.firstMatch(dateTime.toString());
      if (match != null) {
        return '${match.group(1)}:${match.group(2)}';
      }
      return '-';
    }
  }

  String? _toIsoDateString(dynamic value) {
    if (value == null) return null;
    final dt = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : DateTime.tryParse(value.toString());
    if (dt == null) {
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }
    return _formatDateForQuery(dt);
  }

  String? _toIsoDateTimeString(dynamic value, {String? fallbackDate}) {
    if (value == null) return null;
    final dt = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : DateTime.tryParse(value.toString());
    if (dt != null) return dt.toIso8601String();

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(text) && fallbackDate != null) {
      return '${fallbackDate}T$text:00';
    }
    return text;
  }

  String _formatMultipleValues(String value) {
    if (value.isEmpty || value == '-') return '-';
    // Split by comma and format each value
    final values = value.split(',');
    if (values.length <= 1) return value;
    return values.map((v) => v.trim()).join('\n');
  }

  List<String> _parseMultipleValues(String value) {
    if (value.isEmpty || value == '-') return [];
    return value
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && v != '-')
        .toList();
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(
              label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            DataColumn(
              label: Text(
                'Nama Kapal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Call Sign',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Nama Nahkoda',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Bendera',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'GT Tug  / Tongkang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Keagenan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'LOA Tug / Tongkang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Sarat Muka',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Sarat Belakang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Pandu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Tugboat Dipakai',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Arah',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Pelabuhan Asal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Pelabuhan Tujuan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Tanggal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Pilot On Board',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Aksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _pemanduanList.map((data) {
            return DataRow(
              cells: [
                DataCell(Text(_activityDisplayId(data))),
                DataCell(Text(data['vessel_name'] ?? '-')),
                DataCell(Text(data['call_sign'] ?? '-')),
                DataCell(Text(data['master_name'] ?? '-')),
                DataCell(Text(data['flag'] ?? '-')),
                DataCell(
                  Text(
                    data['gross_tonnage']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text(data['agency'] ?? '-')),
                DataCell(
                  Text(
                    data['loa'] != null ? '${data['loa']} m' : '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    data['fore_draft'] != null
                        ? '${data['fore_draft']} m'
                        : '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    data['aft_draft'] != null ? '${data['aft_draft']} m' : '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text(data['pilot_name'] ?? '-')),
                DataCell(
                  Text(
                    _formatMultipleValues(
                      (data['assist_tug_name'] ?? '-').toString(),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    data['last_port'] ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    data['next_port'] ?? '-',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    _formatDate(data['date']),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    _formatTimeOnly(data['pilot_on_board']),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(_buildStatusBadge(data['status'] ?? 'Terjadwal')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => _showDetailDialog(context, data),
                        tooltip: 'Lihat Detail',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                          size: 20,
                        ),
                        onPressed: () => _showEditDialog(context, data),
                        tooltip: 'Edit',
                      ),
                      // Tombol PDF untuk kegiatan yang sudah Selesai
                      if (data['status'] == 'Selesai') ...[
                        IconButton(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.green,
                            size: 20,
                          ),
                          onPressed: () => _showPdfGenerationDialog(
                            context,
                            _activityDocId(data),
                            data,
                          ),
                          tooltip: 'Generate PDF',
                        ),
                      ],
                      // Tombol Delete hanya muncul untuk Admin
                      if (_isAdmin) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteConfirmation(
                            context,
                            _activityDocId(data),
                          ),
                          tooltip: 'Hapus',
                        ),
                      ] else
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: _showAccessDeniedDialog,
                          tooltip: 'Hapus (Admin Only)',
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardList() {
    return Column(
      children: _pemanduanList.map((data) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${_activityDisplayId(data)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(12, 10, 80, 1),
                    ),
                  ),
                  _buildStatusBadge(data['status'] ?? 'Terjadwal'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['vessel_name'] ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pandu: Capt. ${data['pilot_name'] ?? '-'}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final tugboatList = _parseMultipleValues(
                    (data['assist_tug_name'] ?? '-').toString(),
                  );

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(245, 247, 252, 1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_boat,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tugboat Dipakai',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (tugboatList.isEmpty)
                          Text(
                            '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tugboatList
                                .map(
                                  (tug) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color.fromRGBO(
                                          0,
                                          40,
                                          120,
                                          0.2,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      tug,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.route, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${data['last_port'] ?? '-'} → ${data['next_port'] ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(data['pilot_on_board']),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCardActions(context, data),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardActions(BuildContext context, Map<String, dynamic> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: compact ? 6 : 4,
            runSpacing: 6,
            children: [
              if (data['status'] == 'Selesai')
                _buildCardActionButton(
                  onPressed: () => _showPdfGenerationDialog(
                    context,
                    _activityDocId(data),
                    data,
                  ),
                  icon: Icons.picture_as_pdf,
                  label: 'PDF',
                  color: Colors.green,
                  compact: compact,
                ),
              _buildCardActionButton(
                onPressed: () => _showDetailDialog(context, data),
                icon: Icons.visibility,
                label: 'Detail',
                color: Colors.blue,
                compact: compact,
              ),
              _buildCardActionButton(
                onPressed: () => _showEditDialog(context, data),
                icon: Icons.edit,
                label: 'Edit',
                color: Colors.orange,
                compact: compact,
              ),
              if (_isAdmin)
                _buildCardActionButton(
                  onPressed: () =>
                      _showDeleteConfirmation(context, _activityDocId(data)),
                  icon: Icons.delete,
                  label: 'Hapus',
                  color: Colors.red,
                  compact: compact,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool compact = false,
  }) {
    if (compact) {
      return SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: color,
          tooltip: label,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Aktif':
        color = Colors.orange;
        break;
      case 'Selesai':
        color = Colors.green;
        break;
      case 'Terjadwal':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Pemanduan ID: ${_activityDisplayId(data)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nama Kapal', data['vessel_name'] ?? '-'),
              _buildDetailRow('Call Sign', data['call_sign'] ?? '-'),
              _buildDetailRow('Nama Master', data['master_name'] ?? '-'),
              _buildDetailRow('Bendera', data['flag'] ?? '-'),
              _buildDetailRow(
                'Gross Tonnage',
                data['gross_tonnage']?.toString() ?? '-',
              ),
              _buildDetailRow('Keagenan', data['agency'] ?? '-'),
              _buildDetailRow(
                'LOA',
                data['loa'] != null ? '${data['loa']} m' : '-',
              ),
              _buildDetailRow(
                'Sarat Muka',
                data['fore_draft'] != null ? '${data['fore_draft']} m' : '-',
              ),
              _buildDetailRow(
                'Sarat Belakang',
                data['aft_draft'] != null ? '${data['aft_draft']} m' : '-',
              ),
              const Divider(height: 24),
              _buildDetailRow('Pandu', data['pilot_name'] ?? '-'),
              _buildDetailRow(
                'Arah Pemanduan',
                '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}',
              ),
              _buildDetailRow('Pelabuhan Asal', data['last_port'] ?? '-'),
              _buildDetailRow('Pelabuhan Tujuan', data['next_port'] ?? '-'),
              _buildDetailRow('Tanggal', _formatDate(data['date'])),
              _buildDetailRow(
                'Pandu Naik kapal',
                _formatTimeOnly(data['pilot_on_board']),
              ),
              _buildDetailRow(
                'Kapal Bergerak',
                _formatTimeOnly(data['vessel_start']),
              ),
              _buildDetailRow(
                'Pandu Selesai',
                _formatTimeOnly(data['pilot_finished']),
              ),
              _buildDetailRow(
                'Pandu Turun',
                _formatTimeOnly(data['pilot_get_off']),
              ),
              const Divider(height: 24),
              _buildDetailRow(
                'Assist Tug',
                _formatMultipleValues(data['assist_tug_name'] ?? '-'),
              ),
              _buildDetailRow(
                'Engine Power',
                _formatMultipleValues(data['engine_power'] ?? '-'),
              ),
              _buildDetailRow(
                'Bollard Pull Power',
                _formatMultipleValues(data['bollard_pull_power'] ?? '-'),
              ),
              _buildDetailRow('Status', data['status'] ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    final vesselNameParts = (data['vessel_name'] ?? '').split('/');
    String vesselType = vesselNameParts.length > 1 ? 'Tug' : 'Motor';

    final vesselController = TextEditingController(
      text: vesselType == 'Motor' ? data['vessel_name'] : '',
    );
    final tugNameController = TextEditingController(
      text: vesselType == 'Tug' && vesselNameParts.isNotEmpty
          ? vesselNameParts[0]
          : '',
    );
    final bargeNameController = TextEditingController(
      text: vesselType == 'Tug' && vesselNameParts.length > 1
          ? vesselNameParts[1]
          : '',
    );
    final callSignController = TextEditingController(
      text: data['call_sign'] ?? '',
    );
    final masterController = TextEditingController(
      text: data['master_name'] ?? '',
    );
    final flagController = TextEditingController(text: data['flag'] ?? '');

    final gtParts = (data['gross_tonnage']?.toString() ?? '').split('/');
    final gtTugController = TextEditingController(
      text: gtParts.isNotEmpty ? gtParts[0].trim() : '',
    );
    final gtBargeController = TextEditingController(
      text: gtParts.length > 1 ? gtParts[1].trim() : '',
    );

    final agencyController = TextEditingController(text: data['agency'] ?? '');

    final loaParts = (data['loa']?.toString() ?? '').split('/');
    final loaTugController = TextEditingController(
      text: loaParts.isNotEmpty ? loaParts[0].trim() : '',
    );
    final loaBargeController = TextEditingController(
      text: loaParts.length > 1 ? loaParts[1].trim() : '',
    );

    final foredraftController = TextEditingController(
      text: data['fore_draft']?.toString() ?? '',
    );
    final aftdraftController = TextEditingController(
      text: data['aft_draft']?.toString() ?? '',
    );
    final pilotController = TextEditingController(
      text: data['pilot_name'] ?? '',
    );
    final lastPortController = TextEditingController(
      text: data['last_port'] ?? '',
    );
    final nextPortController = TextEditingController(
      text: data['next_port'] ?? '',
    );

    // Time Controllers - always load existing values
    final pilotOnBoardController = TextEditingController(
      text: data['pilot_on_board'] != null
          ? _formatTimeOnly(data['pilot_on_board'])
          : '',
    );
    final pilotFinishedController = TextEditingController(
      text: data['pilot_finished'] != null
          ? _formatTimeOnly(data['pilot_finished'])
          : '',
    );
    final vesselStartController = TextEditingController(
      text: data['vessel_start'] != null
          ? _formatTimeOnly(data['vessel_start'])
          : '',
    );
    final pilotGetOffController = TextEditingController(
      text: data['pilot_get_off'] != null
          ? _formatTimeOnly(data['pilot_get_off'])
          : '',
    );

    // Signature Controller
    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      // Export transparan agar di PDF hanya goresan tanda tangan yang terlihat
      exportBackgroundColor: Colors.transparent,
    );

    String selectedStatus = data['status'] ?? 'Terjadwal';

    String selectedDirection;
    final jettyController = TextEditingController();

    // Determine direction based on which field contains 'LAUT'
    if (data['from_where']?.toString().toLowerCase() == 'laut') {
      selectedDirection = 'IN';
      jettyController.text = data['to_where'] ?? '';
    } else if (data['to_where']?.toString().toLowerCase() == 'laut') {
      selectedDirection = 'OUT';
      jettyController.text = data['from_where'] ?? '';
    } else {
      // Fallback: assume OUT direction if neither field is 'LAUT'
      selectedDirection = 'OUT';
      jettyController.text = data['from_where'] ?? '';
    }

    // Predefined assist tug options
    final List<Map<String, String>> assistTugOptions = [
      {'name': 'TB. MEGAMAS VISHA', 'power': '2060', 'bollard_pull': '25'},
      {'name': 'TB. HEMINGWAY 2400', 'power': '2400', 'bollard_pull': '24'},
      {'name': 'TB. ORIENT VICTORY 1', 'power': '3500', 'bollard_pull': '44'},
    ];

    // Parse assist tug data
    List<Map<String, String>> selectedAssistTugs = [];
    final assistTugNames = (data['assist_tug_name'] ?? '').split(',');
    final enginePowers = (data['engine_power'] ?? '').split(',');
    final bollardPulls = (data['bollard_pull_power'] ?? '').split(',');

    for (int i = 0; i < assistTugNames.length; i++) {
      if (assistTugNames[i].trim().isNotEmpty) {
        selectedAssistTugs.add({
          'name': assistTugNames[i].trim(),
          'power': i < enginePowers.length ? enginePowers[i].trim() : '',
          'bollard_pull': i < bollardPulls.length ? bollardPulls[i].trim() : '',
        });
      }
    }

    // Time Picker Helper
    Future<void> selectTime(
      BuildContext context,
      TextEditingController controller,
    ) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color.fromRGBO(0, 40, 120, 1),
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Check if additional time fields should be shown
          bool showTimeFields =
              selectedStatus == 'Aktif' || selectedStatus == 'Selesai';

          // Tampilkan signature canvas untuk status Aktif dan Selesai
          bool showSignatureCanvas =
              selectedStatus == 'Aktif' || selectedStatus == 'Selesai';

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text('Edit Pemanduan ID: ${_activityDisplayId(data)}'),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pilihan Jenis Kapal
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('KAPAL MOTOR'),
                            value: 'Motor',
                            groupValue: vesselType,
                            onChanged: (value) {
                              setDialogState(() {
                                vesselType = value!;
                                // Reset fields saat ganti jenis
                                tugNameController.clear();
                                bargeNameController.clear();
                                gtBargeController.clear();
                                loaBargeController.clear();
                              });
                            },
                            activeColor: const Color.fromRGBO(0, 40, 120, 1),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('TUG BOAT & TONGKANG'),
                            value: 'Tug',
                            groupValue: vesselType,
                            onChanged: (value) {
                              setDialogState(() {
                                vesselType = value!;
                              });
                            },
                            activeColor: const Color.fromRGBO(0, 40, 120, 1),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Conditional: Nama Kapal Motor atau Nama Tug Boat & Tongkang
                    if (vesselType == 'Motor') ...[
                      TextField(
                        controller: vesselController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Kapal Motor *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Image.asset(
                              'assets/icons/vessel.png',
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: tugNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Tug Boat *',
                          hintText: 'Contoh: TB. Bintang Laut',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Image.asset(
                              'assets/icons/tugboat.png',
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bargeNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Tongkang *',
                          hintText: 'Contoh: BG. Jaya 01',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              'assets/icons/barge.png',
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Basic Info
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: callSignController,
                            decoration: InputDecoration(
                              labelText: 'Call Sign',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(9),
                                child: Image.asset(
                                  'assets/icons/call_sign.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: masterController,
                            decoration: InputDecoration(
                              labelText: 'Nama Nahkoda',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/pilot.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: flagController,
                            decoration: InputDecoration(
                              labelText: 'Bendera',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.asset(
                                  'assets/icons/flag.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: agencyController,
                            decoration: InputDecoration(
                              labelText: 'Keagenan',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  'assets/icons/agency.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gross Tonnage
                    if (vesselType == 'Motor') ...[
                      TextField(
                        controller: gtTugController,
                        decoration: InputDecoration(
                          labelText: 'Gross Tonnage',
                          border: const OutlineInputBorder(),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/icons/vessel.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: gtTugController,
                              decoration: InputDecoration(
                                labelText: 'GT Tug',
                                border: const OutlineInputBorder(),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image.asset(
                                    'assets/icons/tugboat.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: gtBargeController,
                              decoration: InputDecoration(
                                labelText: 'GT Tongkang',
                                border: const OutlineInputBorder(),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Image.asset(
                                    'assets/icons/barge.png',
                                    width: 15,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // LOA
                    if (vesselType == 'Motor') ...[
                      TextField(
                        controller: loaTugController,
                        decoration: InputDecoration(
                          labelText: 'LOA (meter)',
                          border: const OutlineInputBorder(),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Image.asset(
                              'assets/icons/loa.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: loaTugController,
                              decoration: InputDecoration(
                                labelText: 'LOA Tug (m)',
                                border: const OutlineInputBorder(),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Image.asset(
                                    'assets/icons/loa.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: loaBargeController,
                              decoration: InputDecoration(
                                labelText: 'LOA Tongkang (m)',
                                border: const OutlineInputBorder(),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Image.asset(
                                    'assets/icons/loa.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Draft
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: foredraftController,
                            decoration: InputDecoration(
                              labelText: 'Sarat Muka (m)',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/draft.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: aftdraftController,
                            decoration: InputDecoration(
                              labelText: 'Sarat Belakang (m)',
                              border: const OutlineInputBorder(),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/draft.png',
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pilot and Ports
                    TextField(
                      controller: pilotController,
                      decoration: InputDecoration(
                        labelText: 'Nama Pandu',
                        border: const OutlineInputBorder(),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Image.asset(
                            'assets/icons/pilot.png',
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lastPortController,
                            decoration: const InputDecoration(
                              labelText: 'Pelabuhan Asal',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: nextPortController,
                            decoration: const InputDecoration(
                              labelText: 'Pelabuhan Tujuan',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Direction Selection
                    const Text(
                      'Arah Pemanduan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('IN'),
                            value: 'IN',
                            groupValue: selectedDirection,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDirection = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('OUT'),
                            value: 'OUT',
                            groupValue: selectedDirection,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDirection = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Jetty
                    TextField(
                      controller: jettyController,
                      decoration: InputDecoration(
                        labelText: 'Dermaga',
                        border: const OutlineInputBorder(),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Image.asset(
                            'assets/icons/jetty.png',
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Selection
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: ['Terjadwal', 'Aktif', 'Selesai']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Time Fields (shown only for Aktif or Selesai)
                    if (showTimeFields) ...[
                      const Text(
                        'Waktu Pemanduan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pilotOnBoardController,
                              decoration: const InputDecoration(
                                labelText: 'Pandu Naik Kapal',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              readOnly: true,
                              onTap: () =>
                                  selectTime(context, pilotOnBoardController),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: vesselStartController,
                              decoration: const InputDecoration(
                                labelText: 'Kapal Bergerak',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              readOnly: true,
                              onTap: () =>
                                  selectTime(context, vesselStartController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pilotFinishedController,
                              decoration: const InputDecoration(
                                labelText: 'Pandu Selesai',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              readOnly: true,
                              onTap: () =>
                                  selectTime(context, pilotFinishedController),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: pilotGetOffController,
                              decoration: const InputDecoration(
                                labelText: 'Pandu Turun',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.access_time),
                              ),
                              readOnly: true,
                              onTap: () =>
                                  selectTime(context, pilotGetOffController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Assist Tug Selection
                    const Text(
                      'Assist Tug',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: assistTugOptions.map((tug) {
                        final isSelected = selectedAssistTugs.any(
                          (selected) => selected['name'] == tug['name'],
                        );
                        return FilterChip(
                          label: Text(tug['name']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              // Check if tug already selected
                              bool alreadySelected = selectedAssistTugs.any(
                                (selectedTug) =>
                                    selectedTug['name'] == tug['name'],
                              );

                              if (alreadySelected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tug Boat ini sudah dipilih'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                selectedAssistTugs.add(Map.from(tug));
                              });
                            } else {
                              setDialogState(() {
                                selectedAssistTugs.removeWhere(
                                  (selectedTug) =>
                                      selectedTug['name'] == tug['name'],
                                );
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Display selected assist tugs
                    if (selectedAssistTugs.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assist Tug yang Dipilih:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...selectedAssistTugs.map(
                              (tug) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${tug['name']} - ${tug['power']} HP / ${tug['bollard_pull']} TON',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedAssistTugs.remove(tug);
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Signature canvas diletakkan paling akhir
                    if (showSignatureCanvas) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tanda tangan ini akan langsung masuk ke PDF dan TIDAK disimpan di database.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tanda Tangan Nahkoda',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Signature(controller: signatureController),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              signatureController.clear();
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Hapus Tanda Tangan'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Collect form data
                  final vesselName = vesselType == 'Motor'
                      ? vesselController.text.trim()
                      : '${tugNameController.text.trim()}/${bargeNameController.text.trim()}';

                  final grossTonnage = vesselType == 'Motor'
                      ? gtTugController.text.trim()
                      : '${gtTugController.text.trim()}/${gtBargeController.text.trim()}';

                  final loa = vesselType == 'Motor'
                      ? loaTugController.text.trim()
                      : '${loaTugController.text.trim()}/${loaBargeController.text.trim()}';

                  final fromWhere = selectedDirection == 'IN'
                      ? 'LAUT'
                      : jettyController.text.trim();
                  final toWhere = selectedDirection == 'IN'
                      ? jettyController.text.trim()
                      : 'LAUT';

                  // Prepare update data
                  final updateData = {
                    '_doc_id': _activityDocId(data),
                    'id': _activityDisplayId(data),
                    'vessel_name': vesselName,
                    'call_sign': callSignController.text.trim(),
                    'master_name': masterController.text.trim(),
                    'flag': flagController.text.trim(),
                    'gross_tonnage': grossTonnage,
                    'agency': agencyController.text.trim(),
                    'loa': loa,
                    'fore_draft': foredraftController.text.trim(),
                    'aft_draft': aftdraftController.text.trim(),
                    'pilot_name': pilotController.text.trim(),
                    'from_where': fromWhere,
                    'to_where': toWhere,
                    'last_port': lastPortController.text.trim(),
                    'next_port': nextPortController.text.trim(),
                    'status': selectedStatus,
                    'assist_tug_name': selectedAssistTugs
                        .map((tug) => tug['name'])
                        .join(','),
                    'engine_power': selectedAssistTugs
                        .map((tug) => tug['power'])
                        .join(','),
                    'bollard_pull_power': selectedAssistTugs
                        .map((tug) => tug['bollard_pull'])
                        .join(','),
                  };
                  for (final key in [
                    'activity_no',
                    'document_no',
                    'pilot_certificate_no',
                    'tug_certificate_no',
                    'sequence_no',
                    'sequence_year_month',
                  ]) {
                    if (data[key] != null) {
                      updateData[key] = data[key];
                    }
                  }

                  // Always include time fields to prevent null values
                  updateData['pilot_on_board'] = data['pilot_on_board'];
                  updateData['pilot_finished'] = data['pilot_finished'];
                  updateData['vessel_start'] = data['vessel_start'];
                  updateData['pilot_get_off'] = data['pilot_get_off'];

                  // Update time fields if status is Aktif or Selesai and values are provided
                  if (selectedStatus == 'Aktif' ||
                      selectedStatus == 'Selesai') {
                    final eventDate =
                        data['date'] ??
                        DateTime.now().toIso8601String().split('T')[0];
                    if (pilotOnBoardController.text.isNotEmpty) {
                      updateData['pilot_on_board'] =
                          '${eventDate}T${pilotOnBoardController.text}:00';
                    }
                    if (pilotFinishedController.text.isNotEmpty) {
                      updateData['pilot_finished'] =
                          '${eventDate}T${pilotFinishedController.text}:00';
                    }
                    if (vesselStartController.text.isNotEmpty) {
                      updateData['vessel_start'] =
                          '${eventDate}T${vesselStartController.text}:00';
                    }
                    if (pilotGetOffController.text.isNotEmpty) {
                      updateData['pilot_get_off'] =
                          '${eventDate}T${pilotGetOffController.text}:00';
                    }
                  }

                  // ==============================================
                  // SIMPAN SIGNATURE KE STATE (TEMPORARY)
                  // TIDAK DISIMPAN KE DATABASE!
                  // ==============================================
                  if ((selectedStatus == 'Aktif' ||
                          selectedStatus == 'Selesai') &&
                      signatureController.isNotEmpty) {
                    final signatureBytes = await signatureController
                        .toPngBytes();
                    if (signatureBytes != null) {
                      final signatureId = _activityDocId(data);
                      final displayId = _activityDisplayId(data);
                      final signatureBase64 = base64Encode(signatureBytes);
                      final signatureDataUrl =
                          'data:image/png;base64,$signatureBase64';

                      setState(() {
                        // Simpan temporary per ID untuk PDF generation
                        _pendingSignatures[signatureId] = signatureBase64;
                        _pendingSignatures[displayId] = signatureBase64;
                      });

                      // Kirim juga saat update agar bisa disimpan permanen (jika kolom tersedia)
                      updateData['signature'] = signatureDataUrl;

                      // Tampilkan notifikasi
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ Tanda tangan tersimpan sementara.\n'
                              'Silakan generate PDF sebelum keluar dari halaman ini.',
                            ),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }

                  // Call update function (TANPA signature - tidak masuk database)
                  await _updatePilotages(updateData);
                  Navigator.pop(context);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPdfGenerationDialog(
    BuildContext context,
    Object id,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Jenis Form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Silakan pilih jenis form yang ingin di-generate:'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _generatePdf(id, 'pandu', data);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Form Pandu\n(2A1)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _generatePdf(id, 'tunda', data);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Form Tunda\n(2A2)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(
    Object id,
    String type,
    Map<String, dynamic> data,
  ) async {
    var dialogOpen = false;
    try {
      if (mounted) {
        dialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      String? signatureToSend;
      final signatureKeys = _activitySignatureKeys(id, data);
      for (final key in signatureKeys) {
        signatureToSend = _pendingSignatures[key];
        if (signatureToSend != null) break;
      }
      if (signatureToSend == null && _pendingSignatures.length == 1) {
        signatureToSend = _pendingSignatures.values.first;
      }
      if (signatureToSend == null &&
          data['signature'] != null &&
          data['signature'].toString().trim().isNotEmpty) {
        signatureToSend = data['signature'].toString().trim();
      }

      String? signaturePayload;
      if (signatureToSend != null && signatureToSend.trim().isNotEmpty) {
        signaturePayload = signatureToSend.startsWith('data:image')
            ? signatureToSend
            : 'data:image/png;base64,$signatureToSend';
      }

      final pdfData = Map<String, dynamic>.from(data);
      pdfData['doc_id'] = id.toString();
      pdfData['id'] = _activityDisplayId(data);
      pdfData['form_type'] = type;

      final dateText = _toIsoDateString(data['date']);
      if (dateText != null) {
        pdfData['date'] = dateText;
      }

      for (final field in [
        'pilot_on_board',
        'vessel_start',
        'pilot_finished',
        'pilot_get_off',
      ]) {
        final normalized = _toIsoDateTimeString(
          data[field],
          fallbackDate: dateText,
        );
        if (normalized != null) {
          pdfData[field] = normalized;
        }
      }

      if (signaturePayload != null) {
        pdfData['signature'] = signaturePayload;
      }

      final file = await PdfGenerator.generatePemanduanPdf(pdfData);

      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (file == null) {
        throw Exception('Gagal menyimpan PDF. Periksa izin penyimpanan.');
      }

      if (signatureToSend != null) {
        setState(() {
          for (final key in signatureKeys) {
            _pendingSignatures.remove(key);
          }
        });
      }

      final fileName = file.path.split(RegExp(r'[\\/]')).last;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF berhasil dibuat:\n$fileName'
              '${signatureToSend != null ? '\nDengan tanda tangan' : ''}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await PdfGenerator.openPdf(file);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tidak dapat membuka PDF: $e'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate PDF:\n$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, Object id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Konfirmasi Hapus'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus data pemanduan ini?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data yang dihapus tidak dapat dikembalikan!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePilotages(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
