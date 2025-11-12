import 'package:flutter/material.dart';

class PemanduanPage extends StatefulWidget {
  const PemanduanPage({super.key});

  @override
  State<PemanduanPage> createState() => _PemanduanPageState();
}

class _PemanduanPageState extends State<PemanduanPage> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();

  // Dummy data sesuai struktur database
  final List<Map<String, dynamic>> _pemanduanList = [
    {
      'id': 1,
      'pilot_name': 'Capt. Ahmad',
      'from_where': 'Pelabuhan Dumai',
      'to_where': 'Singapura',
      'pilot_on_board': '2025-11-09 10:00:00',
      'pilot_finished': '2025-11-09 14:00:00',
      'tanggal': '2025-11-09',
      'vessel_start': '2025-11-09 09:45:00',
      'pilot_get_off': '2025-11-09 14:15:00',
      'vessel_name': 'MV Ocean Star',
      'status': 'Aktif',
    },
    {
      'id': 2,
      'pilot_name': 'Capt. Budi',
      'from_where': 'Singapura',
      'to_where': 'Pelabuhan Dumai',
      'pilot_on_board': '2025-11-09 14:30:00',
      'pilot_finished': null,
      'tanggal': '2025-11-09',
      'vessel_start': '2025-11-09 14:15:00',
      'pilot_get_off': null,
      'vessel_name': 'MT Marine Tanker',
      'status': 'Terjadwal',
    },
    {
      'id': 3,
      'pilot_name': 'Capt. Chandra',
      'from_where': 'Pelabuhan Dumai',
      'to_where': 'Malaysia',
      'pilot_on_board': '2025-11-09 08:00:00',
      'pilot_finished': '2025-11-09 12:00:00',
      'tanggal': '2025-11-09',
      'vessel_start': '2025-11-09 07:45:00',
      'pilot_get_off': '2025-11-09 12:15:00',
      'vessel_name': 'MV Cargo Express',
      'status': 'Selesai',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isLargeScreen = width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // ✅ Body Content
          Positioned.fill(
            top: 100,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Dashboard Cards
                  isLargeScreen
                      ? Row(
                          children: [
                            Expanded(child: _buildStatCard('Total Hari Ini', '12', Icons.assessment, Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildStatCard('Aktif', '3', Icons.sailing, Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildStatCard('Selesai', '7', Icons.check_circle, Colors.green)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildStatCard('Terjadwal', '2', Icons.schedule, Colors.purple)),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildStatCard('Total Hari Ini', '12', Icons.assessment, Colors.blue)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatCard('Aktif', '3', Icons.sailing, Colors.orange)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildStatCard('Selesai', '7', Icons.check_circle, Colors.green)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatCard('Terjadwal', '2', Icons.schedule, Colors.purple)),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 30),

                  // ✅ Search & Filter Bar
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
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
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
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

                  // ✅ Daftar Pemanduan
                  const Text(
                    'Daftar Pemanduan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(12, 10, 80, 1),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ Table/Cards
                  isLargeScreen ? _buildTable() : _buildCardList(),
                ],
              ),
            ),
          ),

          // ✅ Navbar
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

  // ✅ Stat Card Widget
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

  // Helper: Format DateTime
  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return '-';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return date;
    }
  }

  // ✅ Table untuk Desktop
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
              DataCell(Text(_formatDate(data['tanggal']), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_formatDateTime(data['pilot_on_board']), style: const TextStyle(fontSize: 12))),
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
                      onPressed: () => _showDeleteConfirmation(context, data['id'].toString()),
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

  // ✅ Card List untuk Mobile
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
                      '${data['from_where']} → ${data['to_where']}',
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
                    _formatDateTime(data['pilot_on_board']),
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

  // ✅ Status Badge
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

  // ✅ Dialog Tambah Pemanduan
  void _showAddPemanduanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Pemanduan Baru'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Nama Kapal')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Nama Pandu')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Dari (Pelabuhan)')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Ke (Pelabuhan)')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Tanggal')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Waktu Pilot On Board')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pemanduan berhasil ditambahkan!')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ✅ Dialog Detail
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
              _buildDetailRow('Tanggal', _formatDate(data['tanggal'])),
              _buildDetailRow('Pilot On Board', _formatDateTime(data['pilot_on_board'])),
              _buildDetailRow('Pilot Finished', _formatDateTime(data['pilot_finished'])),
              _buildDetailRow('Vessel Start', _formatDateTime(data['vessel_start'])),
              _buildDetailRow('Pilot Get Off', _formatDateTime(data['pilot_get_off'])),
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

  // ✅ Dialog Edit
  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Pemanduan ID: ${data['id']}'),
        content: const Text('Form edit akan ditampilkan di sini'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data berhasil diupdate!')),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ✅ Konfirmasi Hapus
  void _showDeleteConfirmation(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pemanduan'),
        content: Text('Apakah Anda yakin ingin menghapus pemanduan ID: $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data berhasil dihapus!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}