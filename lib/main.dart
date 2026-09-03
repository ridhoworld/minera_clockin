import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:minera_clockin/pages/user_management_page.dart';
import 'pages/attendance_page.dart';
import 'pages/attendance_management_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minera Clockin',
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/attendance': (context) => const AttendancePage(),

        '/attendance-management': (context) => const AttendanceManagementPage(),
        '/users': (context) => const UserManagementPage(),
      },
    );
  }
}
