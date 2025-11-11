import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilotage_assistance_app/pages/profile/edit_profile_page.dart';
import 'package:pilotage_assistance_app/pages/profile/change_password_page.dart'; // ✅ Import change password page

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _userName = '';
  String _userEmail = '';
  String _userRole = '';
  int _userId = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ✅ Load data user dari SharedPreferences
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
      _userEmail = prefs.getString('userEmail') ?? 'email@example.com';
      _userRole = prefs.getString('userRole') ?? 'User';
      _userId = prefs.getInt('userId') ?? 0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profil Akun',
          style: TextStyle(
            color: Color.fromRGBO(12, 10, 80, 1),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ✅ Header Profile
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Nama
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(12, 10, 80, 1),
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _userRole.toLowerCase() == 'admin'
                                ? Colors.red[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _userRole.toUpperCase(),
                            style: TextStyle(
                              color: _userRole.toLowerCase() == 'admin'
                                  ? Colors.red[900]
                                  : Colors.blue[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Informasi Akun
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(12, 10, 80, 1),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // ID User
                        _buildInfoCard(
                          icon: Icons.badge,
                          title: 'User ID',
                          value: '#$_userId',
                        ),
                        const SizedBox(height: 10),

                        // Email
                        _buildInfoCard(
                          icon: Icons.email,
                          title: 'Email',
                          value: _userEmail,
                        ),
                        const SizedBox(height: 10),

                        // Role
                        _buildInfoCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Role',
                          value: _userRole,
                        ),
                        const SizedBox(height: 30),

                        // ✅ Tombol Edit Profile
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // ✅ Navigasi ke halaman Edit Profile
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EditProfilePage(),
                                ),
                              );
                              
                              // ✅ Refresh data jika berhasil update
                              if (result == true) {
                                _loadUserData();
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromRGBO(0, 40, 120, 1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ✅ Tombol Ganti Password
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // ✅ Navigasi ke halaman Ganti Password
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChangePasswordPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.lock),
                            label: const Text(
                              'Ganti Password',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color.fromRGBO(0, 40, 120, 1),
                              side: const BorderSide(
                                color: Color.fromRGBO(0, 40, 120, 1),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ✅ Widget Info Card
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 40, 120, 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color.fromRGBO(0, 40, 120, 1),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color.fromRGBO(12, 10, 80, 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}