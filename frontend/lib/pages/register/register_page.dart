import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../login/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers untuk Pandu
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // Controllers untuk Kapal Tunda
  final TextEditingController _vesselNameController = TextEditingController();
  final TextEditingController _tugboatEmailController = TextEditingController();
  final TextEditingController _tugboatPasswordController = TextEditingController();
  final TextEditingController _tugboatConfirmController = TextEditingController();

  bool _isObscure = true;
  bool _isObscureConfirm = true;
  bool _isLoading = false;
  
  String? _selectedRole; // null = belum pilih role

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _vesselNameController.dispose();
    _tugboatEmailController.dispose();
    _tugboatPasswordController.dispose();
    _tugboatConfirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    String name;
    String email;
    String password;
    String confirm;

    // Ambil data sesuai role
    if (_selectedRole == 'pilot') {
      name = _nameController.text.trim();
      email = _emailController.text.trim();
      password = _passwordController.text.trim();
      confirm = _confirmController.text.trim();
    } else {
      // Untuk kapal tunda, nama kapal jadi nama akun
      name = _vesselNameController.text.trim();
      email = _tugboatEmailController.text.trim();
      password = _tugboatPasswordController.text.trim();
      confirm = _tugboatConfirmController.text.trim();
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field wajib diisi")),
      );
      return;
    }

    if (password != confirm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password dan konfirmasi tidak cocok")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final requestBody = {
        "name": name,
        "email": email,
        "password": password,
        "role": _selectedRole,
      };

      print("📤 Sending data: $requestBody"); // Debug print

      final response = await http.post(
        Uri.parse('http://192.168.0.9/pilotage_and_assistance_app/backend/auth/register.php'),
        // Uri.parse('http://192.168.1.15/pilotage_and_assistance_app/backend/auth/register.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print("📥 Response: ${response.body}");
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registrasi berhasil, silakan login"),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? "Registrasi gagal")),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal terhubung ke server: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/LOGO-SIS.png', height: 150),
              const SizedBox(height: 20),

              // ROLE SELECTOR - Tampil pertama kali
              if (_selectedRole == null) ...[
                const Text(
                  "Pilih Role Pendaftaran",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(12, 10, 80, 1),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Silakan pilih role yang sesuai dengan Anda",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Card Pandu
                InkWell(
                  onTap: () {
                    setState(() => _selectedRole = 'pilot');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 40, 120, 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Color.fromRGBO(0, 40, 120, 1),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pandu",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Daftar sebagai pandu kapal",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Card Kapal Tunda
                InkWell(
                  onTap: () {
                    setState(() => _selectedRole = 'tugboat');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(0, 40, 120, 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.directions_boat,
                            size: 40,
                            color: Color.fromRGBO(0, 40, 120, 1),
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Kapal Tunda",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Daftar sebagai operator kapal tunda",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],

              // FORM PANDU
              if (_selectedRole == 'pilot') ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _selectedRole = null);
                      },
                    ),
                    const Text(
                      "Pendaftaran Pandu",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(12, 10, 80, 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _nameController,
                  label: "Nama Lengkap",
                  hint: "Masukkan nama lengkap",
                  icon: Icons.person,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  controller: _emailController,
                  label: "Email",
                  hint: "Masukkan email",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),

                _buildPasswordField(
                  controller: _passwordController,
                  label: "Password",
                  hint: "Masukkan password",
                  isObscure: _isObscure,
                  onToggle: () => setState(() => _isObscure = !_isObscure),
                ),
                const SizedBox(height: 15),

                _buildPasswordField(
                  controller: _confirmController,
                  label: "Konfirmasi Password",
                  hint: "Konfirmasi password",
                  isObscure: _isObscureConfirm,
                  onToggle: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                ),
              ],

              // FORM KAPAL TUNDA
              if (_selectedRole == 'tugboat') ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _selectedRole = null);
                      },
                    ),
                    const Text(
                      "Pendaftaran Kapal Tunda",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(12, 10, 80, 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: _vesselNameController,
                  label: "Nama Kapal",
                  hint: "Masukkan nama kapal tunda",
                  icon: Icons.directions_boat,
                ),
                const SizedBox(height: 15),

                _buildTextField(
                  controller: _tugboatEmailController,
                  label: "Email",
                  hint: "Masukkan email",
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),

                _buildPasswordField(
                  controller: _tugboatPasswordController,
                  label: "Password",
                  hint: "Masukkan password",
                  isObscure: _isObscure,
                  onToggle: () => setState(() => _isObscure = !_isObscure),
                ),
                const SizedBox(height: 15),

                _buildPasswordField(
                  controller: _tugboatConfirmController,
                  label: "Konfirmasi Password",
                  hint: "Konfirmasi password",
                  isObscure: _isObscureConfirm,
                  onToggle: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                ),
              ],

              // TOMBOL DAFTAR (tampil jika sudah pilih role)
              if (_selectedRole != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Daftar",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 15),

              // Link ke Login
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text(
                  "Sudah punya akun? Login di sini",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk TextField biasa
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  // Helper widget untuk Password Field
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: isObscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            suffixIcon: IconButton(
              icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}