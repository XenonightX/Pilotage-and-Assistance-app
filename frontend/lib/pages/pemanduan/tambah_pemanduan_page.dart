import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pilotage_and_assistance_app/utils/user_session.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class TambahPemanduanPage extends StatefulWidget {
  const TambahPemanduanPage({super.key});

  @override
  State<TambahPemanduanPage> createState() => _TambahPemanduanPageState();
}

class _TambahPemanduanPageState extends State<TambahPemanduanPage> {
  final _formKey = GlobalKey<FormState>();

  final vesselController = TextEditingController();
  final tugNameController = TextEditingController();
  final bargeNameController = TextEditingController();
  final callSignController = TextEditingController();
  final masterController = TextEditingController();
  final flagController = TextEditingController();
  final gtTugController = TextEditingController();
  final gtBargeController = TextEditingController();
  final loaTugController = TextEditingController();
  final loaBargeController = TextEditingController();
  final agencyController = TextEditingController();
  final foredraftController = TextEditingController();
  final aftdraftController = TextEditingController();
  final pilotController = TextEditingController();
  final jettyController = TextEditingController();
  final lastPortController = TextEditingController();
  final nextPortController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedDirection = 'IN';
  String vesselType = 'Motor'; // Motor atau Tug & Tongkang
  bool _isLoading = false;

  // Assist Tug variables - now supports multiple tugs
  List<Map<String, String>> selectedAssistTugs = [];

  // Predefined assist tug options
  late List<Map<String, String>> assistTugOptions;

  final String baseUrl = 'http://192.168.0.9/pilotage_and_assistance_app/api';
  // final String baseUrl = 'http://192.168.1.15/pilotage_and_assistance_app/api';

  @override
  void initState() {
    super.initState();
    pilotController.text = UserSession.userName ?? '';
    assistTugOptions = [
      {'name': 'TB. MEGAMAS VISHA', 'power': '2060', 'bollard_pull': '25'},
      {'name': 'TB. HEMINGWAY 2400', 'power': '2400', 'bollard_pull': '24'},
      {'name': 'TB. ORIENT VICTORY 1', 'power': '3500', 'bollard_pull': '44'},
    ];
  }

