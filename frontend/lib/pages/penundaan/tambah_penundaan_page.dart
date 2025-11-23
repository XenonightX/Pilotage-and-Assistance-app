import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TambahPenundaanPage extends StatefulWidget {
  const TambahPenundaanPage({super.key});

  @override
  State<TambahPenundaanPage> createState() => _TambahPenundaanPageState();
}

class _TambahPenundaanPageState extends State<TambahPenundaanPage> {
  final _formKey = GlobalKey<FormState>();
  final String baseUrl = 'http://192.168.1.20/pilotage_and_assistance_app/api';
  
  bool _isLoading = false;

  // Controllers untuk field wajib
  final TextEditingController _vesselNameController = TextEditingController();
  final TextEditingController _flagController = TextEditingController();
  final TextEditingController _grossTonnageController = TextEditingController();
  final TextEditingController _agencyController = TextEditingController();
  final TextEditingController _loaController = TextEditingController();
  final TextEditingController _assistTugNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _assistanceStartController = TextEditingController();

  // Controllers untuk field opsional
  final TextEditingController _callSignController = TextEditingController();
  final TextEditingController _masterNameController = TextEditingController();
  final TextEditingController _foreDraftController = TextEditingController();
  final TextEditingController _aftDraftController = TextEditingController();
  final TextEditingController _assistanceEndController = TextEditingController();
  final TextEditingController _enginePowerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _fromWhere = 'Laut';
  String _toWhere = 'Dermaga';
  String _status = 'Terjadwal';

  @override
  void dispose() {
    _vesselNameController.dispose();
    _flagController.dispose();
    _grossTonnageController.dispose();
    _agencyController.dispose();
    _loaController.dispose();
    _assistTugNameController.dispose();
    _dateController.dispose();
    _assistanceStartController.dispose();
    _callSignController.dispose();
    _masterNameController.dispose();
    _foreDraftController.dispose();
    _aftDraftController.dispose();
    _assistanceEndController.dispose();
    _enginePowerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_assistances.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vessel_name": _vesselNameController.text,
          "call_sign": _callSignController.text.isEmpty ? null : _callSignController.text,
          "master_name": _masterNameController.text.isEmpty ? null : _masterNameController.text,
          "flag": _flagController.text,
          "gross_tonnage": _grossTonnageController.text,
          "agency": _agencyController.text,
          "loa": _loaController.text,
          "fore_draft": _foreDraftController.text.isEmpty ? null : _foreDraftController.text,
          "aft_draft": _aftDraftController.text.isEmpty ? null : _aftDraftController.text,
          "assist_tug_name": _assistTugNameController.text,
          "from_where": _fromWhere,
          "to_where": _toWhere,
          "date": _dateController.text,
          "assistance_start": _assistanceStartController.text,
          "assistance_end": _assistanceEndController.text.isEmpty ? null : _assistanceEndController.text,
          "engine_power": _enginePowerController.text.isEmpty ? null : _enginePowerController.text,
          "notes": _notesController.text.isEmpty ? null : _notesController.text,
          "status": _status,
        }),
      );

      final result = jsonDecode(response.body);

      if (result['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan data: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(0, 40, 120, 1),
      body: Stack(
        children: [
          // Header
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        "Tambah Data Penundaan",
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

          // Form Content
          Positioned.fill(
            top: 100,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Informasi Kapal'),
                    _buildTextField(
                      controller: _vesselNameController,
                      label: 'Nama Kapal *',
                      icon: Icons.directions_boat,
                      required: true,
                    ),
                    _buildTextField(
                      controller: _callSignController,
                      label: 'Call Sign',
                      icon: Icons.radio,
                    ),
                    _buildTextField(
                      controller: _masterNameController,
                      label: 'Nama Nahkoda',
                      icon: Icons.person,
                    ),
                    _buildTextField(
                      controller: _flagController,
                      label: 'Bendera *',
                      icon: Icons.flag,
                      required: true,
                    ),
                    _buildTextField(
                      controller: _grossTonnageController,
                      label: 'Gross Tonnage (GT) *',
                      icon: Icons.scale,
                      keyboardType: TextInputType.number,
                      required: true,
                    ),
                    _buildTextField(
                      controller: _loaController,
                      label: 'LOA (meter) *',
                      icon: Icons.straighten,
                      keyboardType: TextInputType.number,
                      required: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _foreDraftController,
                            label: 'Draft Depan (m)',
                            icon: Icons.arrow_downward,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _aftDraftController,
                            label: 'Draft Belakang (m)',
                            icon: Icons.arrow_downward,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _agencyController,
                      label: 'Keagenan *',
                      icon: Icons.business,
                      required: true,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Informasi Penundaan (Tug Service)'),
                    _buildTextField(
                      controller: _assistTugNameController,
                      label: 'Nama Kapal Tunda *',
                      icon: Icons.anchor,
                      required: true,
                    ),
                    _buildTextField(
                      controller: _enginePowerController,
                      label: 'Tenaga Mesin Tunda (HP/BHP)',
                      icon: Icons.power,
                      keyboardType: TextInputType.number,
                    ),
                    _buildDropdown(
                      label: 'Dari *',
                      value: _fromWhere,
                      items: ['Laut', 'Dermaga'],
                      onChanged: (value) => setState(() => _fromWhere = value!),
                    ),
                    _buildDropdown(
                      label: 'Ke *',
                      value: _toWhere,
                      items: ['Laut', 'Dermaga'],
                      onChanged: (value) => setState(() => _toWhere = value!),
                    ),

                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _dateController,
                          label: 'Tanggal *',
                          icon: Icons.calendar_today,
                          required: true,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () => _selectTime(context, _assistanceStartController),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _assistanceStartController,
                          label: 'Waktu Mulai Penundaan *',
                          icon: Icons.access_time,
                          required: true,
                        ),
                      ),
                    ),

                    GestureDetector(
                      onTap: () => _selectTime(context, _assistanceEndController),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _assistanceEndController,
                          label: 'Waktu Selesai Penundaan',
                          icon: Icons.access_time_filled,
                        ),
                      ),
                    ),

                    _buildDropdown(
                      label: 'Status *',
                      value: _status,
                      items: ['Terjadwal', 'Berlangsung', 'Selesai', 'Dibatalkan'],
                      onChanged: (value) => setState(() => _status = value!),
                    ),

                    _buildTextField(
                      controller: _notesController,
                      label: 'Catatan',
                      icon: Icons.note,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 225, 109, 0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Simpan Data',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        validator: required
            ? (value) => value == null || value.isEmpty ? 'Field ini wajib diisi' : null
            : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}