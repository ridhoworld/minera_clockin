import 'package:flutter/material.dart';
import 'package:minera_clockin/pages/attendance_management_page.dart';
import 'package:minera_clockin/pages/attendance_page.dart';
import 'package:minera_clockin/pages/user_management_page.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  String _formatAttendanceDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return '-';
    }

    final raw = value.toString();

    try {
      final date = DateTime.parse(raw);

      const days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];

      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${days[date.weekday - 1]}, '
          '${date.day.toString().padLeft(2, '0')} '
          '${months[date.month - 1]} '
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatDuration(dynamic value) {
    final minutes = int.tryParse('${value ?? 0}') ?? 0;

    if (minutes <= 0) {
      return '0 menit';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0 && remainingMinutes > 0) {
      return '$hours jam $remainingMinutes mnt';
    }

    if (hours > 0) {
      return '$hours jam';
    }

    return '$remainingMinutes menit';
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Panggil fungsi getDashboard() dari ApiService Anda
      final response = await _apiService.getDashboard();
      setState(() {
        _dashboardData = response['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun ini?',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    // User menekan Batal atau menutup dialog
    if (confirm != true) return;

    if (!mounted) return;

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  SizedBox(width: 20),
                  Text(
                    'Sedang keluar...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Gagal request logout: $e');
    } finally {
      if (!mounted) return;

      // Tutup loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Kembali ke login dan hapus semua halaman sebelumnya
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'MINERA CLOCKIN',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: const Color(0xFF0F766E),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F766E)),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchDashboardData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final role = _dashboardData?['role'];

    if (role == 'admin') {
      return _buildAdminDashboard();
    } else {
      return _buildBargeCrewDashboard();
    }
  }

  // ==========================================
  // DASHBOARD ADMIN
  // ==========================================
  Widget _buildAdminDashboard() {
    final user = _dashboardData?['user'];
    final stats = _dashboardData?['statistics'] ?? {};
    final recentAttendances =
        _dashboardData?['recent_attendances'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          Text(
            'Halo, ${user?['name'] ?? 'Admin'}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Text(
            'Berikut ringkasan presensi hari ini.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard(
                'Total Crew',
                '${stats['total_barge_crew'] ?? 0}',
                Icons.people,
                const Color(0xFF0284C7),
              ),
              _buildStatCard(
                'Hadir Hari Ini',
                '${stats['present_today'] ?? 0}',
                Icons.check_circle,
                const Color(0xFF16A34A),
              ),
              _buildStatCard(
                'Terlambat',
                '${stats['late_today'] ?? 0}',
                Icons.warning_amber,
                const Color(0xFFD97706),
              ),
              _buildStatCard(
                'Belum Absen',
                '${stats['not_clocked_in_today'] ?? 0}',
                Icons.cancel,
                const Color(0xFFDC2626),
              ),
            ],
          ),

          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(
              Icons.people_alt_outlined,
              color: Color(0xFF0F766E),
            ),
            title: const Text('Manajemen User'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(
              Icons.assignment_turned_in_outlined,
              color: Color(0xFF0F766E),
            ),
            title: const Text('Manajemen Attendance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceManagementPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Presensi Terbaru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          // Recent Attendance List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentAttendances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = recentAttendances[index];
              final userName = item['user']?['name'] ?? 'Crew';
              final clockIn = item['clock_in'] ?? '-';
              final clockOut = item['clock_out'] ?? 'Belum Clock Out';
              final isLate = item['is_late'] ?? false;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFCCFBF1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('In: $clockIn | Out: $clockOut'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLate
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLate ? 'Late' : 'On Time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLate
                            ? const Color(0xFFB45309)
                            : const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistory(List history) {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 28,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Belum Ada Riwayat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Riwayat absensi Anda akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(history.length, (index) {
        final item = Map<String, dynamic>.from(history[index] as Map);

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == history.length - 1 ? 0 : 12,
          ),
          child: _buildAttendanceHistoryCard(item),
        );
      }),
    );
  }

  Widget _buildAttendanceHistoryCard(Map<String, dynamic> item) {
    final date = item['date'];

    final clockIn = item['clock_in'];
    final clockOut = item['clock_out'];

    final status = '${item['status'] ?? 'absent'}'.toLowerCase();

    final isLate = item['is_late'] == true;

    final workDuration = item['work_duration'];

    final lateDuration = item['late_duration'];

    Color statusColor;
    Color statusBackground;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'present':
        statusColor = const Color(0xFF15803D);
        statusBackground = const Color(0xFFDCFCE7);
        statusText = 'Hadir';
        statusIcon = Icons.check_circle_rounded;
        break;

      case 'sick':
        statusColor = const Color(0xFF2563EB);
        statusBackground = const Color(0xFFDBEAFE);
        statusText = 'Sakit';
        statusIcon = Icons.medical_services_rounded;
        break;

      case 'leave':
        statusColor = const Color(0xFFD97706);
        statusBackground = const Color(0xFFFEF3C7);
        statusText = 'Izin';
        statusIcon = Icons.event_available_rounded;
        break;

      default:
        statusColor = const Color(0xFFDC2626);
        statusBackground = const Color(0xFFFEE2E2);
        statusText = 'Tidak Hadir';
        statusIcon = Icons.cancel_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // HEADER
          // =========================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF0F766E),
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  _formatAttendanceDate(date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =========================
          // CLOCK IN / OUT
          // =========================
          Row(
            children: [
              Expanded(
                child: _buildAttendanceTimeBox(
                  icon: Icons.login_rounded,
                  title: 'Clock In',
                  value: clockIn?.toString() ?? '--:--',
                  iconColor: const Color(0xFF0F766E),
                  backgroundColor: const Color(0xFFF0FDFA),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _buildAttendanceTimeBox(
                  icon: Icons.logout_rounded,
                  title: 'Clock Out',
                  value: clockOut?.toString() ?? '--:--',
                  iconColor: const Color(0xFF475569),
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // =========================
          // DURASI
          // =========================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: Color(0xFF64748B),
                ),

                const SizedBox(width: 9),

                const Expanded(
                  child: Text(
                    'Durasi Kerja',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),

                Text(
                  _formatDuration(workDuration),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // TERLAMBAT
          // =========================
          if (isLate) ...[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 19,
                    color: Color(0xFFD97706),
                  ),

                  const SizedBox(width: 9),

                  const Expanded(
                    child: Text(
                      'Terlambat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),

                  Text(
                    '${lateDuration ?? 0} menit',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // =========================
          // BELUM CLOCK OUT
          // =========================
          if (clockIn != null && clockOut == null) ...[
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 19,
                    color: Color(0xFF2563EB),
                  ),

                  SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      'Belum Clock Out',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),

                  Text(
                    'Masih aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceTimeBox({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DASHBOARD BARGE CREW
  // ==========================================
  Widget _buildBargeCrewDashboard() {
    final user = _dashboardData?['user'];
    final today = _dashboardData?['today'];
    final stats = _dashboardData?['statistics'] ?? {};
    final history = _dashboardData?['history'] as List? ?? [];

    final bool hasClockedIn = today != null && today['clock_in'] != null;
    final bool hasClockedOut = today != null && today['clock_out'] != null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          Text(
            'Halo, ${user?['name'] ?? 'Crew'}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Text(
            'Barge Crew Status',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),

          // Status Card Hari Ini
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Status Absensi Hari Ini',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  hasClockedOut
                      ? 'SUDAH CLOCK OUT'
                      : (hasClockedIn ? 'SUDAH CLOCK IN' : 'BELUM ABSEN'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Jam Masuk',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          today?['clock_in'] ?? '--:--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 30, width: 1, color: Colors.white30),
                    Column(
                      children: [
                        const Text(
                          'Jam Keluar',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          today?['clock_out'] ?? '--:--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Monthly Statistics Summary
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Hadir Bulan Ini',
                  '${stats['present_this_month'] ?? 0} Hari',
                  Icons.calendar_today,
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Terlambat',
                  '${stats['late_this_month'] ?? 0} Kali',
                  Icons.timer,
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Absensi Saya'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendancePage()),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Riwayat 7 Hari Terakhir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          // Attendance History
          _buildAttendanceHistory(history),
        ],
      ),
    );
  }

  // Reusable Component Stat Card
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
