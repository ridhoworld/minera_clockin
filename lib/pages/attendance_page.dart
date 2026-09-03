import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _today;

  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
  }

  // Mengambil status absensi hari ini khusus untuk user yang sedang login
  Future<void> _loadTodayAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Panggil endpoint /api/attendance/today alih-alih /api/attendances
      final todayData = await _apiService.getTodayAttendance();

      if (!mounted) return;

      setState(() {
        _today = todayData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('GPS belum aktif. Silakan aktifkan lokasi.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi diperlukan untuk absensi.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<File?> _takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (image == null) {
      return null;
    }

    return File(image.path);
  }

  Future<void> _clockIn() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final photo = await _takePhoto();

      if (photo == null) {
        throw Exception('Foto tidak diambil.');
      }

      final position = await _getLocation();

      await _apiService.clockIn(
        photo: photo,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      _showMessage('Clock In berhasil.');

      await _loadTodayAttendance();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _clockOut() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final photo = await _takePhoto();

      if (photo == null) {
        throw Exception('Foto tidak diambil.');
      }

      final position = await _getLocation();

      await _apiService.clockOut(
        photo: photo,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      _showMessage('Clock Out berhasil.');

      await _loadTodayAttendance();
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF0F766E),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0 jam';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes mnt';
    }

    if (remainingMinutes == 0) {
      return '$hours jam';
    }

    return '$hours jam $remainingMinutes mnt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Absensi Saya',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _loadTodayAttendance,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            )
          : RefreshIndicator(
              onRefresh: _loadTodayAttendance,
              color: const Color(0xFF0F766E),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [_buildTodayCard()],
              ),
            ),
    );
  }

  Widget _buildTodayCard() {
    if (_today == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Absensi Hari Ini',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda belum melakukan clock in hari ini.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _clockIn,
                icon: const Icon(Icons.login),
                label: Text(_isProcessing ? 'MEMPROSES...' : 'CLOCK IN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final clockIn = _today!['clock_in'];
    final clockOut = _today!['clock_out'];
    final isLate = _today!['is_late'] == true;
    final duration = int.tryParse('${_today!['work_duration'] ?? 0}') ?? 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Absensi Hari Ini',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildStatusBadge(isLate),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _timeInfo('Clock In', clockIn ?? '-', Icons.login),
              ),
              Expanded(
                child: _timeInfo('Clock Out', clockOut ?? '-', Icons.logout),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white70),
                const SizedBox(width: 10),
                const Text(
                  'Durasi Kerja',
                  style: TextStyle(color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (clockOut == null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _clockOut,
                icon: const Icon(Icons.logout),
                label: Text(_isProcessing ? 'MEMPROSES...' : 'CLOCK OUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isLate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLate ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isLate ? 'Terlambat' : 'Tepat Waktu',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isLate ? const Color(0xFFB45309) : const Color(0xFF15803D),
        ),
      ),
    );
  }

  Widget _timeInfo(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
