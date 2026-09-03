import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/user_model.dart';

class ApiService {
  // ============================================================
  // SINGLETON
  // ============================================================

  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  late final Dio _dio;

  String? token;
  UserModel? user;

  ApiService._internal() {
    final baseUrl = dotenv.env['API_URL'];

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_URL belum dikonfigurasi di .env');
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ============================================================
  // HELPER ERROR MESSAGE
  // ============================================================

  String _getErrorMessage(
    DioException e, {
    String defaultMessage = 'Terjadi kesalahan pada server.',
  }) {
    final data = e.response?.data;

    if (data is Map) {
      final message = data['message'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi ke server timeout.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server.';
    }

    return defaultMessage;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {'username': username, 'password': password},
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response login tidak valid.');
      }

      final data = responseData['data'];

      if (data is! Map) {
        throw Exception('Data login tidak ditemukan.');
      }

      final tokenResponse = data['token'];
      final userResponse = data['user'];

      if (tokenResponse == null || userResponse is! Map) {
        throw Exception('Token atau data user tidak ditemukan.');
      }

      token = tokenResponse.toString();

      user = UserModel.fromJson(Map<String, dynamic>.from(userResponse));

      return user!;
    } on DioException catch (e) {
      debugPrint('LOGIN ERROR: ${e.response?.data}');

      if (e.response?.statusCode == 422 || e.response?.statusCode == 401) {
        throw Exception('Username atau password salah.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Terjadi kesalahan pada server.'),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    if (token == null) {
      return;
    }

    try {
      await _dio.post(
        '/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } finally {
      token = null;
      user = null;
    }
  }

  // ============================================================
  // ME
  // ============================================================

  Future<UserModel> me() async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.get(
        '/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response user tidak valid.');
      }

      final userResponse = responseData['data'];

      if (userResponse is! Map) {
        throw Exception('Data user tidak ditemukan.');
      }

      user = UserModel.fromJson(Map<String, dynamic>.from(userResponse));

      return user!;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal mengambil data user.'),
      );
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getDashboard() async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.get(
        '/dashboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response dashboard tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ??
              'Gagal mengambil data dashboard.',
        );
      }

