import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilotage_assistance_app/pages/profile/profile_page.dart'; // ✅ Absolute import
import '../../pages/pemanduan_page.dart';
import '../../pages/penundaan_page.dart';
import '../../../pages/login/login_page.dart';

class ResponsiveNavBarPage extends StatefulWidget {
  const ResponsiveNavBarPage({super.key});

  @override
  State<ResponsiveNavBarPage> createState() => _ResponsiveNavBarPageState();
}

class _ResponsiveNavBarPageState extends State<ResponsiveNavBarPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'User'; // Default name

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  // ✅ Load nama user dari SharedPreferences
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          titleSpacing: 0,
          leading: isLargeScreen
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
          // ✅ Logo & Nama Perusahaan di Tengah
          title: isLargeScreen
              ? null
              : Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/LOGO-SIS.png', height: 40),
                      const SizedBox(width: 10),
                      const Text(
                        "Snepac Indo Service",
                        style: TextStyle(
                          color: Color.fromRGBO(12, 10, 80, 1),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
          // ✅ Untuk Large Screen - Custom Layout
          flexibleSpace: isLargeScreen
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        // Menu items di kiri
                        _navBarItems(context),
                        // Logo & nama di tengah
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/LOGO-SIS.png',
                                    height: 40),
                                const SizedBox(width: 10),
                                const Text(
                                  "Snepac Indo Service",
                                  style: TextStyle(
                                    color: Color.fromRGBO(12, 10, 80, 1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Profile icon di kanan
                        _ProfileIcon(
                          userName: _userName,
                          onSignOut: () => _handleSignOut(context),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          actions: isLargeScreen
              ? null
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: _ProfileIcon(
                      userName: _userName,
                      onSignOut: () => _handleSignOut(context),
                    ),
                  ),
                ],
        ),
        drawer: isLargeScreen ? null : _drawer(context),
        body: const Center(child: Text("Body")),
      ),
    );
  }

  // ✅ Drawer untuk tampilan mobile
  Widget _drawer(BuildContext context) => Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                  color: Color.fromRGBO(0, 40, 120, 1)),
              child: Row(
                children: [
                  Image.asset('assets/images/LOGO-SIS.png', height: 50),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Snepac Indo Service",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            ..._menuItems.map(
              (item) => ListTile(
                onTap: () {
                  Navigator.pop(context);
                  if (item == 'Pemanduan') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PemanduanPage()),
                    );
                  } else if (item == 'Penundaan') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PenundaanPage()),
                    );
                  }
                },
                leading: item == 'Pemanduan'
                    ? const Icon(Icons.directions_boat)
                    : const Icon(Icons.anchor),
                title: Text(item),
              ),
            ),
          ],
        ),
      );

  // ✅ Navbar untuk tampilan desktop
  Widget _navBarItems(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: _menuItems.map((item) {
        return InkWell(
          onTap: () {
            if (item == 'Pemanduan') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PemanduanPage(),
                ),
              );
            } else if (item == 'Penundaan') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PenundaanPage(),
                ),
              );
            }
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
            child: Text(
              item,
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ✅ Fungsi Sign Out
  void _handleSignOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Hapus semua data login

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }
}

// ✅ Menu items
final List<String> _menuItems = ['Pemanduan', 'Penundaan'];

enum Menu { itemOne, itemTwo, itemThree }

// ✅ Profile Icon tanpa Tooltip
class _ProfileIcon extends StatelessWidget {
  final String userName;
  final VoidCallback onSignOut;

  const _ProfileIcon({
    required this.userName,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Menu>(
      tooltip: '', // ✅ Hilangkan tooltip "Show menu"
      icon: CircleAvatar(
        backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      offset: const Offset(0, 50),
      onSelected: (Menu item) {
        if (item == Menu.itemOne) {
          // ✅ Navigasi ke halaman Profile
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          );
        } else if (item == Menu.itemThree) {
          onSignOut();
        }
      },
      itemBuilder: (BuildContext context) => const [
        PopupMenuItem<Menu>(value: Menu.itemOne, child: Text('Akun')),
        PopupMenuItem<Menu>(value: Menu.itemTwo, child: Text('Pengaturan')),
        PopupMenuItem<Menu>(value: Menu.itemThree, child: Text('Log out')),
      ],
    );
  }
}