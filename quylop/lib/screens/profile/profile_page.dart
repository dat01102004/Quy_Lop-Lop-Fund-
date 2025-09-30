import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repos/profile_repository.dart';
import '../../services/session.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? meRaw;
  Map<String, dynamic> user = const {};
  String? err;
  bool loading = true;

  /// Hỗ trợ cả 2 dạng: { user:{...}, ... } hoặc { id,name,email,... }
  Map<String, dynamic> _normalizeUser(Map<String, dynamic> raw) {
    final hasUser = raw['user'] is Map;
    final Map<String, dynamic> u =
    hasUser ? Map<String, dynamic>.from(raw['user'] as Map) : {};
    // Nếu không có 'user', dùng raw phẳng
    if (!hasUser) return Map<String, dynamic>.from(raw);
    // Nếu có 'user', merge thêm avatar_url/role/... ở ngoài (nếu có)
    final Map<String, dynamic> flat = Map<String, dynamic>.from(raw);
    flat.remove('user');
    return {
      ...u,
      ...flat, // ưu tiên giá trị ngoài nếu trùng key
    };
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final data = await ref.read(profileRepoProvider).getMe();
      setState(() {
        meRaw = data;
        user = _normalizeUser(data);
        loading = false;
      });
    } catch (e) {
      setState(() { err = '$e'; loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final roleLabel = switch (user['role'] ?? s.role) {
      'owner' => 'Owner',
      'treasurer' => 'Thủ quỹ',
      _ => 'Member',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin tài khoản')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err != null
          ? Center(child: Text(err!, style: const TextStyle(color: Colors.red)))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? Text(((user['name'] ?? s.name ?? 'U') as String)
                      .characters.first.toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (user['name'] ?? s.name ?? '').toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (user['email'] ?? s.email ?? '').toString(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(roleLabel, style: Theme.of(context).textTheme.labelMedium),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final initial = Map<String, dynamic>.from(user);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(initial: initial),
                        ),
                      );
                      _load(); // refresh lại
                    },
                    child: const Text('Chỉnh sửa thông tin'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                      );
                    },
                    child: const Text('Đổi mật khẩu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