  @override
  void dispose() {
    vesselController.dispose();
    bargeNameController.dispose();
    callSignController.dispose();
    masterController.dispose();
    flagController.dispose();
    gtTugController.dispose();
    gtBargeController.dispose();
    loaTugController.dispose();
    loaBargeController.dispose();
    agencyController.dispose();
    foredraftController.dispose();
    aftdraftController.dispose();
    tugNameController.dispose();
    jettyController.dispose();
    lastPortController.dispose();
    nextPortController.dispose();
    dateController.dispose();
    timeController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) {
      print('========== Form tidak valid! ==========');
      print('Vessel Type: $vesselType');
      print('Vessel Name: ${vesselController.text}');
      print('Tug Name: ${tugNameController.text}');
      print('Barge Name: ${bargeNameController.text}');
      print('Call Sign: ${callSignController.text}');
      print('Master: ${masterController.text}');
      print('Flag: ${flagController.text}');
      print('Agency: ${agencyController.text}');
      print('GT Tug: ${gtTugController.text}');
      print('GT Barge: ${gtBargeController.text}');
      print('LOA Tug: ${loaTugController.text}');
      print('LOA Barge: ${loaBargeController.text}');
      print('Foredraft: ${foredraftController.text}');
      print('Aftdraft: ${aftdraftController.text}');
      print('Pilot: ${pilotController.text}');
      print('Jetty: ${jettyController.text}');
      print('Last Port: ${lastPortController.text}');
      print('Next Port: ${nextPortController.text}');
      print(
        'Assist Tugs: ${selectedAssistTugs.map((tug) => '${tug['name']} (${tug['power']} HP)').join(', ')}',
      );
      print('Date: ${dateController.text}');
      print('Time: ${timeController.text}');
      print('=======================================');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mohon lengkapi semua field yang wajib diisi (bertanda *)',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal dan waktu harus diisi!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbDate =
          '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      final dbTime =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00';

      String fromWhere, toWhere;
      if (selectedDirection == 'IN') {
        fromWhere = 'LAUT';
        toWhere = jettyController.text;
      } else {
        fromWhere = jettyController.text;
        toWhere = 'LAUT';
      }

      // Format GT dan LOA sesuai jenis kapal
      String grossTonnage;
      String loa;
      String vesselName;

      if (vesselType == 'Motor') {
        vesselName = vesselController.text;
        grossTonnage = gtTugController.text;
        loa = loaTugController.text;
      } else {
        vesselName = tugNameController.text.trim();
        if (bargeNameController.text.trim().isNotEmpty) {
          vesselName += '/${bargeNameController.text.trim()}';
        }

        grossTonnage = gtTugController.text;
        if (gtBargeController.text.isNotEmpty) {
          grossTonnage += '/${gtBargeController.text}';
        }

        loa = loaTugController.text;
        if (loaBargeController.text.isNotEmpty) {
          loa += '/${loaBargeController.text}';
        }
      }

      final data = {
        "vessel_name": vesselName,
        "call_sign": callSignController.text.isEmpty
            ? null
            : callSignController.text,
        "master_name": masterController.text.isEmpty
            ? null
            : masterController.text,
        "flag": flagController.text,
        "gross_tonnage": grossTonnage,
        "agency": agencyController.text,
        "loa": loa,
        "fore_draft": foredraftController.text.isEmpty
            ? null
            : foredraftController.text,
        "aft_draft": aftdraftController.text.isEmpty
            ? null
            : aftdraftController.text,
        "pilot_name": pilotController.text,
        "from_where": fromWhere,
        "to_where": toWhere,
        "last_port": lastPortController.text,
        "next_port": nextPortController.text,
        "assist_tug_name": selectedAssistTugs.isEmpty
            ? null
            : selectedAssistTugs.map((tug) => tug['name']).join(', '),
        "engine_power": selectedAssistTugs.isEmpty
            ? null
            : selectedAssistTugs.map((tug) => tug['power']).join(', '),
        "bollard_pull_power": selectedAssistTugs.isEmpty
            ? null
            : selectedAssistTugs.map((tug) => tug['bollard_pull']).join(', '),
        "date": dbDate,
        "pilot_on_board": '$dbDate $dbTime',
        "status": "Terjadwal",
      };

      // ====== DEBUGGING: Print data yang akan dikirim ======
      print('========== DATA YANG DIKIRIM KE API ==========');
      print(jsonEncode(data));
      print('==============================================');

      final response = await http.post(
        Uri.parse('$baseUrl/add_pilotages.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      // ====== DEBUGGING: Print response dari server ======
      print('========== RESPONSE DARI SERVER ==========');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('==========================================');

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
      print('========== ERROR ==========');
      print(e);
      print('===========================');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menambahkan data: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPilot = UserSession.isPilot();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          Positioned.fill(
            top: 100,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pilihan Jenis Kapal
                    _buildSectionTitle('Jenis Kapal'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.category,
                                size: 20,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pilih Jenis Kapal',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('KAPAL MOTOR'),
                                  value: 'Motor',
                                  groupValue: vesselType,
                                  onChanged: (value) {
                                    setState(() {
                                      vesselType = value!;
                                      // Reset fields saat ganti jenis
                                      tugNameController.clear();
                                      bargeNameController.clear();
                                      gtBargeController.clear();
                                      loaBargeController.clear();
                                    });
                                  },
                                  activeColor: const Color.fromRGBO(
                                    0,
                                    40,
                                    120,
                                    1,
                                  ),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('TUG BOAT & TONGKANG'),
                                  value: 'Tug',
                                  groupValue: vesselType,
                                  onChanged: (value) {
                                    setState(() {
                                      vesselType = value!;
                                    });
                                  },
                                  activeColor: const Color.fromRGBO(
                                    0,
                                    40,
                                    120,
                                    1,
                                  ),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Informasi Kapal Section
                    _buildSectionTitle('Data Kapal'),
                    const SizedBox(height: 16),

                    // Conditional: Nama Kapal Motor atau Nama Tug Boat & Tongkang
                    if (vesselType == 'Motor') ...[
                      TextFormField(
                        controller: vesselController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Kapal Motor *',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Image.asset(
                              'assets/icons/vessel.png', // ganti sesuai icon
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama kapal wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      TextFormField(
                        controller: tugNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Tug Boat *',
                          hintText: 'Contoh: TB. Bintang Laut',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Image.asset(
                              'assets/icons/tugboat.png', // ganti sesuai icon
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama Tug Boat wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bargeNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Nama Tongkang *',
                          hintText: 'Contoh: BG. Jaya 01',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Image.asset(
                              'assets/icons/barge.png', // ganti sesuai icon
                              width: 15,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama Tongkang wajib diisi';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Field Call Sign - Wajib untuk Motor, Opsional untuk Tug
                    TextFormField(
                      controller: callSignController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: vesselType == 'Motor'
                            ? 'Call Sign / Nama Panggilan *'
                            : 'Call Sign / Nama Panggilan',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Image.asset(
                            'assets/icons/call_sign.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: vesselType == 'Motor'
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Call Sign wajib diisi untuk Kapal Motor';
                              }
                              return null;
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Field Nama Nahkoda - Wajib untuk Motor, Opsional untuk Tug
                    TextFormField(
                      controller: masterController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: vesselType == 'Motor'
                            ? 'Nama Nahkoda *'
                            : 'Nama Nahkoda',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Image.asset(
                            'assets/icons/pilot.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: vesselType == 'Motor'
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama Nahkoda wajib diisi untuk Kapal Motor';
                              }
                              return null;
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: flagController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Bendera Kapal *',
                        hintText: 'Contoh: Indonesia, Singapore',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/icons/flag.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bendera kapal wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: agencyController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Keagenan Kapal *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/icons/agency.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Keagenan wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Gross Tonnage Section - Conditional
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.scale,
                                size: 20,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gross Tonnage (GT)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Form untuk Kapal Motor (1 field) atau Tug Boat
                          TextFormField(
                            controller: gtTugController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: vesselType == 'Motor'
                                  ? 'GT Kapal Motor *'
                                  : 'GT Tug Boat *',
                              hintText: vesselType == 'Motor'
                                  ? 'Masukkan GT Kapal'
                                  : 'Masukkan GT Tug Boat',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,

                              // === Prefix Icon dari Asset ===
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  vesselType == 'Motor'
                                      ? 'assets/icons/vessel.png' // icon kapal motor
                                      : 'assets/icons/tugboat.png', // icon tugboat
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return vesselType == 'Motor'
                                    ? 'GT Kapal wajib diisi'
                                    : 'GT Tug Boat wajib diisi';
                              }
                              return null;
                            },
                          ),

                          // Form Tongkang (hanya muncul jika Tug & Tongkang)
                          if (vesselType == 'Tug') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: gtBargeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'GT Tongkang *',
                                hintText: 'Masukkan GT Tongkang',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Image.asset(
                                    'assets/icons/barge.png', // ganti sesuai icon
                                    width: 15,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'GT Tongkang wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // LOA Section - Conditional
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Panjang Kapal (LOA - Length Overall)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Form untuk Kapal Motor (1 field) atau Tug Boat
                          TextFormField(
                            controller: loaTugController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: vesselType == 'Motor'
                                  ? 'LOA Kapal Motor (meter) *'
                                  : 'LOA Tug Boat (meter) *',
                              hintText: vesselType == 'Motor'
                                  ? 'Panjang Kapal'
                                  : 'Panjang Tug Boat',
                              border: const OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  vesselType == 'Motor'
                                      ? 'assets/icons/loa.png' // icon kapal motor
                                      : 'assets/icons/loa.png', // icon tugboat
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return vesselType == 'Motor'
                                    ? 'LOA Kapal wajib diisi'
                                    : 'LOA Tug Boat wajib diisi';
                              }
                              return null;
                            },
                          ),

                          // Form Tongkang (hanya muncul jika Tug & Tongkang)
                          if (vesselType == 'Tug') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: loaBargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'LOA Tongkang (meter) *',
                                hintText: 'Panjang Tongkang',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Image.asset(
                                    'assets/icons/loa.png', // ganti sesuai icon
                                    width: 15,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                suffixText: 'm',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'LOA Tongkang wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ganti bagian Sarat Muka dan Sarat Belakang dengan kode ini:

                    // Draft Section - Similar to GT and LOA
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.waves,
                                size: 20,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sarat Kapal (Draft)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: const Color.fromARGB(255, 255, 0, 0),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Opsional - Isi jika data tersedia',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        0,
                                        0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sarat Muka
                          TextFormField(
                            controller: foredraftController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Sarat Muka (meter)',
                              hintText: 'Opsional',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/draft.png', // ganti sesuai icon
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              suffixText: 'm',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Sarat Belakang
                          TextFormField(
                            controller: aftdraftController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Sarat Belakang (meter)',
                              hintText: 'Opsional',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/draft.png', // ganti sesuai icon
                                  width: 15,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              suffixText: 'm',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Informasi Pemanduan Section
                    _buildSectionTitle('Informasi Pemanduan'),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: pilotController,
                      readOnly: isPilot,
                      decoration: InputDecoration(
                        labelText: 'Nama Pandu *',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: isPilot ? Colors.grey[200] : Colors.white,

                        // === Prefix Icon dari Asset ===
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icons/pilot1.png', // Ganti sesuai icon
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // === Suffix Icon Pakai Asset Jika isPilot ===
                        suffixIcon: isPilot
                            ? Padding(
                                padding: const EdgeInsets.all(7),
                                child: Image.asset(
                                  'assets/icons/lock.png', // file icon gembok
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : null,
                      ),

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama pandu wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedDirection,
                      decoration: InputDecoration(
                        labelText: 'Arah Pemanduan *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/icons/transfer.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      items: ['IN', 'OUT']
                          .map(
                            (direction) => DropdownMenuItem(
                              value: direction,
                              child: Text(
                                direction == 'IN'
                                    ? 'IN (Masuk dari Laut ke Jetty'
                                    : 'OUT (Keluar dari Jetty ke Laut)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDirection = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: jettyController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Nama Jetty *',
                        hintText: selectedDirection == 'IN'
                            ? 'Jetty tujuan (contoh: Jetty Batu Ampar)'
                            : 'Jetty asal (contoh: Jetty Batu Ampar)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/icons/jetty.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama jetty wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: lastPortController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Pelabuhan Asal *',
                        hintText: 'Contoh: Singapore, Jakarta',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Image.asset(
                            'assets/icons/location.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Pelabuhan asal wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: nextPortController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Pelabuhan Tujuan *',
                        hintText: 'Contoh: Batam, Singapore',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Image.asset(
                            'assets/icons/location.png', // ganti sesuai icon
                            width: 15,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Pelabuhan tujuan wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Pilih Assist Tug
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade400,
                          width: 2,
                        ),
                      ),
                      child: DropdownButtonFormField<Map<String, String>>(
                        decoration: InputDecoration(
                          labelText: 'Pilih Assist Tug',
                          border: InputBorder.none,
                          filled: false,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/icons/tugboat.png',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        items: assistTugOptions.isNotEmpty
                            ? assistTugOptions.map((tug) {
                                return DropdownMenuItem<Map<String, String>>(
                                  value: tug,
                                  child: Text(
                                    '${tug['name']} - ${tug['power']} HP / ${tug['bollard_pull']} TON',
                                  ),
                                );
                              }).toList()
                            : [],
                        onChanged: (Map<String, String>? selectedTug) {
                          if (selectedTug != null) {
                            // Check if tug already selected
                            bool alreadySelected = selectedAssistTugs.any(
                              (tug) => tug['name'] == selectedTug['name'],
                            );

                            if (alreadySelected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tug Boat ini sudah dipilih'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setState(() {
                              selectedAssistTugs.add(selectedTug);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Display selected assist tugs
                    if (selectedAssistTugs.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assist Tug yang Dipilih:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...selectedAssistTugs.map(
                              (tug) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${tug['name']} - ${tug['power']} HP / ${tug['bollard_pull']} TON',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          selectedAssistTugs.remove(tug);
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Tanggal *',
                        hintText: 'Pilih tanggal',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,

                        // suffix icon pakai asset PNG
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icons/calendar.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color.fromRGBO(0, 40, 120, 1),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                            final displayDate =
                                '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
                            dateController.text = displayDate;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Tanggal wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: timeController,
                      decoration: InputDecoration(
                        labelText: 'Waktu Pandu Naik Kapal *',
                        hintText: 'Pilih waktu',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icons/clock.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color.fromRGBO(0, 40, 120, 1),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                            final hour = picked.hour.toString().padLeft(2, '0');
                            final minute = picked.minute.toString().padLeft(
                              2,
                              '0',
                            );
                            timeController.text = '$hour:$minute';
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Waktu wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color.fromRGBO(0, 40, 120, 1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(0, 40, 120, 1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(
                                0,
                                40,
                                120,
                                1,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                                    'Simpan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Navbar tetap di atas
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
                        "Tambah Kegiatan Baru",
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color.fromRGBO(12, 10, 80, 1),
      ),
    );
  }
}
