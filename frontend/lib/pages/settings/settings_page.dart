import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Preferensi Aplikasi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(12, 10, 80, 1),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Mode Gelap"),
            subtitle: const Text("Aktifkan tema gelap untuk aplikasi"),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
            },
            activeThumbColor: const Color.fromRGBO(0, 40, 120, 1),
          ),
          const Divider(height: 30),

          const Text(
            "Notifikasi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(12, 10, 80, 1),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text("Aktifkan Notifikasi"),
            subtitle: const Text("Terima pemberitahuan dari aplikasi"),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
            activeThumbColor: const Color.fromRGBO(0, 40, 120, 1),
          ),

          const Divider(height: 30),

          ListTile(
            leading: const Icon(Icons.info_outline, color: Color.fromRGBO(12, 10, 80, 1)),
            title: const Text("Tentang Aplikasi"),
            subtitle: const Text("Versi 1.0.0"),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: "Pilotage Assistance App",
                applicationVersion: "1.0.0",
                applicationLegalese: "© 2025 Snepac Indo Service",
              );
            },
          ),
        ],
      ),
    );
  }
}
