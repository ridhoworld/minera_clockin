import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../services/api_service.dart';

class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  State<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _attendances = [];
  List<Map<String, dynamic>> _filteredAttendances = [];

  bool _isLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterData);

    _loadAttendances();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterData);
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _exportExcel() async {
    if (_filteredAttendances.isEmpty) {
      _showMessage('Tidak ada data absensi untuk diexport.', true);
      return;
    }

    try {
      final excel = ex.Excel.createExcel();

      // Hapus sheet default
      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null) {
        excel.delete(defaultSheet);
      }

      final sheet = excel['Data Absensi'];

      // HEADER
      final headers = [
        'No',
        'Nama',
        'Username',
        'Tanggal',
        'Clock In',
        'Clock Out',
        'Durasi Kerja',
        'Status',
        'Terlambat',
        'Durasi Terlambat',
        'Latitude In',
        'Longitude In',
        'Latitude Out',
        'Longitude Out',
        'Catatan',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(ex.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = ex.TextCellValue(
          headers[i],
        );
      }

      // DATA
      for (int index = 0; index < _filteredAttendances.length; index++) {
        final item = _filteredAttendances[index];

        final user = item['user'] is Map
            ? Map<String, dynamic>.from(item['user'])
            : <String, dynamic>{};

        final row = [
          index + 1,
          user['name'] ?? '-',
          user['username'] ?? '-',
          _displayDate(item['date']),
          item['clock_in'] ?? '-',
          item['clock_out'] ?? '-',
          _formatDuration(item['work_duration']),
          _formatStatus(item['status']),
          item['is_late'] == true ? 'Ya' : 'Tidak',
          '${item['late_duration'] ?? 0} menit',
          item['latitude_in'] ?? '-',
          item['longitude_in'] ?? '-',
          item['latitude_out'] ?? '-',
          item['longitude_out'] ?? '-',
          item['notes'] ?? '-',
        ];

        for (int column = 0; column < row.length; column++) {
          sheet
              .cell(
                ex.CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: index + 1,
                ),
              )
              .value = ex.TextCellValue(
            row[column].toString(),
          );
        }
      }

      final bytes = excel.encode();

      if (bytes == null) {
        throw Exception('Gagal membuat file Excel.');
      }

      final directory = await getTemporaryDirectory();

      final start = _startDate != null ? _formatDate(_startDate!) : 'semua';

      final end = _endDate != null ? _formatDate(_endDate!) : 'tanggal';

      final fileName = 'data_absensi_${start}_sampai_$end.xlsx';

      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Data Absensi',
        text: 'Export data absensi',
      );

      if (!mounted) return;

      _showMessage(
        'Excel berhasil dibuat '
        '(${_filteredAttendances.length} data).',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal export Excel: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        true,
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_filteredAttendances.isEmpty) {
      _showMessage('Tidak ada data absensi untuk diexport.', true);
      return;
    }

    try {
      final pdf = pw.Document();

      // ============================================================
      // CEK FILTER PERIODE
      // ============================================================

      final bool hasPeriodFilter = _startDate != null || _endDate != null;

      final String startDate = _startDate != null
          ? _formatDate(_startDate!)
          : '';

      final String endDate = _endDate != null ? _formatDate(_endDate!) : '';

      String periodText = '';

      if (hasPeriodFilter) {
        if (_startDate != null && _endDate != null) {
          periodText = 'Periode: $startDate s/d $endDate';
        } else if (_startDate != null) {
          periodText = 'Periode: mulai $startDate';
        } else if (_endDate != null) {
          periodText = 'Periode: sampai $endDate';
        }
      }

      // ============================================================
      // SIAPKAN DATA TABLE
      // ============================================================

      final List<List<pw.Widget>> tableData = [];

      for (int index = 0; index < _filteredAttendances.length; index++) {
        final item = _filteredAttendances[index];

        final user = item['user'] is Map
            ? Map<String, dynamic>.from(item['user'])
            : <String, dynamic>{};

        // ==========================================================
        // LOAD FOTO CLOCK IN
        // ==========================================================

        final pw.MemoryImage? photoIn = await _loadPdfImage(item['photo_in']);

        // ==========================================================
        // LOAD FOTO CLOCK OUT
        // ==========================================================

        final pw.MemoryImage? photoOut = await _loadPdfImage(item['photo_out']);

        // ==========================================================
        // FOTO CLOCK IN
        // ==========================================================

        final pw.Widget photoInWidget = photoIn != null
            ? pw.Container(
                width: 55,
                height: 65,
                alignment: pw.Alignment.center,
                child: pw.Image(photoIn, fit: pw.BoxFit.cover),
              )
            : pw.Container(
                width: 55,
                height: 65,
                alignment: pw.Alignment.center,
                child: pw.Text('-', style: const pw.TextStyle(fontSize: 7)),
              );

        // ==========================================================
        // FOTO CLOCK OUT
        // ==========================================================

        final pw.Widget photoOutWidget = photoOut != null
            ? pw.Container(
                width: 55,
                height: 65,
                alignment: pw.Alignment.center,
                child: pw.Image(photoOut, fit: pw.BoxFit.cover),
              )
            : pw.Container(
                width: 55,
                height: 65,
                alignment: pw.Alignment.center,
                child: pw.Text('-', style: const pw.TextStyle(fontSize: 7)),
              );

        // ==========================================================
        // DATA TABLE
        // ==========================================================

        tableData.add([
          // NO
          pw.Center(
            child: pw.Text(
              '${index + 1}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),

          // NAMA
          pw.Text(
            '${user['name'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 7),
          ),

          // TANGGAL
          pw.Text(
            _displayDate(item['date']),
            style: const pw.TextStyle(fontSize: 7),
          ),

          // CLOCK IN
          pw.Text(
            '${item['clock_in'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 7),
          ),

          // FOTO IN
          photoInWidget,

          // LATITUDE IN
          // LOKASI IN
          pw.Text(
            '${item['latitude_in'] ?? '-'}, ${item['longitude_in'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 6),
          ),

          // CLOCK OUT
          pw.Text(
            '${item['clock_out'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 7),
          ),

          // FOTO OUT
          photoOutWidget,

          // LATITUDE OUT
          // LOKASI OUT
          pw.Text(
            '${item['latitude_out'] ?? '-'}, ${item['longitude_out'] ?? '-'}',
            style: const pw.TextStyle(fontSize: 6),
          ),

          // DURASI
          pw.Text(
            _formatDuration(item['work_duration']),
            style: const pw.TextStyle(fontSize: 7),
          ),

          // STATUS
          pw.Text(
            _formatStatus(item['status']),
            style: const pw.TextStyle(fontSize: 7),
          ),

          // TERLAMBAT
          pw.Text(
            item['is_late'] == true ? '${item['late_duration'] ?? 0} mnt' : '-',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ]);
      }

      // ============================================================
      // PDF
      // ============================================================

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(24),

          build: (context) {
            return [
              // ======================================================
              // JUDUL
              // ======================================================
              pw.Text(
                'LAPORAN DATA ABSENSI',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 6),

              // ======================================================
              // PERIODE
              // HANYA MUNCUL JIKA ADA FILTER
              // ======================================================
              if (hasPeriodFilter) ...[
                pw.Text(periodText, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 2),
              ],

              // ======================================================
              // JUMLAH DATA
              // ======================================================
              pw.Text(
                'Jumlah data: ${_filteredAttendances.length}',
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 18),

              // ======================================================
              // TABLE
              // ======================================================
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),

                columnWidths: const {
                  0: pw.FixedColumnWidth(25), // No
                  1: pw.FixedColumnWidth(85), // Nama
                  2: pw.FixedColumnWidth(60), // Tanggal
                  3: pw.FixedColumnWidth(50), // Clock In
                  4: pw.FixedColumnWidth(80), // Foto In
                  5: pw.FixedColumnWidth(90), // Lokasi In
                  6: pw.FixedColumnWidth(50), // Clock Out
                  7: pw.FixedColumnWidth(80), // Foto Out
                  8: pw.FixedColumnWidth(90), // Lokasi Out
                  9: pw.FixedColumnWidth(50), // Durasi
                  10: pw.FixedColumnWidth(55), // Status
                  11: pw.FixedColumnWidth(50), //
                },

                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children:
                        [
                          'No',
                          'Nama',
                          'Tanggal',
                          'Clock In',
                          'Foto In',
                          'Lokasi In',
                          'Clock Out',
                          'Foto Out',
                          'Lokasi Out',
                          'Durasi',
                          'Status',
                          'Terlambat',
                        ].map((header) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              header,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                  ),

                  // ==================================================
                  // DATA
                  // ==================================================
                  ...tableData.map((row) {
                    return pw.TableRow(
                      children: row.map((cell) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          alignment: pw.Alignment.center,
                          child: cell,
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // ======================================================
              // TANGGAL CETAK
              // ======================================================
              pw.Text(
                'Dicetak pada: ${_formatDate(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ];
          },
        ),
      );

      // ============================================================
      // SAVE PDF
      // ============================================================

      final bytes = await pdf.save();

      await Printing.sharePdf(bytes: bytes, filename: 'data_absensi.pdf');

      if (!mounted) return;

      _showMessage(
        'PDF berhasil dibuat '
        '(${_filteredAttendances.length} data).',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal export PDF: '
        '${e.toString().replaceFirst('Exception: ', '')}',
        true,
      );
    }
  }

  String? _photoUrl(dynamic photo) {
    if (photo == null) {
      debugPrint('PHOTO: null');
      return null;
    }

    final path = photo.toString().trim();

    if (path.isEmpty) {
      debugPrint('PHOTO: kosong');
      return null;
    }

    debugPrint('PHOTO PATH DARI API: $path');

    // API sudah memberikan URL lengkap
    if (path.startsWith('http://') || path.startsWith('https://')) {
      debugPrint('PHOTO URL FINAL: $path');
      return path;
    }

    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';

    if (baseUrl.isEmpty) {
      debugPrint('ERROR: API_BASE_URL kosong');
      return null;
    }

    // Hilangkan trailing /
    final cleanBaseUrl = baseUrl.replaceFirst(RegExp(r'\/+$'), '');

    // Path dari API misalnya:
    // attendances/abc.jpg

    final cleanPath = path.replaceFirst(RegExp(r'^\/+'), '');

    final url = '$cleanBaseUrl/storage/$cleanPath';

    debugPrint('PHOTO URL FINAL: $url');

    return url;
  }

  Future<pw.MemoryImage?> _loadPdfImage(dynamic photo) async {
    // Gunakan fungsi _photoUrl() yang sama dengan tampilan detail
    final photoUrl = _photoUrl(photo);

    if (photoUrl == null || photoUrl.isEmpty) {
      debugPrint('PDF PHOTO: URL tidak tersedia');
      return null;
    }

    try {
      debugPrint('PDF PHOTO URL: $photoUrl');

      final dio = Dio();

      final response = await dio.get<List<int>>(
        photoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          validateStatus: (status) {
            return status != null && status >= 200 && status < 400;
          },
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        debugPrint('PDF PHOTO: data kosong');
        return null;
      }

      debugPrint('PDF PHOTO BERHASIL: ${response.data!.length} bytes');

      return pw.MemoryImage(Uint8List.fromList(response.data!));
    } catch (e, stackTrace) {
      debugPrint('=================================');
      debugPrint('GAGAL LOAD FOTO UNTUK PDF');
      debugPrint('URL: $photoUrl');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('=================================');

      return null;
    }
  }
  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadAttendances() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _apiService.getAttendances();

      if (!mounted) return;

      setState(() {
        _attendances = data;
        _isLoading = false;
      });

      _filterData();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''), true);
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _filterData() {
    final search = _searchController.text.trim().toLowerCase();

    final filtered = _attendances.where((item) {
      final user = item['user'] is Map
          ? Map<String, dynamic>.from(item['user'])
          : <String, dynamic>{};

      final name = '${user['name'] ?? ''}'.toLowerCase();
      final username = '${user['username'] ?? ''}'.toLowerCase();

      final dateText = _displayDate(item['date']).toLowerCase();

      final matchesSearch =
          search.isEmpty ||
          name.contains(search) ||
          username.contains(search) ||
          dateText.contains(search);

      final itemDate = _parseDate(item['date']);

      bool matchesDate = true;

      if (_startDate != null && itemDate != null) {
        final start = DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        );

        if (itemDate.isBefore(start)) {
          matchesDate = false;
        }
      }

      if (_endDate != null && itemDate != null) {
        final end = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );

        if (itemDate.isAfter(end)) {
          matchesDate = false;
        }
      }

      return matchesSearch && matchesDate;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredAttendances = filtered;
    });
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      final parsed = DateTime.parse(value.toString());

      // Konversi ke WIB
      return parsed.toUtc().add(const Duration(hours: 7));
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;

      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });

    _filterData();
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _endDate = picked;
    });

    _filterData();
  }

  void _resetFilter() {
    _searchController.clear();

    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredAttendances = _attendances;
    });
  }

  // ============================================================
  // DETAIL
  // ============================================================

  void _showDetail(Map<String, dynamic> item) {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'])
        : <String, dynamic>{};

    // LOKASI CLOCK IN
    final clockInLatitude = _toDouble(item['latitude_in']);

    final clockInLongitude = _toDouble(item['longitude_in']);

    // LOKASI CLOCK OUT
    final clockOutLatitude = _toDouble(item['latitude_out']);

    final clockOutLongitude = _toDouble(item['longitude_out']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.60,
          maxChildSize: 0.97,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // HANDLE
                    // ==================================================
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // USER
                    // ==================================================
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFFE6FFFB),
                          child: Text(
                            _initials('${user['name'] ?? 'User'}'),
                            style: const TextStyle(
                              color: Color(0xFF0F766E),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user['name'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                '@${user['username'] ?? '-'}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // INFORMASI ABSENSI
                    // ==================================================
                    _sectionTitle('Informasi Absensi'),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _detailRow(
                            Icons.calendar_today_outlined,
                            'Tanggal',
                            _displayDate(item['date']),
                          ),

                          _detailRow(
                            Icons.login,
                            'Clock In',
                            '${item['clock_in'] ?? '-'}',
                          ),

                          _detailRow(
                            Icons.logout,
                            'Clock Out',
                            '${item['clock_out'] ?? '-'}',
                          ),

                          _detailRow(
                            Icons.timer_outlined,
                            'Durasi Kerja',
                            _formatDuration(item['work_duration']),
                          ),

                          _detailRow(
                            Icons.info_outline,
                            'Status',
                            _formatStatus(item['status']),
                          ),

                          _detailRow(
                            Icons.warning_amber_outlined,
                            'Keterlambatan',
                            item['is_late'] == true
                                ? '${item['late_duration'] ?? 0} menit'
                                : 'Tidak terlambat',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),
                    // ==================================================
                    // FOTO CLOCK IN
                    // ==================================================
                    _sectionTitle('Foto Clock In'),
                    const SizedBox(height: 10),

                    _buildAttendancePhoto(
                      title: 'Clock In',
                      photo: item['photo_in'],
                      icon: Icons.camera_alt_outlined,
                    ),

                    const SizedBox(height: 26),
                    // ==================================================
                    // LOKASI CLOCK IN
                    // ==================================================
                    _sectionTitle('Lokasi Clock In'),

                    const SizedBox(height: 10),

                    if (clockInLatitude != null && clockInLongitude != null)
                      _buildLocationMap(
                        latitude: clockInLatitude,
                        longitude: clockInLongitude,
                        title: 'Lokasi saat Clock In',
                      )
                    else
                      _buildNoLocation('Lokasi Clock In belum tersedia'),

                    const SizedBox(height: 24),

                    // ==================================================
                    // LOKASI CLOCK OUT
                    // ==================================================
                    _sectionTitle('Lokasi Clock Out'),

                    const SizedBox(height: 10),

                    if (clockOutLatitude != null && clockOutLongitude != null)
                      _buildLocationMap(
                        latitude: clockOutLatitude,
                        longitude: clockOutLongitude,
                        title: 'Lokasi saat Clock Out',
                      )
                    else
                      _buildNoLocation('Lokasi Clock Out belum tersedia'),

                    const SizedBox(height: 24),
                    // ==================================================
                    // FOTO CLOCK OUT
                    // ==================================================
                    const SizedBox(height: 26),

                    _sectionTitle('Foto Clock Out'),
                    const SizedBox(height: 10),

                    _buildAttendancePhoto(
                      title: 'Clock Out',
                      photo: item['photo_out'],
                      icon: Icons.camera_alt_outlined,
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // CATATAN
                    // ==================================================
                    _sectionTitle('Catatan'),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item['notes']?.toString().trim().isNotEmpty == true
                            ? item['notes'].toString()
                            : '-',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // LOCATION MAP
  // ============================================================

  Widget _buildLocationMap({
    required double latitude,
    required double longitude,
    required String title,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xFF0F766E)),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(latitude, longitude),
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.minera_clockin',
                ),

                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude, longitude),
                      width: 55,
                      height: 55,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(child: _coordinateInfo('Latitude', latitude)),

              Expanded(child: _coordinateInfo('Longitude', longitude)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordinateInfo(String title, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),

        const SizedBox(height: 4),

        Text(
          value.toStringAsFixed(6),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildNoLocation(String message) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 40,
            color: Color(0xFF94A3B8),
          ),

          const SizedBox(height: 10),

          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Koordinat belum dikirim oleh server.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendancePhoto({
    required String title,
    required dynamic photo,
    required IconData icon,
  }) {
    final photoUrl = _photoUrl(photo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (photoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: 280,
              color: const Color(0xFFF1F5F9),
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0F766E),
                        ),
                      );
                    },
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      debugPrint('=================================');
                      debugPrint('GAGAL LOAD FOTO');
                      debugPrint('URL: $photoUrl');
                      debugPrint('ERROR: $error');
                      debugPrint('STACK: $stackTrace');
                      debugPrint('=================================');

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image_outlined,
                                size: 42,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Foto gagal dimuat',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                photoUrl,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(height: 10),
                Text(
                  'Foto belum tersedia',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 6),

        if (photoUrl != null)
          Text(
            'Foto diambil saat $title',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
      ],
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteAttendance(Map<String, dynamic> item) async {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'])
        : <String, dynamic>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Hapus Absensi?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Hapus absensi ${user['name'] ?? '-'} '
            'pada ${_displayDate(item['date'])}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteAttendance(item['id']);

      if (!mounted) return;

      _showMessage('Absensi berhasil dihapus.');

      await _loadAttendances();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), true);
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editAttendance(Map<String, dynamic> item) async {
    final clockInController = TextEditingController(
      text: item['clock_in']?.toString() ?? '',
    );

    final clockOutController = TextEditingController(
      text: item['clock_out']?.toString() ?? '',
    );

    final lateController = TextEditingController(
      text: '${item['late_duration'] ?? 0}',
    );

    final workController = TextEditingController(
      text: '${item['work_duration'] ?? 0}',
    );

    final notesController = TextEditingController(
      text: item['notes']?.toString() ?? '',
    );

    String status = item['status']?.toString() ?? 'present';

    bool isLate =
        item['is_late'] == true ||
        item['is_late'] == 1 ||
        item['is_late']?.toString() == '1';

    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Edit Absensi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                content: SizedBox(
                  width: 420,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            item['user']?['name']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),

                          const SizedBox(height: 18),

                          // STATUS
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text('Hadir'),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text('Tidak Hadir'),
                              ),
                              DropdownMenuItem(
                                value: 'sick',
                                child: Text('Sakit'),
                              ),
                              DropdownMenuItem(
                                value: 'leave',
                                child: Text('Izin'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                status = value;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // CLOCK IN
                          TextFormField(
                            controller: clockInController,
                            decoration: const InputDecoration(
                              labelText: 'Clock In',
                              hintText: '08:00:00',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // CLOCK OUT
                          TextFormField(
                            controller: clockOutController,
                            decoration: const InputDecoration(
                              labelText: 'Clock Out',
                              hintText: '17:00:00',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // TERLAMBAT
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Terlambat'),
                            value: isLate,
                            onChanged: (value) {
                              setDialogState(() {
                                isLate = value;
                              });
                            },
                          ),

                          // DURASI TERLAMBAT
                          TextFormField(
                            controller: lateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durasi Terlambat (menit)',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // DURASI KERJA
                          TextFormField(
                            controller: workController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durasi Kerja (menit)',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // CATATAN
                          TextFormField(
                            controller: notesController,
                            maxLines: 3,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Catatan',
                              hintText: 'Masukkan catatan...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                actions: [
                  // BATAL
                  TextButton(
                    onPressed: () {
                      FocusScope.of(dialogContext).unfocus();

                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('Batal'),
                  ),

                  // SIMPAN
                  ElevatedButton(
                    onPressed: () async {
                      // Validasi form
                      if (formKey.currentState?.validate() != true) {
                        return;
                      }

                      // Ambil semua nilai terlebih dahulu
                      final clockIn = clockInController.text.trim();
                      final clockOut = clockOutController.text.trim();
                      final notes = notesController.text.trim();

                      final lateDuration =
                          int.tryParse(lateController.text.trim()) ?? 0;

                      final workDuration =
                          int.tryParse(workController.text.trim()) ?? 0;

                      // Hilangkan keyboard/focus
                      FocusScope.of(dialogContext).unfocus();

                      // Tunggu Flutter menyelesaikan perubahan focus
                      await Future<void>.delayed(
                        const Duration(milliseconds: 150),
                      );

                      try {
                        await _apiService.updateAttendance(
                          id: item['id'],
                          date: '${item['date']}',
                          status: status,
                          clockIn: clockIn,
                          clockOut: clockOut,
                          isLate: isLate,
                          lateDuration: lateDuration,
                          workDuration: workDuration,
                          notes: notes,
                        );

                        if (!dialogContext.mounted) return;

                        // Jangan snackbar / reload di dalam dialog.
                        // Cukup tutup dialog dan kirim hasil true.
                        Navigator.of(dialogContext).pop(true);
                      } catch (e) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          );
        },
      );

      // ============================================================
      // Dialog sudah benar-benar ditutup di sini
      // Baru dispose controller
      // ============================================================

      if (!mounted) return;

      if (result == true) {
        _showMessage('Absensi berhasil diperbarui.');

        await _loadAttendances();
      }
    } finally {
      // Dispose masing-masing controller SATU KALI
      clockInController.dispose();
      clockOutController.dispose();
      lateController.dispose();
      workController.dispose();
      notesController.dispose();
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Manajemen Absensi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),

        actions: [
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.download_outlined),
            onSelected: (value) {
              if (value == 'excel') {
                _exportExcel();
              } else if (value == 'pdf') {
                _exportPdf();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: Colors.green),
                    SizedBox(width: 10),
                    Text('Export Excel'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Export PDF'),
                  ],
                ),
              ),
            ],
          ),

          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAttendances,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          _buildFilter(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  )
                : _filteredAttendances.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data absensi.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAttendances,
                    color: const Color(0xFF0F766E),

                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                      itemCount: _filteredAttendances.length,
                      itemBuilder: (context, index) {
                        return _buildCard(_filteredAttendances[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER UI
  // ============================================================

  Widget _buildFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),

      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama crew / username / tanggal...',
              prefixIcon: const Icon(Icons.search),

              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,

              filled: true,
              fillColor: const Color(0xFFF8FAFC),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F766E)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _dateButton(
                  icon: Icons.calendar_today_outlined,
                  label: _startDate == null
                      ? 'Tanggal awal'
                      : _formatDate(_startDate!),
                  onTap: _selectStartDate,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _dateButton(
                  icon: Icons.event_outlined,
                  label: _endDate == null
                      ? 'Tanggal akhir'
                      : _formatDate(_endDate!),
                  onTap: _selectEndDate,
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Reset filter',
                onPressed: _resetFilter,

                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                ),

                icon: const Icon(
                  Icons.filter_alt_off_outlined,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _filteredAttendances.isEmpty ? null : _exportExcel,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _filteredAttendances.isEmpty ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),

        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),

        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0F766E)),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildCard(Map<String, dynamic> item) {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'])
        : <String, dynamic>{};

    final isLate = item['is_late'] == true;

    // SESUAI RESPONSE API
    final latitudeIn = _toDouble(item['latitude_in']);

    final longitudeIn = _toDouble(item['longitude_in']);

    final latitudeOut = _toDouble(item['latitude_out']);

    final longitudeOut = _toDouble(item['longitude_out']);

    final hasLocationIn = latitudeIn != null && longitudeIn != null;

    final hasLocationOut = latitudeOut != null && longitudeOut != null;

    final hasLocation = hasLocationIn || hasLocationOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),

      child: Column(
        children: [
          // ========================================================
          // HEADER
          // ========================================================
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE6FFFB),

                child: Text(
                  _initials('${user['name'] ?? 'User'}'),
                  style: const TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['name'] ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _displayDate(item['date']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'detail') {
                    _showDetail(item);
                  }

                  if (value == 'edit') {
                    _editAttendance(item);
                  }

                  if (value == 'delete') {
                    _deleteAttendance(item);
                  }
                },

                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'detail', child: Text('Detail')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),

          const Divider(height: 24),

          // ========================================================
          // INFO
          // ========================================================
          Row(
            children: [
              Expanded(child: _info('Clock In', item['clock_in'] ?? '-')),

              Expanded(child: _info('Clock Out', item['clock_out'] ?? '-')),

              Expanded(
                child: _info('Durasi', _formatDuration(item['work_duration'])),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ========================================================
          // STATUS
          // ========================================================
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

                decoration: BoxDecoration(
                  color: isLate
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFECFDF5),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  isLate ? 'Terlambat' : 'Tepat Waktu',

                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isLate
                        ? const Color(0xFFB45309)
                        : const Color(0xFF047857),
                  ),
                ),
              ),

              const Spacer(),

              if (hasLocation)
                TextButton.icon(
                  onPressed: () {
                    _showDetail(item);
                  },

                  icon: const Icon(Icons.location_on_outlined, size: 17),

                  label: const Text('Lihat Lokasi'),

                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),

      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F766E)),

          const SizedBox(width: 12),

          SizedBox(
            width: 105,
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String title, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),

        const SizedBox(height: 4),

        Text(
          '$value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String _formatDuration(dynamic value) {
    final minutes = int.tryParse('$value') ?? 0;

    if (minutes <= 0) {
      return '0 jam';
    }

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    if (hours == 0) {
      return '$remaining mnt';
    }

    if (remaining == 0) {
      return '$hours jam';
    }

    return '$hours jam $remaining mnt';
  }

  String _formatStatus(dynamic status) {
    switch ('$status') {
      case 'present':
        return 'Hadir';

      case 'absent':
        return 'Tidak Hadir';

      case 'sick':
        return 'Sakit';

      case 'leave':
        return 'Izin';

      default:
        return '$status';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _displayDate(dynamic value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      return '-';
    }

    return _formatDate(parsed);
  }

  String _initials(String name) {
    final clean = name.trim();

    if (clean.isEmpty) {
      return '?';
    }

    final parts = clean.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length > 1 ? 2 : 1)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _showMessage(String message, [bool isError = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF0F766E),
      ),
    );
  }
}
