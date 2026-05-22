import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pilotage_and_assistance_app/services/firebase_auth_service.dart';
import 'package:pilotage_and_assistance_app/widgets/common/gradient_background.dart';
import 'package:pilotage_and_assistance_app/widgets/navbar/navbar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();

  bool _isObscure = true;
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _userController.text.trim();
    final password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password tidak boleh kosong")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(email: email, password: password);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResponsiveNavBarPage()),
      );
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'user-not-found' => 'Email tidak ditemukan.',
        'wrong-password' ||
        'invalid-credential' => 'Email atau password salah.',
        'network-request-failed' => 'Tidak ada koneksi jaringan untuk login.',
        _ => e.message ?? 'Login gagal.',
      };
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackground()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/LOGO-SIS.png', height: 150),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Masukan Email",
                      style: TextStyle(color: Colors.white),
                    ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Masukan Password",
                      style: TextStyle(color: Colors.white),
                    ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() => _isObscure = !_isObscure);
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return RotationTransition(
                              turns: Tween<double>(
                                begin: 0.75,
                                end: 1,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            _isObscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            key: ValueKey<bool>(_isObscure),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
