import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:pilotage_and_assistance_app/utils/user_session.dart';
import 'package:pilotage_and_assistance_app/widgets/common/gradient_background.dart';

class ManagerProfilePage extends StatefulWidget {
  const ManagerProfilePage({super.key});

  @override
  State<ManagerProfilePage> createState() => _ManagerProfilePageState();
}

class _ManagerProfilePageState extends State<ManagerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2.5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final _firestore = FirebaseFirestore.instance;

  String _currentUserRole = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _existingSignatureData;
  bool _showSignatureCanvas = false;
  bool get _isSuperadmin => _currentUserRole.toLowerCase() == 'superadmin';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await UserSession.loadUser();
    final role = (UserSession.userRole ?? '').trim();

    if (!mounted) return;

    setState(() => _currentUserRole = role);

    if (!_isSuperadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak. Halaman ini hanya untuk superadmin.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }

    await _loadManagerProfile();
  }

  Future<void> _loadManagerProfile() async {
    try {
      final doc = await _firestore.collection('settings').doc('manager').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _nameController.text = data['name']?.toString() ?? '';
        _titleController.text = data['title']?.toString() ?? '';
        _existingSignatureData = data['signature_data']?.toString();
      }
    } catch (e) {
      // Dokumen belum ada, biarkan form kosong
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmChangeSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Ganti Tanda Tangan'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengganti tanda tangan Manager Pemanduan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Ganti'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      _signatureController.clear();
      setState(() => _showSignatureCanvas = true);
    }
  }

  void _addSignature() {
    _signatureController.clear();
    setState(() => _showSignatureCanvas = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isSuperadmin) return;

    setState(() => _isSaving = true);

    try {
      // Ambil signature baru jika ada
      String? signatureDataUrl = _existingSignatureData;
      if (_signatureController.isNotEmpty) {
        final signatureBytes = await _signatureController.toPngBytes();
        if (signatureBytes != null) {
          final base64 = base64Encode(signatureBytes);
          signatureDataUrl = 'data:image/png;base64,$base64';
        }
      }

      await _firestore.collection('settings').doc('manager').set({
        'name': _nameController.text.trim(),
        'title': _titleController.text.trim(),
        'signature_data': signatureDataUrl,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by_uid': UserSession.userUid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil manager berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSignaturePreview() {
    final signatureData = _existingSignatureData?.trim() ?? '';
    final payload = signatureData.replaceFirst(
      RegExp(r'data:image/[^;]+;base64,'),
      '',
    );

    try {
      final bytes = base64Decode(payload);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanda tangan tersimpan:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Center(
              child: Image.memory(bytes, height: 120, fit: BoxFit.contain),
            ),
          ],
        ),
      );
    } on FormatException {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Tanda tangan tersimpan tidak dapat ditampilkan.',
          style: TextStyle(fontSize: 12, color: Colors.black87),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackground()),
          Positioned.fill(
            top: 100,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profil Manager',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(12, 10, 80, 1),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Nama dan tanda tangan manager akan muncul di setiap sertifikat PDF.',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 20),

                            // Nama Manager
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Nama Manager *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                                hintText: 'Contoh: MOHAMMAD ADAM',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nama manager wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Jabatan Manager
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Jabatan',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge),
                                hintText: 'Contoh: MANAGER PEMANDUAN',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tanda Tangan
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Tanda Tangan Manager',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color.fromRGBO(12, 10, 80, 1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tanda tangan ini akan muncul di QR verifikasi setiap sertifikat PDF.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (!_showSignatureCanvas) ...[
                              if (_existingSignatureData != null &&
                                  _existingSignatureData!.trim().isNotEmpty)
                                _buildSignaturePreview(),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : (_existingSignatureData != null &&
                                            _existingSignatureData!
                                                .trim()
                                                .isNotEmpty)
                                      ? _confirmChangeSignature
                                      : _addSignature,
                                  icon: const Icon(Icons.draw_outlined),
                                  label: Text(
                                    _existingSignatureData != null &&
                                            _existingSignatureData!
                                                .trim()
                                                .isNotEmpty
                                        ? 'Ganti Tanda Tangan'
                                        : 'Tambah Tanda Tangan',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: Color.fromRGBO(0, 40, 120, 1),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade50,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Signature(
                                    controller: _signatureController,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            _signatureController.clear();
                                            setState(
                                              () =>
                                                  _showSignatureCanvas = false,
                                            );
                                          },
                                    icon: const Icon(Icons.undo, size: 16),
                                    label: const Text('Batal Ganti'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            _signatureController.clear();
                                            setState(() {});
                                          },
                                    icon: const Icon(Icons.clear, size: 16),
                                    label: const Text('Bersihkan'),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color.fromRGBO(0, 40, 120, 1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Tombol
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      side: const BorderSide(
                                        color: Color.fromRGBO(0, 40, 120, 1),
                                      ),
                                    ),
                                    child: const Text('Batal'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromRGBO(
                                        0,
                                        40,
                                        120,
                                        1,
                                      ),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Simpan'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // App Bar
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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
                        'Profil Manager',
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
}
