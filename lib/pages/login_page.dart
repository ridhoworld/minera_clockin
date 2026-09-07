import 'package:flutter/material.dart';

import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color navy = Color(0xFF0F3D52);
  static const Color darkNavy = Color(0xFF092C3C);
  static const Color yellow = Color(0xFFFFB91F);
  static const Color background = Color(0xFFF7F9FA);
  static const Color textDark = Color(0xFF172B35);
  static const Color textMuted = Color(0xFF71808A);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: textMuted),
      suffixIcon: suffixIcon,

      filled: true,
      fillColor: background,

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),

      labelStyle: const TextStyle(color: textMuted, fontSize: 14),

      hintStyle: const TextStyle(color: Color(0xFFA1ACB2), fontSize: 14),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7EA)),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E7EA)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: navy, width: 1.5),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LOGO
          Image.asset('assets/minera.png', height: 105, fit: BoxFit.contain),

          const SizedBox(height: 20),

          const Text(
            'MINERA CLOCKIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: textDark,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Workforce Management System',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.3,
              color: textMuted,
            ),
          ),

          const SizedBox(height: 38),

          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Silakan masuk untuk melanjutkan aktivitas Anda.',
            style: TextStyle(fontSize: 13, height: 1.5, color: textMuted),
          ),

          const SizedBox(height: 27),

          const Text(
            'Username',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Username',
              hint: 'Masukkan username',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username wajib diisi';
              }

              return null;
            },
          ),

          const SizedBox(height: 19),

          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) {
                _login();
              }
            },
            decoration: _inputDecoration(
              label: 'Password',
              hint: 'Masukkan password',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: textMuted,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password wajib diisi';
              }

              return null;
            },
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: navy.withOpacity(0.65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 30),

          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFE3E8EA))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'MINERA CLOCKIN',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: Color(0xFF9AA6AC),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFE3E8EA))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _brandingPanel() {
    return Expanded(
      flex: 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg.jpg', fit: BoxFit.cover),

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC092C3C), Color(0xE6092C3C)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(55),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 55,
                  decoration: BoxDecoration(
                    color: yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'MINERA',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'CLOCKIN',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5,
                    color: yellow,
                  ),
                ),

                const SizedBox(height: 25),

                const SizedBox(
                  width: 380,
                  child: Text(
                    'Sistem manajemen kehadiran dan operasional '
                    'yang membantu mengelola aktivitas kerja '
                    'secara lebih terstruktur.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return Row(
              children: [
                _brandingPanel(),

                Expanded(
                  flex: 5,
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 55,
                          vertical: 40,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _loginForm(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Container(
            color: background,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: _loginForm(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