      return Map<String, dynamic>.from(responseData);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal mengambil data dashboard.'),
      );
    }
  }

  // ============================================================
  // GET USERS
  // ============================================================

  Future<List<Map<String, dynamic>>> getUsers({
    String? search,
    String? role,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.get(
        '/users',
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          if (role != null && role.isNotEmpty) 'role': role,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response user tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Gagal mengambil data user.',
        );
      }

      final data = responseData['data'];

      if (data == null) {
        return [];
      }

      if (data is! List) {
        throw Exception('Format data user tidak valid.');
      }

      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      if (e.response?.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses admin.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal mengambil data user.'),
      );
    }
  }

  // ============================================================
  // CREATE USER
  // ============================================================

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      debugPrint('====================================');
      debugPrint('CREATE USER');
      debugPrint('Name     : $name');
      debugPrint('Username : $username');
      debugPrint('Role     : $role');
      debugPrint('====================================');

      final response = await _dio.post(
        '/users',
        data: {
          'name': name,
          'username': username,
          'password': password,
          'role': role,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint('CREATE USER STATUS: ${response.statusCode}');
      debugPrint('CREATE USER RESPONSE: ${response.data}');

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response server tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Gagal menambahkan user.',
        );
      }

      final data = responseData['data'];

      if (data == null) {
        return {};
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {};
    } on DioException catch (e) {
      debugPrint('====================================');
      debugPrint('CREATE USER DIO ERROR');
      debugPrint('TYPE   : ${e.type}');
      debugPrint('STATUS : ${e.response?.statusCode}');
      debugPrint('DATA   : ${e.response?.data}');
      debugPrint('ERROR  : ${e.message}');
      debugPrint('====================================');

      if (e.response?.statusCode == 422) {
        final responseData = e.response?.data;

        if (responseData is Map) {
          final errors = responseData['errors'];

          if (errors is Map) {
            final messages = <String>[];

            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                messages.add(value.first.toString());
              }
            });

            if (messages.isNotEmpty) {
              throw Exception(messages.join('\n'));
            }

            final message = responseData['message'];

            if (message != null) {
              throw Exception(message.toString());
            }
          }
        }

        throw Exception('Data user tidak valid.');
      }

      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      if (e.response?.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses admin.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal menambahkan user.'),
      );
    } catch (e, stackTrace) {
      debugPrint('====================================');
      debugPrint('CREATE USER GENERAL ERROR');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint('====================================');

      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // UPDATE USER
  // ============================================================

  Future<Map<String, dynamic>> updateUser({
    required int id,
    required String name,
    required String username,
    String? password,
    required String role,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final data = <String, dynamic>{
        'name': name,
        'username': username,
        'role': role,
      };

      if (password != null && password.isNotEmpty) {
        data['password'] = password;
      }

      final response = await _dio.put(
        '/users/$id',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response server tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Gagal memperbarui user.',
        );
      }

      final result = responseData['data'];

      if (result == null) {
        return {};
      }

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final responseData = e.response?.data;

        if (responseData is Map) {
          final errors = responseData['errors'];

          if (errors is Map) {
            final messages = <String>[];

            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                messages.add(value.first.toString());
              }
            });

            if (messages.isNotEmpty) {
              throw Exception(messages.join('\n'));
            }
          }
        }

        throw Exception('Data user tidak valid.');
      }

      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      if (e.response?.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses admin.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal memperbarui user.'),
      );
    }
  }

  // ============================================================
  // DELETE USER
  // ============================================================

  Future<void> deleteUser(int id) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.delete(
        '/users/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response server tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Gagal menghapus user.',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw Exception(
          _getErrorMessage(e, defaultMessage: 'User tidak dapat dihapus.'),
        );
      }

      if (e.response?.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses admin.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal menghapus user.'),
      );
    }
  }

  // ============================================================
  // GET ATTENDANCES
  // ============================================================

  Future<List<Map<String, dynamic>>> getAttendances() async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.get(
        '/attendances',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response attendance tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ??
              'Gagal mengambil data attendance.',
        );
      }

      final data = responseData['data'];

      if (data == null) {
        return [];
      }

      if (data is! List) {
        throw Exception('Format data attendance tidak valid.');
      }

      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      if (e.response?.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal mengambil data attendance.'),
      );
    }
  }

  // ============================================================
  // CLOCK IN
  // ============================================================

  Future<Map<String, dynamic>> clockIn({
    required File photo,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split('/').last,
        ),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await _dio.post(
        '/attendance/clock-in',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response clock in tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Clock in gagal.',
        );
      }

      final data = responseData['data'];

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw Exception(
          _getErrorMessage(
            e,
            defaultMessage: 'Anda tidak dapat melakukan clock in.',
          ),
        );
      }

      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal melakukan clock in.'),
      );
    }
  }

  // ============================================================
  // CLOCK OUT
  // ============================================================

  Future<Map<String, dynamic>> clockOut({
    required File photo,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: photo.path.split('/').last,
        ),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      final response = await _dio.post(
        '/attendance/clock-out',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response clock out tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Clock out gagal.',
        );
      }

      final data = responseData['data'];

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {};
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw Exception(
          _getErrorMessage(
            e,
            defaultMessage: 'Anda tidak dapat melakukan clock out.',
          ),
        );
      }

      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal melakukan clock out.'),
      );
    }
  }

  // ============================================================
  // UPDATE ATTENDANCE
  // ============================================================

  Future<Map<String, dynamic>> updateAttendance({
    required int id,
    required String date,
    required String status,
    String? clockIn,
    String? clockOut,
    bool? isLate,
    int? lateDuration,
    int? workDuration,
    String? notes,
  }) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final data = <String, dynamic>{'date': date, 'status': status};

      if (clockIn != null && clockIn.isNotEmpty) {
        data['clock_in'] = clockIn;
      }

      if (clockOut != null && clockOut.isNotEmpty) {
        data['clock_out'] = clockOut;
      }

      if (isLate != null) {
        data['is_late'] = isLate;
      }

      if (lateDuration != null) {
        data['late_duration'] = lateDuration;
      }

      if (workDuration != null) {
        data['work_duration'] = workDuration;
      }

      if (notes != null) {
        data['notes'] = notes;
      }

      final response = await _dio.put(
        '/attendances/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response server tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ??
              'Gagal memperbarui attendance.',
        );
      }

      final result = responseData['data'];

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return {};
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal memperbarui attendance.'),
      );
    }
  }

  // ============================================================
  // DELETE ATTENDANCE
  // ============================================================

  Future<void> deleteAttendance(int id) async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.delete(
        '/attendances/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response server tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ?? 'Gagal menghapus attendance.',
        );
      }
    } on DioException catch (e) {
      throw Exception(
        _getErrorMessage(e, defaultMessage: 'Gagal menghapus attendance.'),
      );
    }
  }

  // ============================================================
  // TODAY ATTENDANCE
  // ============================================================

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    if (token == null) {
      throw Exception('Belum login.');
    }

    try {
      final response = await _dio.get(
        '/attendance/today',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Response attendance hari ini tidak valid.');
      }

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message']?.toString() ??
              'Gagal mengambil data absensi hari ini.',
        );
      }

      final data = responseData['data'];

      if (data == null) {
        return null;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        token = null;
        user = null;

        throw Exception('Sesi login sudah berakhir.');
      }

      throw Exception(
        _getErrorMessage(
          e,
          defaultMessage: 'Gagal mengambil data absensi hari ini.',
        ),
      );
    }
  }
}
