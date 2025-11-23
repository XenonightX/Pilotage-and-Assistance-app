import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pilotage_and_assistance_app/pages/penundaan/tambah_penundaan_page.dart';

class PenundaanPage extends StatefulWidget {
  const PenundaanPage({super.key});

  @override
  State<PenundaanPage> createState() => _PenundaanPageState();
}

class _PenundaanPageState extends State<PenundaanPage> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _penundaanList = [];
  bool _isLoading = true;
  
  Map<String, dynamic> _stats = {
    'total': '0',
    'menunggu': '0',
    'diproses': '0',
    'selesai': '0'
  };

  final String baseUrl = 'http://192.168.1.20/pilotage_and_assistance_app/api';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _fetchPenundaan(),
      _fetchStats(),
    ]);
  }

  Future<void> _fetchPenundaan() async {
    setState(() => _isLoading = true);
    
    try {
      final uri = Uri.parse('$baseUrl/get_assistances.php').replace(queryParameters: {
        'status': _selectedFilter != 'Semua' ? _selectedFilter : '',
        'search': _searchController.text,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          setState(() {
            _penundaanList = List<Map<String, dynamic>>.from(result['data']);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_assistances_stats.php'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          final data = result['data'];
          
          setState(() {
            _stats = {
              'total': (data['total'] ?? 0).toString(),
              'menunggu': (data['menunggu'] ?? 0).toString(),
              'diproses': (data['diproses'] ?? 0).toString(),
              'selesai': (data['selesai'] ?? 0).toString(),
            };
          });
        }
      }
    } catch (e) {
      setState(() {
        _stats = {
          'total': '0',
          'menunggu': '0',
          'diproses': '0',
          'selesai': '0'
        };
      });
    }
  }

  Future<void> _deletePenundaan(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_assistances.php'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus data: $e')),
        );
      }
    }
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
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          isLargeScreen
                              ? Row(
                                  children: [
                                    Expanded(child: _buildStatCard('Total Penundaan', _stats['total']!, Icons.assessment, Colors.blue)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Menunggu', _stats['menunggu']!, Icons.access_time, Colors.orange)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Diproses', _stats['diproses']!, Icons.loop, Colors.purple)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Selesai', _stats['selesai']!, Icons.check_circle, Colors.green)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard('Total', _stats['total']!, Icons.assessment, Colors.blue)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Menunggu', _stats['menunggu']!, Icons.access_time, Colors.orange)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard('Diproses', _stats['diproses']!, Icons.loop, Colors.purple)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Selesai', _stats['selesai']!, Icons.check_circle, Colors.green)),
                                      ],
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 30),

                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isLargeScreen ? 400 : double.infinity,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama kapal...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (_searchController.text == value) {
                                        _fetchPenundaan();
                                      }
                                    });
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedFilter,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.filter_list),
                                  items: ['Semua', 'Menunggu', 'Diproses', 'Selesai']
                                      .map((filter) => DropdownMenuItem(
                                            value: filter,
                                            child: Text(filter),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedFilter = value!);
                                    _fetchPenundaan();
                                  },
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TambahPenundaanPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadData();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 225, 109, 0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daftar Penundaan',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                              Text(
                                '${_penundaanList.length} data',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _penundaanList.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tidak ada data',
                                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : (isLargeScreen ? _buildTable() : _buildCardList()),
                        ],
                      ),
                    ),
                  ),
          ),

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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        "Penundaan",
                        style: TextStyle(
                          color: Color.fromRGBO(12, 10, 80, 1),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return date;
    }
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
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Nama Kapal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Call Sign', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Bendera', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GT', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('LOA', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Keagenan', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Alasan', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _penundaanList.map((data) {
            return DataRow(cells: [
              DataCell(Text(data['id'].toString())),
              DataCell(Text(data['vessel_name'] ?? '-')),
              DataCell(Text(data['call_sign'] ?? '-')),
              DataCell(Text(data['flag'] ?? '-')),
              DataCell(Text(data['gross_tonnage'] ?? '-')),
              DataCell(Text(data['loa'] != null ? '${data['loa']} m' : '-')),
              DataCell(Text(data['agency'] ?? '-')),
              DataCell(Text(_formatDate(data['assistance_date']))),
              DataCell(Text(data['reason'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(_buildStatusBadge(data['status'] ?? 'Menunggu')),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                      onPressed: () => _showDetailDialog(context, data),
                      tooltip: 'Lihat Detail',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _showDeleteConfirmation(context, data['id']),
                      tooltip: 'Hapus',
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardList() {
    return Column(
      children: _penundaanList.map((data) {
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
                  _buildStatusBadge(data['status'] ?? 'Menunggu'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['vessel_name'] ?? '-',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Keagenan: ${data['agency'] ?? '-'}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(data['assistance_date'] ?? '-'),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Alasan: ${data['reason'] ?? '-'}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    onPressed: () => _showDeleteConfirmation(context, data['id']),
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
      case 'Menunggu':
        color = Colors.orange;
        break;
      case 'Diproses':
        color = Colors.purple;
        break;
      case 'Selesai':
        color = Colors.green;
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
        title: Text('Detail Penundaan ID: ${data['id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nama Kapal', data['vessel_name'] ?? '-'),
              _buildDetailRow('Call Sign', data['call_sign'] ?? '-'),
              _buildDetailRow('Nama Nahkoda', data['master_name'] ?? '-'),
              _buildDetailRow('Bendera', data['flag'] ?? '-'),
              _buildDetailRow('Gross Tonnage', data['gross_tonnage'] ?? '-'),
              _buildDetailRow('Keagenan', data['agency'] ?? '-'),
              _buildDetailRow('LOA', data['loa'] != null ? '${data['loa']} m' : '-'),
              const Divider(height: 24),
              _buildDetailRow('Tanggal Penundaan', _formatDate(data['assistance_date'])),
              _buildDetailRow('Alasan Penundaan', data['reason'] ?? '-'),
              _buildDetailRow('Keterangan', data['notes'] ?? '-'),
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
            width: 150,
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

  void _showDeleteConfirmation(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePenundaan(id);
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