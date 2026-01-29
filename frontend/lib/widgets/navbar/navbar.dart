import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
    });
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
              child: Container(
                padding: const EdgeInsets.all(16),
                child: const Center(
                  child: Text("Body Content", style: TextStyle(fontSize: 20)),
                ),
              ),
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
              }
            },
            leading: Image.asset(
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

final List<String> _menuItems = ['Pemanduan & Penundaan'];

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
