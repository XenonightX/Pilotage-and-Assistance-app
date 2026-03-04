import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pilotage_and_assistance_app/pages/profile/profile_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../pages/pemanduan/pemanduan_page.dart';

import '../../../pages/login/login_page.dart';

class ResponsiveNavBarPage extends StatefulWidget {
  const ResponsiveNavBarPage({super.key});

  @override
  State<ResponsiveNavBarPage> createState() => _ResponsiveNavBarPageState();
}

class _ResponsiveNavBarPageState extends State<ResponsiveNavBarPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final String _baseUrl = 'http://192.168.1.18/pilotage_and_assistance_app/api';
  String _userName = 'User';
  bool? _isDashboardLoading = true;

  Map<String, int>? _stats = {
    'total': 0,
    'active': 0,
    'completed': 0,
    'scheduled': 0,
  };

  List<Map<String, dynamic>>? _recentActivities = [];

  Map<String, int> get _safeStats => _stats ?? const {
        'total': 0,
        'active': 0,
        'completed': 0,
        'scheduled': 0,
      };

  List<Map<String, dynamic>> get _safeRecentActivities =>
      _recentActivities ?? const [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDashboard();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
    });
  }

  Future<int> _fetchCountByStatus(String status) async {
    final queryParams = <String, String>{'page': '1', 'limit': '1'};
    if (status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$_baseUrl/get_pilotages.php',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    if (result['status'] != 'success') {
      throw Exception(result['message'] ?? 'Gagal mengambil statistik');
    }

    return result['total'] ?? 0;
  }

  Future<List<Map<String, dynamic>>> _fetchRecentActivities() async {
    final uri = Uri.parse('$_baseUrl/get_pilotages.php').replace(
      queryParameters: {'page': '1', 'limit': '5'},
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final result = jsonDecode(response.body);
    if (result['status'] != 'success') {
      throw Exception(result['message'] ?? 'Gagal mengambil data kegiatan');
    }

    return List<Map<String, dynamic>>.from(result['data'] ?? []);
  }

  Future<void> _loadDashboard() async {
    setState(() => _isDashboardLoading = true);

    try {
      final values = await Future.wait([
        _fetchCountByStatus(''),
        _fetchCountByStatus('Aktif'),
        _fetchCountByStatus('Selesai'),
        _fetchCountByStatus('Terjadwal'),
        _fetchRecentActivities(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = {
          'total': values[0] as int,
          'active': values[1] as int,
          'completed': values[2] as int,
          'scheduled': values[3] as int,
        };
        _recentActivities = values[4] as List<Map<String, dynamic>>;
        _isDashboardLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDashboardLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif':
        return Colors.orange;
      case 'Selesai':
        return Colors.green;
      case 'Terjadwal':
      default:
        return const Color.fromRGBO(0, 40, 120, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isLargeScreen = width > 800;

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
        body: Stack(
          children: [
            // ✅ Body di bawah navbar
            Positioned.fill(
              top: 100, // beri jarak agar tidak tertutup navbar
              child: _buildDashboardBody(),
            ),

            // ✅ Navbar tetap di atas
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100, // 🔥 lebih tinggi biar terlihat lebar & lega
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ✅ Kiri: Logo + Nama / tombol menu (untuk HP)
                        Row(
                          children: [
                            if (!isLargeScreen)
                              IconButton(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Color.fromRGBO(12, 10, 80, 1),
                                  size: 30,
                                ),
                                onPressed: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                              ),
                            Image.asset(
                              'assets/images/LOGO-SIS.png',
                              height: 55,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Snepac Indo Service",
                              style: TextStyle(
                                color: Color.fromRGBO(12, 10, 80, 1),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),

                        // ✅ Tengah: Menu (kalau layar besar)
                        if (isLargeScreen) _navBarItems(context),

                        // ✅ Kanan: Profil Icon
                        _ProfileIcon(
                          userName: _userName,
                          onSignOut: () => _handleSignOut(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: isLargeScreen ? null : _drawer(context),
      ),
    );
  }

  Widget _buildDashboardBody() {
    if (_isDashboardLoading ?? true) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Semua Kegiatan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard('Total Kegiatan', _safeStats['total']!, Colors.white),
                _buildStatCard('Aktif', _safeStats['active']!, Colors.orange),
                _buildStatCard('Selesai', _safeStats['completed']!, Colors.green),
                _buildStatCard('Terjadwal', _safeStats['scheduled']!, Colors.blue),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kegiatan Terbaru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_safeRecentActivities.isEmpty)
                    const Text('Belum ada data kegiatan.')
                  else
                    ..._safeRecentActivities.map((item) {
                      final vessel = (item['vessel_name'] ?? '-').toString();
                      final pilot = (item['pilot_name'] ?? '-').toString();
                      final status = (item['status'] ?? 'Terjadwal').toString();
                      final date = (item['date'] ?? '-').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(245, 247, 252, 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vessel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text('Pilot: $pilot'),
                                  Text('Tanggal: $date'),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color accentColor) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color.fromRGBO(70, 70, 70, 1),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Drawer (untuk mobile)
  Widget _drawer(BuildContext context) => Drawer(
    child: ListView(
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: Color.fromRGBO(0, 40, 120, 1)),
          child: Row(
            children: [
              Image.asset('assets/images/LOGO-SIS.png', height: 55),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Snepac Indo Service",
                  style: TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
            ],
          ),
        ),
        ..._menuItems.map(
          (item) => ListTile(
            onTap: () {
              Navigator.pop(context);
              if (item == 'Pemanduan & Penundaan') {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const PemanduanPage(),
                  ),
                );
              } else if (item == 'Dashboard') {
                _loadDashboard();
              }
            },
            leading: item == 'Dashboard'
                ? const Icon(
                    Icons.dashboard,
                    color: Color.fromRGBO(0, 40, 120, 1),
                    size: 28,
                  )
                : Image.asset(
                    'assets/icons/pilot1.png',
                    width: 28,
                    height: 27,
                  ),

            title: Text(
              item,
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(12, 10, 80, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ✅ Menu items (desktop view)
  Widget _navBarItems(BuildContext context) {
    return Row(
      children: _menuItems.map((item) {
        return InkWell(
          onTap: () {
            if (item == 'Pemanduan & Penundaan') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PemanduanPage()),
              );
            } else if (item == 'Dashboard') {
              _loadDashboard();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 18,
                color: Color.fromRGBO(12, 10, 80, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ✅ Fungsi Sign Out
  void _handleSignOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }
}

final List<String> _menuItems = ['Dashboard', 'Pemanduan & Penundaan'];

enum Menu { itemOne, itemTwo, itemThree }

// ✅ Profile Icon
class _ProfileIcon extends StatelessWidget {
  final String userName;
  final VoidCallback onSignOut;

  const _ProfileIcon({required this.userName, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Menu>(
      tooltip: '',
      icon: CircleAvatar(
        radius: 22,
        backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      offset: const Offset(0, 55),
      onSelected: (Menu item) {
        if (item == Menu.itemOne) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        } else if (item == Menu.itemTwo) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        } else if (item == Menu.itemThree) {
          onSignOut();
        }
      },
      itemBuilder: (BuildContext context) => const [
        PopupMenuItem<Menu>(value: Menu.itemOne, child: Text('Profil Akun')),
        PopupMenuItem<Menu>(value: Menu.itemTwo, child: Text('Pengaturan')),
        PopupMenuItem<Menu>(value: Menu.itemThree, child: Text('Log out')),
      ],
    );
  }
}
