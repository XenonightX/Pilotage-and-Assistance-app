import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    'scheduled': '0'
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
      _fetchPilotages(),
      _fetchStats(),
    ]);
  }

  Future<void> _fetchPilotages() async {
    setState(() => _isLoading = true);
    
    try {
      final uri = Uri.parse('$baseUrl/get_pilotages.php').replace(queryParameters: {
        'status': _selectedFilter != 'Semua' ? _selectedFilter : '',
        'search': _searchController.text,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['status'] == 'success') {
          setState(() {
            _pemanduanList = List<Map<String, dynamic>>.from(result['data']);
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
      final response = await http.get(Uri.parse('$baseUrl/get_pilotages_stats.php'));

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
              'scheduled': '0'
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
          'scheduled': '0'
        };
      });
    }
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
                                    Expanded(child: _buildStatCard('Total Pemanduan', _stats['total']!, Icons.assessment, Colors.blue)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Aktif', _stats['active']!, Icons.sailing, Colors.orange)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Selesai', _stats['completed']!, Icons.check_circle, Colors.green)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildStatCard('Terjadwal', _stats['scheduled']!, Icons.schedule, Colors.purple)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard('Total Pemanduan', _stats['total']!, Icons.assessment, Colors.blue)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Aktif', _stats['active']!, Icons.sailing, Colors.orange)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCard('Selesai', _stats['completed']!, Icons.check_circle, Colors.green)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildStatCard('Terjadwal', _stats['scheduled']!, Icons.schedule, Colors.purple)),
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
                                    hintText: 'Cari nama kapal atau nama pandu...',
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
                                        _fetchPilotages();
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
                                  items: ['Semua', 'Aktif', 'Terjadwal', 'Selesai']
                                      .map((filter) => DropdownMenuItem(
                                            value: filter,
                                            child: Text(filter),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedFilter = value!);
                                    _fetchPilotages();
                                  },
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TambahPemanduanPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadData(); // Refresh data setelah berhasil tambah
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
                                'Daftar Pemanduan',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                              Text(
                                '${_pemanduanList.length} data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFF4F6FA),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _pemanduanList.isEmpty
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
                        "Pemanduan",
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

  String _formatTimeOnly(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
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
            DataColumn(label: Text('Nama Nahkoda', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Bendera', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GT Tug  / Tongkang', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Keagenan', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('LOA Tug / Tongkang', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Sarat Muka', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Sarat Belakang', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pandu', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Arah', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pelabuhan Asal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pelabuhan Tujuan', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pilot On Board', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _pemanduanList.map((data) {
            return DataRow(cells: [
              DataCell(Text(data['id'].toString())),
              DataCell(Text(data['vessel_name'] ?? '-')),
              DataCell(Text(data['call_sign'] ?? '-')),
              DataCell(Text(data['master_name'] ?? '-')),
              DataCell(Text(data['flag'] ?? '-')),
              DataCell(Text('${data['gross_tonnage'] ?? '-'}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['agency'] ?? '-')),
              DataCell(Text(data['loa'] != null ? '${data['loa']} m' : '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['fore_draft'] != null ? '${data['fore_draft']} m' : '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['aft_draft'] != null ? '${data['aft_draft']} m' : '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['pilot_name'] ?? '-')),
              DataCell(Text('${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['last_port'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['next_port'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(_formatDate(data['date']), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_formatTimeOnly(data['pilot_on_board']), style: const TextStyle(fontSize: 12))),
              DataCell(_buildStatusBadge(data['status'] ?? 'Terjadwal')),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                      onPressed: () => _showDetailDialog(context, data),
                      tooltip: 'Lihat Detail',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                      onPressed: () => _showEditDialog(context, data),
                      tooltip: 'Edit',
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
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
              _buildDetailRow('Gross Tonnage', data['gross_tonnage'] ?? '-'),
              _buildDetailRow('Keagenan', data['agency'] ?? '-'),
              _buildDetailRow('LOA', data['loa'] != null ? '${data['loa']} m' : '-'),
              _buildDetailRow('Sarat Muka', data['fore_draft'] != null ? '${data['fore_draft']} m' : '-'),
              _buildDetailRow('Sarat Belakang', data['aft_draft'] != null ? '${data['aft_draft']} m' : '-'),
              const Divider(height: 24),
              _buildDetailRow('Pandu', data['pilot_name'] ?? '-'),
              _buildDetailRow('Arah Pemanduan', '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}'),
              _buildDetailRow('Pelabuhan Asal', data['last_port'] ?? '-'),
              _buildDetailRow('Pelabuhan Tujuan', data['next_port'] ?? '-'),
              _buildDetailRow('Tanggal', _formatDate(data['date'])),
              _buildDetailRow('Pandu Naik kapal', _formatTimeOnly(data['pilot_on_board'])),
              _buildDetailRow('Pandu Selesai', _formatTimeOnly(data['pilot_finished'])),
              _buildDetailRow('Kapal Bergerak', _formatTimeOnly(data['vessel_start'])),
              _buildDetailRow('Pandu Turun', _formatTimeOnly(data['pilot_get_off'])),
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
  // Parse vessel name untuk menentukan jenis kapal
  final vesselNameParts = (data['vessel_name'] ?? '').split('/');
  final String vesselType = vesselNameParts.length > 1 ? 'Tug' : 'Motor'; // FINAL - tidak bisa diubah
  
  // Controllers
  final vesselController = TextEditingController(
    text: vesselType == 'Motor' ? data['vessel_name'] : ''
  );
  final tugNameController = TextEditingController(
    text: vesselType == 'Tug' && vesselNameParts.isNotEmpty ? vesselNameParts[0] : ''
  );
  final bargeNameController = TextEditingController(
    text: vesselType == 'Tug' && vesselNameParts.length > 1 ? vesselNameParts[1] : ''
  );
  final callSignController = TextEditingController(text: data['call_sign'] ?? '');
  final masterController = TextEditingController(text: data['master_name'] ?? '');
  final flagController = TextEditingController(text: data['flag'] ?? '');
  
  // Parse GT
  final gtParts = (data['gross_tonnage'] ?? '').split('/');
  final gtTugController = TextEditingController(text: gtParts.isNotEmpty ? gtParts[0].trim() : '');
  final gtBargeController = TextEditingController(text: gtParts.length > 1 ? gtParts[1].trim() : '');
  
  final agencyController = TextEditingController(text: data['agency'] ?? '');
  
  // Parse LOA
  final loaParts = (data['loa'] ?? '').split('/');
  final loaTugController = TextEditingController(text: loaParts.isNotEmpty ? loaParts[0].trim() : '');
  final loaBargeController = TextEditingController(text: loaParts.length > 1 ? loaParts[1].trim() : '');
  
  final foredraftController = TextEditingController(text: data['fore_draft'] ?? '');
  final aftdraftController = TextEditingController(text: data['aft_draft'] ?? '');
  final pilotController = TextEditingController(text: data['pilot_name'] ?? '');
  final lastPortController = TextEditingController(text: data['last_port'] ?? '');
  final nextPortController = TextEditingController(text: data['next_port'] ?? '');
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

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('Edit Pemanduan ID: ${data['id']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Jenis Kapal (Read-only, tidak bisa diubah)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        vesselType == 'Motor' ? Icons.directions_boat : Icons.anchor,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jenis Kapal: ${vesselType == 'Motor' ? 'Kapal Motor' : 'Tug & Tongkang'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Data Kapal Section
                Text(
                  'Data Kapal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Conditional: Nama Kapal Motor atau Tug & Tongkang
                if (vesselType == 'Motor') ...[
                  TextField(
                    controller: vesselController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kapal Motor *',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.directions_boat),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: tugNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Tug Boat *',
                      hintText: 'Contoh: TB. Bintang Laut',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.directions_boat),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bargeNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Tongkang *',
                      hintText: 'Contoh: BG. Jaya 01',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.anchor),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                
                TextField(
                  controller: callSignController,
                  decoration: InputDecoration(
                    labelText: vesselType == 'Motor'
                        ? 'Call Sign / Nama Panggilan *'
                        : 'Call Sign / Nama Panggilan',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.radio),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: masterController,
                  decoration: InputDecoration(
                    labelText: vesselType == 'Motor'
                        ? 'Nama Nahkoda *'
                        : 'Nama Nahkoda',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: flagController,
                  decoration: const InputDecoration(
                    labelText: 'Bendera Kapal *',
                    hintText: 'Contoh: Indonesia, Singapore',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.flag),
                  ),
                ),
                const SizedBox(height: 16),

                // Gross Tonnage Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.scale, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Gross Tonnage (GT)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: gtTugController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: vesselType == 'Motor' ? 'GT Kapal Motor *' : 'GT Tug Boat *',
                          hintText: vesselType == 'Motor' ? 'Masukkan GT Kapal' : 'Masukkan GT Tug Boat',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.directions_boat),
                        ),
                      ),
                      if (vesselType == 'Tug') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: gtBargeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'GT Tongkang *',
                            hintText: 'Masukkan GT Tongkang',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.anchor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: agencyController,
                  decoration: const InputDecoration(
                    labelText: 'Keagenan Kapal *',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 16),

                // LOA Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 18, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Panjang Kapal (LOA)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: loaTugController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: vesselType == 'Motor' ? 'LOA Kapal Motor (meter) *' : 'LOA Tug Boat (meter) *',
                          hintText: vesselType == 'Motor' ? 'Panjang Kapal' : 'Panjang Tug Boat',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.directions_boat),
                          suffixText: 'm',
                        ),
                      ),
                      if (vesselType == 'Tug') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: loaBargeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'LOA Tongkang (meter) *',
                            hintText: 'Panjang Tongkang',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.anchor),
                            suffixText: 'm',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: foredraftController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sarat Muka (meter)',
                    hintText: 'Opsional',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: aftdraftController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sarat Belakang (meter)',
                    hintText: 'Opsional',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
                const SizedBox(height: 20),

                // Informasi Pemanduan Section
                Text(
                  'Informasi Pemanduan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: pilotController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pandu *',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  value: selectedDirection,
                  decoration: const InputDecoration(
                    labelText: 'Arah Pemanduan *',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.swap_horiz),
                  ),
                  items: ['IN', 'OUT']
                      .map((direction) => DropdownMenuItem(
                            value: direction,
                            child: Text(direction == 'IN' 
                              ? 'IN (Masuk dari Laut ke Jetty)' 
                              : 'OUT (Keluar dari Jetty ke Laut)'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDirection = value!;
                      jettyController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: jettyController,
                  decoration: InputDecoration(
                    labelText: 'Nama Jetty *',
                    hintText: selectedDirection == 'IN' 
                      ? 'Jetty tujuan (contoh: Jetty Batu Ampar)' 
                      : 'Jetty asal (contoh: Jetty Batu Ampar)',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.anchor),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: lastPortController,
                  decoration: const InputDecoration(
                    labelText: 'Pelabuhan Asal *',
                    hintText: 'Contoh: Singapore, Jakarta',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: nextPortController,
                  decoration: const InputDecoration(
                    labelText: 'Pelabuhan Tujuan *',
                    hintText: 'Contoh: Batam, Singapore',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.place),
                  ),
                ),
                const SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status *',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: ['Terjadwal', 'Aktif', 'Selesai']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Validasi
                if (jettyController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama Jetty wajib diisi!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Tentukan from_where dan to_where
                String fromWhere, toWhere;
                if (selectedDirection == 'IN') {
                  fromWhere = 'Laut';
                  toWhere = jettyController.text.trim();
                } else {
                  fromWhere = jettyController.text.trim();
                  toWhere = 'Laut';
                }

                // Format vessel_name (TIDAK BISA DIUBAH JENISNYA)
                String vesselName;
                if (vesselType == 'Motor') {
                  vesselName = vesselController.text.trim();
                } else {
                  vesselName = tugNameController.text.trim();
                  if (bargeNameController.text.trim().isNotEmpty) {
                    vesselName += '/${bargeNameController.text.trim()}';
                  }
                }

                // Format GT
                String grossTonnage = gtTugController.text.trim();
                if (vesselType == 'Tug' && gtBargeController.text.trim().isNotEmpty) {
                  grossTonnage += '/${gtBargeController.text.trim()}';
                }
                
                // Format LOA
                String loa = loaTugController.text.trim();
                if (vesselType == 'Tug' && loaBargeController.text.trim().isNotEmpty) {
                  loa += '/${loaBargeController.text.trim()}';
                }

                final updateData = {
                  "id": data['id'],
                  "vessel_name": vesselName,
                  "call_sign": callSignController.text.isEmpty ? null : callSignController.text,
                  "master_name": masterController.text.isEmpty ? null : masterController.text,
                  "flag": flagController.text,
                  "gross_tonnage": grossTonnage,
                  "agency": agencyController.text,  
                  "loa": loa,
                  "fore_draft": foredraftController.text.isEmpty ? null : foredraftController.text,
                  "aft_draft": aftdraftController.text.isEmpty ? null : aftdraftController.text,
                  "pilot_name": pilotController.text,
                  "from_where": fromWhere,
                  "to_where": toWhere,
                  "last_port": lastPortController.text,
                  "next_port": nextPortController.text,
                  "date": data['date'],
                  "pilot_on_board": data['pilot_on_board'],
                  "pilot_finished": data['pilot_finished'],
                  "vessel_start": data['vessel_start'],
                  "pilot_get_off": data['pilot_get_off'],
                  "status": selectedStatus,
                };
                
                Navigator.pop(context);
                await _updatePilotages(updateData);
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