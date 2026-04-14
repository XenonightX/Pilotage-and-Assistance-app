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
  final String _baseUrl = 'http://192.168.0.9/pilotage_and_assistance_app/api';
  String _userName = 'User';
  bool? _isDashboardLoading = true;

  List<Map<String, dynamic>>? _recentActivities = [];

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
      final recentActivities = await _fetchRecentActivities();

      if (!mounted) return;

      setState(() {
        _recentActivities = recentActivities;
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
    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
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
                        // ✅ Kiri: Logo + Nama
                        Row(
                          children: [
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
      ),
    );
  }

  Widget _buildDashboardBody() {
    if (_isDashboardLoading ?? true) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final bool isLargeScreen = width > 900;
    final double maxWidth = isLargeScreen ? 1100 : double.infinity;
    final double minHeight = MediaQuery.of(context).size.height - 100;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(0, 40, 120, 1),
                Color.fromRGBO(6, 72, 140, 1),
                Color.fromRGBO(10, 120, 140, 1),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: _buildGlowCircle(
                  size: 220,
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              Positioned(
                top: 180,
                left: -90,
                child: _buildGlowCircle(
                  size: 240,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              Positioned(
                bottom: -120,
                right: -40,
                child: _buildGlowCircle(
                  size: 260,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(),
                        const SizedBox(height: 18),
                        _buildQuickActions(isLargeScreen),
                        const SizedBox(height: 18),
                        _buildRecentActivities(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat datang, $_userName',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(12, 10, 80, 1),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pantau semua kegiatan pemanduan dengan ringkas, jelas, dan cepat.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isLargeScreen) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildQuickActionCard(
          title: 'Buka Pemanduan & Penundaan',
          subtitle: 'Lihat daftar & detail kegiatan',
          icon: Icons.assignment,
          color: const Color.fromRGBO(0, 40, 120, 1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PemanduanPage()),
            );
          },
        ),
        _buildQuickActionCard(
          title: 'Refresh Data',
          subtitle: 'Perbarui data terbaru',
          icon: Icons.refresh,
          color: Colors.teal,
          onTap: _loadDashboard,
        ),
        _buildQuickActionCard(
          title: 'Profil Akun',
          subtitle: 'Kelola informasi akun',
          icon: Icons.person,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
        ),
        if (isLargeScreen)
          _buildQuickActionCard(
            title: 'Pengaturan',
            subtitle: 'Preferensi aplikasi',
            icon: Icons.settings,
            color: Colors.blueGrey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth < 500 ? double.infinity : 260;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(245, 247, 252, 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vessel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pilot: $pilot',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Tanggal: $date',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
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
