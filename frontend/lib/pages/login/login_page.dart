import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:pilotage_and_assistance_app/widgets/navbar/navbar.dart';
import 'package:pilotage_and_assistance_app/pages/register/register_page.dart';
import 'package:pilotage_and_assistance_app/pages/login/forgot_password_page.dart'; // ✅ Import forgot password

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isObscure = true;
  bool _isLoading = false;

  // ✅ Fungsi Login
  Future<void> _login() async {
    String email = _userController.text.trim();
    String password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password tidak boleh kosong")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            'http://192.168.0.9/pilotage_and_assistance_app/backend/auth/login.php'), //ip kantor
            // 'http://192.168.1.8/pilotage_and_assistance_app/backend/auth/login.php'), //ip wifi rumah
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success' && result['data'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setInt('userId', result['data']['id'] ?? 0);
          await prefs.setString('userName', result['data']['name'] ?? 'User');
          await prefs.setString('userEmail', result['data']['email'] ?? '');
          await prefs.setString('userRole', result['data']['role'] ?? '');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ResponsiveNavBarPage()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? "Login gagal")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server error: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal terhubung ke server: $e")),
        );
      }
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

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Masukan Email"),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _userController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                ),
              ),
              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Masukan Password"),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: _passController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  hintText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      setState(() => _isObscure = !_isObscure);
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        key: ValueKey<bool>(_isObscure),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Daftar",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // ✅ Navigasi ke halaman Forgot Password
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Lupa password?",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                          "Masuk",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}