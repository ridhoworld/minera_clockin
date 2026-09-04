import 'package:flutter/material.dart';

import '../services/api_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];

  bool _isLoading = true;

  String _selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _apiService.getUsers(
        search: _searchController.text.trim(),
        role: _selectedRole == 'all' ? null : _selectedRole,
      );

      if (!mounted) return;

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showUserForm({Map<String, dynamic>? user}) async {
    final bool isEdit = user != null;

    final nameController = TextEditingController(
      text: user?['name']?.toString() ?? '',
    );

    final usernameController = TextEditingController(
      text: user?['username']?.toString() ?? '',
    );

    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    String selectedRole =
        user?['role']?.toString() == 'admin' ||
            user?['role']?.toString() == 'barge_crew'
        ? user!['role'].toString()
        : 'barge_crew';

    bool isSubmitting = false;

    final pageContext = context;

    bool? result;

    try {
      result = await showDialog<bool>(
        context: pageContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  isEdit ? 'Edit User' : 'Tambah User',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),

                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =========================
                        // NAMA
                        // =========================
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama wajib diisi.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // =========================
                        // USERNAME
                        // =========================
                        TextFormField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username wajib diisi.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // =========================
                        // PASSWORD
                        // =========================
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEdit
                                ? 'Password Baru (opsional)'
                                : 'Password',
                          ),
                          validator: (value) {
                            if (!isEdit &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Password wajib diisi.';
                            }

                            if (value != null &&
                                value.isNotEmpty &&
                                value.length < 6) {
                              return 'Minimal 6 karakter.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // =========================
                        // ROLE
                        // =========================
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'barge_crew',
                              child: Text('Barge Crew'),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    selectedRole = value;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),

                // =========================
                // BUTTON
                // =========================
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),

                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            // =========================
                            // VALIDASI
                            // =========================
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            // =========================
                            // DISABLE BUTTON
                            // =========================
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            try {
                              // =========================
                              // UPDATE
                              // =========================
                              if (isEdit) {
                                await _apiService.updateUser(
                                  id: int.parse(user!['id'].toString()),
                                  name: nameController.text.trim(),
                                  username: usernameController.text.trim(),
                                  password: passwordController.text.trim(),
                                  role: selectedRole,
                                );
                              }
                              // =========================
                              // CREATE
                              // =========================
                              else {
                                await _apiService.createUser(
                                  name: nameController.text.trim(),
                                  username: usernameController.text.trim(),
                                  password: passwordController.text.trim(),
                                  role: selectedRole,
                                );
                              }

                              // =================================================
                              // PENTING:
                              // Setelah API sukses, hanya tutup dialog.
                              // Jangan akses controller lagi setelah Navigator.pop.
                              // =================================================
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } catch (e) {
                              debugPrint('ERROR SIMPAN USER: $e');

                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                isSubmitting = false;
                              });

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEdit ? 'Simpan' : 'Tambah'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // =====================================================
      // showDialog completes when pop() is called, before the dialog route's
      // reverse animation has finished. Delay disposal until that animation
      // is complete so the remaining dialog frames can still use the fields.
      // =====================================================
      await Future<void>.delayed(const Duration(milliseconds: 300));
      nameController.dispose();
      usernameController.dispose();
      passwordController.dispose();
    }

    // =====================================================
    // DIALOG DIBATALKAN
    // =====================================================
    if (result != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    // =====================================================
    // NOTIFIKASI SUKSES
    // =====================================================
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(
        content: Text(
          isEdit ? 'User berhasil diperbarui.' : 'User berhasil ditambahkan.',
        ),
        backgroundColor: const Color(0xFF0F766E),
      ),
    );

    // =====================================================
    // REFRESH DATA
    // =====================================================
    await _loadUsers();
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Hapus User?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus '
            '"${user['name']}"?',
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

    if (confirmed != true) {
      return;
    }

    try {
      await _apiService.deleteUser(user['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User berhasil dihapus.'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _roleLabel(String role) {
    if (role == 'admin') {
      return 'Admin';
    }

    return 'Barge Crew';
  }

  Color _roleBackground(String role) {
    if (role == 'admin') {
      return const Color(0xFFEFF6FF);
    }

    return const Color(0xFFECFDF5);
  }

  Color _roleForeground(String role) {
    if (role == 'admin') {
      return const Color(0xFF2563EB);
    }

    return const Color(0xFF047857);
  }

  String _initials(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return '?';
    }

    final parts = cleanName.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      final text = parts.first;

      return text.substring(0, text.length > 1 ? 2 : 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
          'Manajemen User',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showUserForm();
        },
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(
          'Tambah User',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  )
                : _users.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    color: const Color(0xFF0F766E),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(_users[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: (_) {
              _loadUsers();
            },
            decoration: InputDecoration(
              hintText: 'Cari nama atau username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadUsers();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
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
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _buildRoleFilter('all', 'Semua'),
              const SizedBox(width: 8),
              _buildRoleFilter('admin', 'Admin'),
              const SizedBox(width: 8),
              _buildRoleFilter('barge_crew', 'Barge Crew'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilter(String value, String label) {
    final selected = _selectedRole == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = value;
          });

          _loadUsers();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F766E)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE6FFFB),
            child: Text(
              _initials(user['name'] ?? 'User'),
              style: const TextStyle(
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? '-',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '@${user['username'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 7),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _roleBackground(role),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _roleLabel(role),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _roleForeground(role),
                    ),
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
            onSelected: (value) {
              if (value == 'edit') {
                _showUserForm(user: user);
              }

              if (value == 'delete') {
                _deleteUser(user);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 34,
                color: Color(0xFF0F766E),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Belum ada user',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Tambahkan user baru untuk mulai mengelola akun.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
