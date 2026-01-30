import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilotage_and_assistance_app/pages/pemanduan/tambah_pemanduan_page.dart';

class PemanduanPage extends StatefulWidget {
  const PemanduanPage({super.key});

  @override
  State<PemanduanPage> createState() => _PemanduanPageState();
}

class _PemanduanPageState extends State<PemanduanPage> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();

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

  final String baseUrl = 'http://192.168.0.9/pilotage_and_assistance_app/api';
  // final String baseUrl = 'http://192.168.1.15/pilotage_and_assistance_app/api';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load user role from SharedPreferences
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('user_role') ?? '';
    });
  }

  // Check if user is admin
  bool get _isAdmin => _userRole.toLowerCase() == 'admin';

  Future<void> _loadData() async {
    await Future.wait([_fetchPilotages(), _fetchStats()]);
  }

  Future<void> _fetchPilotages() async {
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('$baseUrl/get_pilotages.php').replace(
        queryParameters: {
          'status': _selectedFilter != 'Semua' ? _selectedFilter : '',
          'search': _searchController.text,
          'page': _currentPage.toString(),
          'limit': _rowsPerPage.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          setState(() {
            _pemanduanList = List<Map<String, dynamic>>.from(
              result['data'] ?? [],
            );
            _totalData = result['total'] ?? 0;
            _totalPages = _totalData > 0
                ? ((_totalData / _rowsPerPage).ceil())
                : 1;
            _isLoading = false;
          });
        } else {
          throw Exception(result['message'] ?? 'Failed to load data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      // Get today's date in YYYY-MM-DD format
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_pilotages_stats.php',
        ).replace(queryParameters: {'date': todayStr}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          final data = result['data'];

          setState(() {
            _stats = {
              'total': (data['total'] ?? 0).toString(),
              'active': (data['active'] ?? 0).toString(),
              'completed': (data['completed'] ?? 0).toString(),
              'scheduled': (data['scheduled'] ?? 0).toString(),
            };
          });
        } else {
          setState(() {
            _stats = {
              'total': '0',
              'active': '0',
              'completed': '0',
              'scheduled': '0',
            };
          });
        }
      }
    } catch (e) {
      setState(() {
        _stats = {
          'total': '0',
          'active': '0',
          'completed': '0',
          'scheduled': '0',
        };
      });
    }
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() => _currentPage = page);
      _fetchPilotages();
    }
  }

  void _changeRowsPerPage(int? newRowsPerPage) {
    if (newRowsPerPage != null) {
      setState(() {
        _rowsPerPage = newRowsPerPage;
        _currentPage = 1;
      });
      _fetchPilotages();
    }
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
      final response = await http.post(
        Uri.parse('$baseUrl/update_pilotages.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      final result = jsonDecode(response.body);

      if (result['status'] == 'success') {
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil diupdate!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['message']);
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

  Future<void> _deletePilotages(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_pilotages.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );

      final result = jsonDecode(response.body);

      if (result['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil dihapus!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _loadData();
      } else {
        throw Exception(result['message']);
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
      backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
      body: Stack(
        children: [
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color.fromRGBO(12, 10, 80, 1),
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Pemanduan & Penundaan",
                        style: TextStyle(
                          color: Color.fromRGBO(12, 10, 80, 1),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      // Show role badge
                      if (_userRole.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isAdmin
                                ? Colors.red[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                size: 16,
                                color: _isAdmin
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _userRole,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isAdmin
                                      ? Colors.red[700]
                                      : Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadData,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  String _formatDate(String? date) {
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

  String _formatTimeOnly(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '- (LT)';
    try {
      final dt = DateTime.parse(dateTime);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm (LT)';
    } catch (e) {
      return '$dateTime (LT)';
    }
  }

  String _formatMultipleValues(String value) {
    if (value.isEmpty || value == '-') return '-';
    // Split by comma and format each value
    final values = value.split(',');
    if (values.length <= 1) return value;
    return values.map((v) => v.trim()).join('\n');
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
                DataCell(Text(data['id']?.toString() ?? '-')),
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
                      // Tombol Delete hanya muncul untuk Admin
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showDeleteConfirmation(context, data['id']),
                          tooltip: 'Hapus',
                        )
                      else
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
                    'ID: ${data['id']}',
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
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showDetailDialog(context, data),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Detail'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditDialog(context, data),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                  // Tombol Delete hanya untuk Admin
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: () =>
                          _showDeleteConfirmation(context, data['id']),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Hapus'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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
        title: Text('Detail Pemanduan ID: ${data['id']}'),
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
                'Pandu Selesai',
                _formatTimeOnly(data['pilot_finished']),
              ),
              _buildDetailRow(
                'Kapal Bergerak',
                _formatTimeOnly(data['vessel_start']),
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

    // Time Controllers
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

    String selectedStatus = data['status'] ?? 'Terjadwal';

    String selectedDirection;
    final jettyController = TextEditingController();

    if (data['from_where'] == 'Laut') {
      selectedDirection = 'IN';
      jettyController.text = data['to_where'] ?? '';
    } else {
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

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text('Edit Pemanduan ID: ${data['id']}'),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vessel Type Selection
                    const Text(
                      'Tipe Kapal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Motor'),
                            value: 'Motor',
                            groupValue: vesselType,
                            onChanged: (value) {
                              setDialogState(() {
                                vesselType = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Tug'),
                            value: 'Tug',
                            groupValue: vesselType,
                            onChanged: (value) {
                              setDialogState(() {
                                vesselType = value!;
                              });
                            },
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Vessel Name Fields
                    if (vesselType == 'Motor') ...[
                      TextField(
                        controller: vesselController,
                        decoration: InputDecoration(
                          labelText: 'Nama Kapal',
                          border: const OutlineInputBorder(),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: tugNameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Tug',
                                border: const OutlineInputBorder(),
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: bargeNameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Tongkang',
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
                            ),
                          ),
                        ],
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
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
                            setDialogState(() {
                              if (selected) {
                                selectedAssistTugs.add(Map.from(tug));
                              } else {
                                selectedAssistTugs.removeWhere(
                                  (selectedTug) =>
                                      selectedTug['name'] == tug['name'],
                                );
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
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
                    'id': data['id'],
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
                  };

                  // Add time fields if status is Aktif or Selesai
                  if (selectedStatus == 'Aktif' ||
                      selectedStatus == 'Selesai') {
                    final eventDate =
                        data['date'] ??
                        DateTime.now().toIso8601String().split('T')[0];
                    updateData['pilot_on_board'] =
                        pilotOnBoardController.text.isNotEmpty
                        ? '${eventDate}T${pilotOnBoardController.text.replaceAll(' (LT)', '')}:00'
                        : null;
                    updateData['pilot_finished'] =
                        pilotFinishedController.text.isNotEmpty
                        ? '${eventDate}T${pilotFinishedController.text.replaceAll(' (LT)', '')}:00'
                        : null;
                    updateData['vessel_start'] =
                        vesselStartController.text.isNotEmpty
                        ? '${eventDate}T${vesselStartController.text.replaceAll(' (LT)', '')}:00'
                        : null;
                    updateData['pilot_get_off'] =
                        pilotGetOffController.text.isNotEmpty
                        ? '${eventDate}T${pilotGetOffController.text.replaceAll(' (LT)', '')}:00'
                        : null;
                  }

                  // Call update function
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

  void _showDeleteConfirmation(BuildContext context, int id) {
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
