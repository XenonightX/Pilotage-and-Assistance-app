import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TambahPenundaanPage extends StatefulWidget {
  const TambahPenundaanPage({super.key});

  @override
  State<TambahPenundaanPage> createState() => _TambahPenundaanPageState();
}

class _TambahPenundaanPageState extends State<TambahPenundaanPage> {
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
  final jettyController = TextEditingController();
  final lastPortController = TextEditingController();
  final nextPortController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();

  // ✅ Controller untuk kapal tunda
  final assistTugNameController1 = TextEditingController();
  final enginePowerController1 = TextEditingController();
  final assistTugNameController2 = TextEditingController();
  final enginePowerController2 = TextEditingController();

  // ✅ Pilihan jumlah kapal tunda
  int tugCount = 1; // Default 1 kapal tunda

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedDirection = 'IN';
  String vesselType = 'Motor';
  bool _isLoading = false;

  final String baseUrl = 'http://192.168.0.9/pilotage_and_assistance_app/api';
  // final String baseUrl = 'http://192.168.1.15/pilotage_and_assistance_app/api';

  @override
  void initState() {
    super.initState();
    // ❌ TIDAK ADA auto-fill
  }

  @override
  void dispose() {
    vesselController.dispose();
    tugNameController.dispose();
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
    jettyController.dispose();
    lastPortController.dispose();
    nextPortController.dispose();
    dateController.dispose();
    timeController.dispose();
    assistTugNameController1.dispose();
    enginePowerController1.dispose();
    assistTugNameController2.dispose();
    enginePowerController2.dispose();
    super.dispose();
  }

Future<void> _submitData() async {
  if (!_formKey.currentState!.validate()) {
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
      fromWhere = 'Laut';
      toWhere = jettyController.text;
    } else {
      fromWhere = jettyController.text;
      toWhere = 'Laut';
    }

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
      "call_sign": callSignController.text.isEmpty ? null : callSignController.text,
      "master_name": masterController.text.isEmpty ? null : masterController.text,
      "flag": flagController.text,
      "gross_tonnage": grossTonnage,
      "agency": agencyController.text,
      "loa": loa,
      "fore_draft": foredraftController.text.isEmpty ? null : foredraftController.text,
      "aft_draft": aftdraftController.text.isEmpty ? null : aftdraftController.text,
      "from_where": fromWhere,
      "to_where": toWhere,
      "last_port": lastPortController.text,
      "next_port": nextPortController.text,
      "date": dbDate,
      "assistance_start": '$dbDate $dbTime',
      "status": "Terjadwal",
      "assist_tug_count": tugCount,
      "assist_tug_name_1": assistTugNameController1.text,
      "engine_power_1": enginePowerController1.text.isEmpty ? null : int.tryParse(enginePowerController1.text),
      "assist_tug_name_2": tugCount == 2 ? assistTugNameController2.text : null,
      "engine_power_2": (tugCount == 2 && enginePowerController2.text.isNotEmpty)
          ? int.tryParse(enginePowerController2.text)
          : null,
    };

    // ✅ PRINT DATA YANG DIKIRIM
    print('=== DATA DIKIRIM ===');
    print(jsonEncode(data));
    print('===================');

