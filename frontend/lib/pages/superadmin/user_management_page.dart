import 'package:flutter/material.dart';
import 'package:pilotage_and_assistance_app/pages/superadmin/add_user_page.dart';
import 'package:pilotage_and_assistance_app/services/firestore_data_service.dart';
import 'package:pilotage_and_assistance_app/utils/user_session.dart';
import 'package:pilotage_and_assistance_app/widgets/common/gradient_background.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final FirestoreDataService _dataService = FirestoreDataService();
  final TextEditingController _searchController = TextEditingController();

  String _currentUserRole = '';
  bool _isCheckingAccess = true;

  bool get _isSuperadmin => _currentUserRole.toLowerCase() == 'superadmin';

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    await UserSession.loadUser();
    final role = (UserSession.userRole ?? '').trim();

    if (!mounted) return;
    setState(() {
      _currentUserRole = role;
      _isCheckingAccess = false;
    });

    if (!_isSuperadmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak. Halaman ini hanya untuk superadmin.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _openAddUser() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddUserPage()),
    );

    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daftar pengguna diperbarui.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openEditUser(Map<String, dynamic> user) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EditUserDialog(user: user),
    );

    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data pengguna berhasil disimpan.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final uid = _userUid(user);
    if (uid.isEmpty) return;

    if (uid == UserSession.userUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun yang sedang login tidak dapat dihapus.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = _field(user, 'name', fallback: '-');
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Hapus profil pengguna "$name" dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _dataService.deleteUserProfile(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengguna berhasil dihapus.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus pengguna: $e'),
          backgroundColor: Colors.red,
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
            child: _isCheckingAccess
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _buildBody(),
          ),
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Manajemen Pengguna',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color.fromRGBO(12, 10, 80, 1),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openAddUser,
                  tooltip: 'Tambah pengguna',
                  icon: const Icon(Icons.person_add_alt_1),
                  color: const Color.fromRGBO(0, 40, 120, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari nama, email, atau role',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dataService.watchUsers(search: _searchController.text),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _MessagePanel(
                    icon: Icons.error_outline,
                    text: 'Gagal memuat pengguna: ${snapshot.error}',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final users = snapshot.data!;
                if (users.isEmpty) {
                  return const _MessagePanel(
                    icon: Icons.people_outline,
                    text: 'Belum ada pengguna yang sesuai.',
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserCard(
                      user: user,
                      onEdit: () => _openEditUser(user),
                      onDelete: () => _confirmDeleteUser(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = _field(user, 'name', fallback: '-');
    final email = _field(user, 'email', fallback: '-');
    final role = _field(user, 'role', fallback: '-');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
              child: Text(
                name.isNotEmpty && name != '-' ? name[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _RoleChip(role: role),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Ubah',
              icon: const Icon(Icons.edit),
              color: Colors.orange,
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});

  final Map<String, dynamic> user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dataService = FirestoreDataService();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late String _selectedRole;
  bool _isSaving = false;

  bool get _isCurrentUser => _userUid(widget.user) == UserSession.userUid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _field(widget.user, 'name'));
    _emailController = TextEditingController(
      text: _field(widget.user, 'email'),
    );
    _selectedRole = _field(widget.user, 'role', fallback: 'pilot');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _userUid(widget.user);
    if (uid.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _dataService.updateUserProfile(uid, {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengguna: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Pengguna'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email Login',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(value: 'pilot', child: Text('Pilot')),
                  DropdownMenuItem(value: 'tugboat', child: Text('Tugboat')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                    value: 'superadmin',
                    child: Text('Superadmin'),
                  ),
                ],
                onChanged: _isCurrentUser
                    ? null
                    : (value) {
                        setState(() => _selectedRole = value ?? 'pilot');
                      },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
            foregroundColor: Colors.white,
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
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role.toLowerCase()) {
      'superadmin' => Colors.red,
      'admin' => Colors.orange,
      'tugboat' => Colors.teal,
      _ => const Color.fromRGBO(0, 40, 120, 1),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: const Color.fromRGBO(0, 40, 120, 1)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _field(
  Map<String, dynamic> row,
  String key, {
  String fallback = '',
}) {
  final value = row[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String _userUid(Map<String, dynamic> user) {
  final value = user['uid'] ?? user['id'];
  return value?.toString().trim() ?? '';
}
