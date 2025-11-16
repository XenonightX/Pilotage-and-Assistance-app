import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pilotage_and_assistance_app/utils/user_session.dart';

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

      print('📋 Pilotages Response: ${response.statusCode}');
      print('📋 Pilotages Body: ${response.body}');

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
      print('❌ Error fetching pilotages: $e');
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
      final response = await http.get(Uri.parse('$baseUrl/get_stats.php'));

      print('📊 Stats Response Status: ${response.statusCode}');
      print('📊 Stats Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        print('📊 Decoded Result: $result');
        
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
          
          print('✅ Stats berhasil diupdate: $_stats');
        } else {
          print('⚠️ API returned error: ${result['message']}');
          
          setState(() {
            _stats = {
              'total': '0',
              'active': '0',
              'completed': '0',
              'scheduled': '0'
            };
          });
        }
      } else {
        print('❌ Server error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching stats: $e');
      
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

  Future<void> _addPilotages(Map<String, dynamic> data) async {
    try {
      print('🚀 Sending data: $data');
      
      final response = await http.post(
        Uri.parse('$baseUrl/add_pilotages.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      print('📥 Add Response: ${response.body}');
      final result = jsonDecode(response.body);

      if (result['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadData();
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      print('❌ Error add: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan data: $e')),
        );
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil diupdate!'),
              backgroundColor: Colors.green,
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
          SnackBar(content: Text('Gagal mengupdate data: $e')),
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
      backgroundColor: const Color(0xFFF4F6FA),
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
                                onPressed: () => _showAddPemanduanDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
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
                                  color: Color.fromRGBO(12, 10, 80, 1),
                                ),
                              ),
                              Text(
                                '${_pemanduanList.length} data',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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
            DataColumn(label: Text('Pandu', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Dari', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Ke', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Pilot On Board', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _pemanduanList.map((data) {
            return DataRow(cells: [
              DataCell(Text(data['id'].toString())),
              DataCell(Text(data['vessel_name'] ?? '-')),
              DataCell(Text(data['pilot_name'] ?? '-')),
              DataCell(Text(data['from_where'] ?? '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text(data['to_where'] ?? '-', style: const TextStyle(fontSize: 12))),
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
                'Pandu: ${data['pilot_name'] ?? '-'}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.route, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${data['from_where'] ?? '-'} → ${data['to_where'] ?? '-'}',
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
                    _formatTimeOnly(data['pilot_on_board']),
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

  void _showAddPemanduanDialog(BuildContext context) {
    final vesselController = TextEditingController();
    final pilotController = TextEditingController(text: UserSession.userName ?? '');
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final bool isPilot = UserSession.isPilot();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Tambah Pemanduan Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: vesselController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kapal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_boat),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pilotController,
                    readOnly: isPilot,
                    decoration: InputDecoration(
                      labelText: 'Nama Pandu',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                      filled: isPilot,
                      fillColor: isPilot ? Colors.grey[200] : null,
                      suffixIcon: isPilot ? const Icon(Icons.lock, size: 18, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromController,
                    decoration: const InputDecoration(
                      labelText: 'Dari (Pelabuhan)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toController,
                    decoration: const InputDecoration(
                      labelText: 'Ke (Pelabuhan)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      hintText: 'Pilih tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color.fromRGBO(0, 40, 120, 1),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                          final displayDate = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                          dateController.text = displayDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Waktu Pilot On Board',
                      hintText: 'Pilih waktu',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color.fromRGBO(0, 40, 120, 1),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                          final hour = picked.hour.toString().padLeft(2, '0');
                          final minute = picked.minute.toString().padLeft(2, '0');
                          timeController.text = '$hour:$minute';
                        });
                      }
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
                  if (vesselController.text.isEmpty || 
                      pilotController.text.isEmpty || 
                      fromController.text.isEmpty || 
                      toController.text.isEmpty || 
                      selectedDate == null || 
                      selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Semua field harus diisi!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // ✅ PENTING: Gunakan "date" bukan "tanggal" agar konsisten dengan get_stats.php
                  final dbDate = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                  final dbTime = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

                  final data = {
                    "vessel_name": vesselController.text,
                    "pilot_name": pilotController.text,
                    "from_where": fromController.text,
                    "to_where": toController.text,
                    "date": dbDate,  // ✅ Gunakan "date"
                    "pilot_on_board": '$dbDate $dbTime',
                    "status": "Terjadwal",
                  };
                  
                  print('📤 Data yang dikirim: $data');
                  
                  Navigator.pop(context);
                  await _addPilotages(data);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
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
              _buildDetailRow('Pandu', data['pilot_name'] ?? '-'),
              _buildDetailRow('Dari', data['from_where'] ?? '-'),
              _buildDetailRow('Ke', data['to_where'] ?? '-'),
              _buildDetailRow('Tanggal', _formatDate(data['date'])),
              _buildDetailRow('Pilot On Board', _formatTimeOnly(data['pilot_on_board'])),
              _buildDetailRow('Pilot Finished', _formatTimeOnly(data['pilot_finished'])),
              _buildDetailRow('Vessel Start', _formatTimeOnly(data['vessel_start'])),
              _buildDetailRow('Pilot Get Off', _formatTimeOnly(data['pilot_get_off'])),
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
            width: 120,
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
    final vesselController = TextEditingController(text: data['vessel_name']);
    final pilotController = TextEditingController(text: data['pilot_name']);
    final fromController = TextEditingController(text: data['from_where']);
    final toController = TextEditingController(text: data['to_where']);
    String selectedStatus = data['status'] ?? 'Terjadwal';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Pemanduan ID: ${data['id']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: vesselController,
                    decoration: const InputDecoration(labelText: 'Nama Kapal'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pilotController,
                    decoration: const InputDecoration(labelText: 'Nama Pandu'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromController,
                    decoration: const InputDecoration(labelText: 'Dari (Pelabuhan)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: toController,
                    decoration: const InputDecoration(labelText: 'Ke (Pelabuhan)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
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
                onPressed: () async {
                  final updateData = {
                    "id": data['id'],
                    "vessel_name": vesselController.text,
                    "pilot_name": pilotController.text,
                    "from_where": fromController.text,
                    "to_where": toController.text,
                    "date": data['date'],  // ✅ Gunakan "date"
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