    final response = await http.post(
      Uri.parse('$baseUrl/add_assistances.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    // ✅ PRINT RESPONSE MENTAH
    print('=== RESPONSE STATUS ===');
    print('Status Code: ${response.statusCode}');
    print('=== RESPONSE BODY (RAW) ===');
    print(response.body);
    print('===========================');

    // ✅ CEK APAKAH RESPONSE VALID JSON
    if (response.body.trim().isEmpty) {
      throw Exception('Server mengembalikan response kosong');
    }

    // ✅ CEK APAKAH RESPONSE DIMULAI DENGAN '{'
    if (!response.body.trim().startsWith('{')) {
      throw Exception('Response bukan JSON. Response: ${response.body.substring(0, 200)}');
    }

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
      throw Exception(result['message'] ?? 'Gagal menambahkan data');
    }
  } catch (e) {
    print('=== ERROR ===');
    print(e.toString());
    print('=============');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan data: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
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

                    // Data Kapal Section
                    _buildSectionTitle('Data Kapal'),
                    const SizedBox(height: 16),

                    if (vesselType == 'Motor') ...[
                      TextFormField(
                        controller: vesselController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Kapal Motor *',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.directions_boat),
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
                        decoration: const InputDecoration(
                          labelText: 'Nama Tug Boat *',
                          hintText: 'Contoh: TB. Bintang Laut',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.directions_boat),
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
                        decoration: const InputDecoration(
                          labelText: 'Nama Tongkang *',
                          hintText: 'Contoh: BG. Jaya 01',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.anchor),
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

                    TextFormField(
                      controller: callSignController,
                      decoration: InputDecoration(
                        labelText: vesselType == 'Motor'
                            ? 'Call Sign / Nama Panggilan *'
                            : 'Call Sign / Nama Panggilan',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.radio),
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

                    TextFormField(
                      controller: masterController,
                      decoration: InputDecoration(
                        labelText: vesselType == 'Motor'
                            ? 'Nama Nahkoda *'
                            : 'Nama Nahkoda',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.person_outline),
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
                      decoration: const InputDecoration(
                        labelText: 'Bendera Kapal *',
                        hintText: 'Contoh: Indonesia, Singapore',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.flag),
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
                      decoration: const InputDecoration(
                        labelText: 'Keagenan Kapal *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Keagenan wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Gross Tonnage Section
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
                              prefixIcon: const Icon(Icons.directions_boat),
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

                          if (vesselType == 'Tug') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: gtBargeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GT Tongkang *',
                                hintText: 'Masukkan GT Tongkang',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.anchor),
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

                    // LOA Section
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
                              prefixIcon: const Icon(Icons.directions_boat),
                              suffixText: 'm',
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

                          if (vesselType == 'Tug') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: loaBargeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'LOA Tongkang (meter) *',
                                hintText: 'Panjang Tongkang',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.anchor),
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

                    // Draft Section
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
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Color.fromARGB(255, 255, 0, 0),
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

                          TextFormField(
                            controller: foredraftController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Sarat Muka (meter)',
                              hintText: 'Opsional',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.straighten),
                              suffixText: 'm',
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: aftdraftController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Sarat Belakang (meter)',
                              hintText: 'Opsional',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(Icons.straighten),
                              suffixText: 'm',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ SECTION KAPAL TUNDA
                    _buildSectionTitle('Informasi Penundaan'),
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
                                Icons.anchor,
                                size: 20,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Kapal Tunda',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ✅ Pilihan Jumlah Kapal Tunda
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jumlah Kapal Tunda *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[900],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<int>(
                                        title: const Text('1 Kapal Tunda'),
                                        value: 1,
                                        groupValue: tugCount,
                                        onChanged: (value) {
                                          setState(() {
                                            tugCount = value!;
                                            if (tugCount == 1) {
                                              assistTugNameController2.clear();
                                              enginePowerController2.clear();
                                            }
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
                                      child: RadioListTile<int>(
                                        title: const Text('2 Kapal Tunda'),
                                        value: 2,
                                        groupValue: tugCount,
                                        onChanged: (value) {
                                          setState(() {
                                            tugCount = value!;
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
                          const SizedBox(height: 20),

                          // ✅ Kapal Tunda 1 (Selalu tampil, TIDAK readonly)
                          Text(
                            'Kapal Tunda 1',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),

                          TextFormField(
                            controller: assistTugNameController1,
                            // ❌ TIDAK ADA readOnly
                            decoration: const InputDecoration(
                              labelText: 'Nama Kapal Tunda 1 *',
                              hintText: 'Contoh: TB. Samudra 01',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors
                                  .white, // ❌ TIDAK ADA conditional fillColor
                              prefixIcon: Icon(Icons.directions_boat),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama kapal tunda 1 wajib diisi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: enginePowerController1,
                            // ❌ TIDAK ADA readOnly
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tenaga Mesin Tunda 1 (HP/BHP)',
                              hintText: 'Opsional',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors
                                  .white, // ❌ TIDAK ADA conditional fillColor
                              prefixIcon: Icon(Icons.power),
                              suffixText: 'HP',
                            ),
                          ),

                          // ✅ Kapal Tunda 2 (Conditional)
                          if (tugCount == 2) ...[
                            const SizedBox(height: 20),
                            Text(
                              'Kapal Tunda 2',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[900],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              controller: assistTugNameController2,
                              decoration: const InputDecoration(
                                labelText: 'Nama Kapal Tunda 2 *',
                                hintText: 'Contoh: TB. Samudra 02',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.directions_boat),
                              ),
                              validator: (value) {
                                if (tugCount == 2 &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Nama kapal tunda 2 wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: enginePowerController2,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tenaga Mesin Tunda 2 (HP/BHP)',
                                hintText: 'Opsional',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.power),
                                suffixText: 'HP',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rest of form fields (Arah, Jetty, Port, Date, Time)
                    DropdownButtonFormField<String>(
                      initialValue: selectedDirection,
                      decoration: const InputDecoration(
                        labelText: 'Arah Pemanduan *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.swap_horiz),
                      ),
                      items: ['IN', 'OUT']
                          .map(
                            (direction) => DropdownMenuItem(
                              value: direction,
                              child: Text(
                                direction == 'IN'
                                    ? 'IN (Masuk dari Laut ke Jetty)'
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
                      decoration: InputDecoration(
                        labelText: 'Nama Jetty *',
                        hintText: selectedDirection == 'IN'
                            ? 'Jetty tujuan (contoh: Jetty Batu Ampar)'
                            : 'Jetty asal (contoh: Jetty Batu Ampar)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.anchor),
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
                      decoration: const InputDecoration(
                        labelText: 'Pelabuhan Asal *',
                        hintText: 'Contoh: Singapore, Jakarta',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.location_on),
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
                      decoration: const InputDecoration(
                        labelText: 'Pelabuhan Tujuan *',
                        hintText: 'Contoh: Batam, Singapore',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.place),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Pelabuhan tujuan wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal *',
                        hintText: 'Pilih tanggal',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.calendar_today),
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
                      decoration: const InputDecoration(
                        labelText: 'Waktu Penundaan *',
                        hintText: 'Pilih waktu',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: Icon(Icons.access_time),
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
                        "Tambah Penundaan Baru",
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
