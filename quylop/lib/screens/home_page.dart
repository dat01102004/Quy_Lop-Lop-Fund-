import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../repos/auth_repository.dart';
import '../repos/class_repository.dart';
import '../repos/fund_account_repository.dart'; // ✅ dùng để lấy summary (balance)
import '../services/session.dart';

import 'profile/profile_page.dart';
import 'class_list_page.dart';
import 'class_members_page.dart';
import 'profile/fund_account_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, dynamic>? me;
  String? err;

  String? _className;
  num? _balance; // giữ số gốc nếu cần chỗ khác dùng
  final _money = NumberFormat.decimalPattern('vi_VN');
  String _balanceText = '—';
  bool _loadingBalance = false;
  @override
  void initState() {
    super.initState();
    _loadMe().then((_) => _loadCurrentClassInfo());
    _loadBalance();
  }
  Future<void> _loadBalance() async {
    final s = ref.read(sessionProvider);
    final classId = s.classId;
    if (classId == null) {
      if (mounted) setState(() => _balanceText = '—');
      return;
    }
    if (mounted) setState(() => _loadingBalance = true);
    try {
      final summary =
      await ref.read(fundAccountRepositoryProvider).getSummary(classId: classId);
      final balance = summary['balance'] ?? 0;
      final formatted = _money.format(balance);
      if (mounted) setState(() => _balanceText = '$formatted đ');
    } catch (e) {
      if (mounted) setState(() => _balanceText = '—');
    } finally {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }
  Future<void> _fallbackHydrateIfNeeded() async {
    final s = ref.read(sessionProvider);
    if (s.token != null && s.classId == null) {
      try {
        final classes = await ref.read(classRepositoryProvider).myClasses();
        if (classes.isNotEmpty) {
          Map<String, dynamic> picked = classes.first;
          for (final c in classes) {
            if ((c['member_status'] ?? 'active') == 'active') {
              picked = c;
              break;
            }
          }
          final classIdAny = (picked['id'] ?? picked['class_id']);
          final role = (picked['role'] ?? 'member').toString();

          if (classIdAny != null) {
            final idInt = classIdAny is int
                ? classIdAny
                : int.tryParse(classIdAny.toString());
            if (idInt != null) {
              await ref.read(sessionProvider.notifier).setClass(idInt);
              await ref.read(sessionProvider.notifier).setRole(role);
            }
          }
          if (mounted) setState(() {});
        }
      } catch (_) {/* ignore */}
    }
  }

  Future<void> _loadMe() async {
    try {
      final data = await ref.read(authRepositoryProvider).me();
      if (!mounted) return;
      setState(() {
        me = data;
        err = null;
      });
      await _fallbackHydrateIfNeeded();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        err = e.response?.data?.toString() ?? e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        err = e.toString();
      });
    }
  }

  /// Parse an toàn về int (BE có thể trả int/num/string)
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _loadCurrentClassInfo() async {
    final s = ref.read(sessionProvider);
    if (s.classId == null) {
      setState(() {
        _className = null;
        _balance = null;
      });
      return;
    }
    try {
      // ✅ Lấy tổng hợp thu–chi theo lớp
      final summary = await ref
          .read(fundAccountRepositoryProvider)
          .getSummary(classId: s.classId!);

      final balance = _toInt(summary['balance']);

      setState(() {
        _balance = balance;
      });

      // tên lớp (cache nhanh)
      if (_className == null) {
        final classes = await ref.read(classRepositoryProvider).myClasses();
        final hit =
        classes.firstWhere((c) => (c['id'] == s.classId), orElse: () => {});
        if (hit.isNotEmpty) {
          setState(() {
            _className = (hit['name'] ?? '').toString();
          });
        }
      }
    } catch (_) {
      // im lặng, hiển thị "—"
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final displayName = s.name ?? (me?['name'] as String?) ?? '';
    final isTreasurer = (s.role == 'treasurer' || s.role == 'owner');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lop Fund'),
        actions: [
          IconButton(
            tooltip: 'Sổ quỹ',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/reports/ledger'),
          ),

          IconButton(
            tooltip: 'Làm mới',
            onPressed: () async {
              await _loadMe();
              await _loadCurrentClassInfo();
              await _loadBalance();
            },
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadMe();
          await _loadCurrentClassInfo();
          await _loadBalance();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(err!, style: const TextStyle(color: Colors.red)),
              ),

            _GreetingCard(
              name: displayName,
              email: s.email ?? (me?['email'] as String?) ?? '',
              role: s.role ?? 'member',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            const SizedBox(height: 16),

            if (s.classId == null)
              _EmptyClassCard(
                onJoin: () => Navigator.of(context).pushNamed('/join'),
              )
            else
              _CurrentClassCard(
                classId: s.classId!,
                className: _className ?? 'Lớp đã tham gia',
                balance: _balance, // ✅ đã đổi sang balance từ summary
                onPickClass: () async {
                  final picked =
                  await Navigator.of(context).push<Map<String, dynamic>>(
                    MaterialPageRoute(builder: (_) => const ClassListPage()),
                  );
                  if (picked != null) {
                    setState(() {
                      _className = (picked['name'] ?? '').toString();
                    });
                    // đổi lớp xong thì nạp lại số dư lớp mới
                    await _loadCurrentClassInfo();
                  }
                },
                onOpenMembers: (isTreasurer)
                    ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClassMembersPage(
                      classId: s.classId!,
                    ),
                  ),
                )
                    : null,
              ),

            const SizedBox(height: 16),

            const _SectionTitle(title: 'Tính năng nhanh'),
            const SizedBox(height: 8),
            _ActionsGrid(
              children: [
                _ActionCard(
                  icon: Icons.receipt_long,
                  title: 'Hóa đơn của tôi',
                  subtitle: 'Theo dõi & thanh toán',
                  onTap: () => Navigator.of(context).pushNamed('/invoices'),
                ),
                if (isTreasurer)
                  _ActionCard(
                    icon: Icons.verified,
                    title: 'Duyệt phiếu nộp',
                    subtitle: 'Xử lý chứng từ',
                    onTap: () => Navigator.of(context).pushNamed('/payments/review'),
                    ),

                _ActionCard(
                  icon: Icons.fact_check,
                  title: 'Danh sách đã nộp',
                  subtitle: 'danh sách đã thanh toán',
                  onTap: () => Navigator.of(context).pushNamed('/payments/approved'),
                ),

                _ActionCard(
                  icon: Icons.payments_outlined,
                  title: 'Khoản chi',
                  subtitle: 'Ghi & xem chi',
                  onTap: () => Navigator.of(context).pushNamed('/expenses'),
                ),
                if (isTreasurer)
                  _ActionCard(
                    icon: Icons.upload_file,
                    title: 'Phát hóa đơn',
                    subtitle: 'Tạo kỳ thu nhanh',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/fee-cycles/generate'),
                  ),
                if (isTreasurer)
                  _ActionCard(
                    icon: Icons.bar_chart,
                    title: 'Báo cáo kỳ thu',
                    subtitle: 'Tổng hợp thu – chi',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/reports/fee'),
                  ),
                // if (isTreasurer)
                //   _ActionCard(
                //   icon: Icons.menu_book_outlined,     // hoặc Icons.account_balance_wallet_outlined
                //   title: 'Sổ quỹ',
                //   subtitle: 'Tổng hợp thu - chi',
                //   onTap: () => Navigator.of(context).pushNamed('/reports/ledger'),
                // ),

                if (s.classId != null && isTreasurer)
                  _ActionCard(
                    icon: Icons.group,
                    title: 'Thành viên lớp',
                    subtitle: 'Xem & đổi quyền',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClassMembersPage(classId: s.classId!),
                      ),
                    ),
                  ),
                if (isTreasurer)
                  _ActionCard(
                    icon: Icons.account_balance,
                    title: 'Tài khoản quỹ',
                    subtitle: 'Cấu hình tài khoản',
                    onTap: () async {
                      final currentClassId = s.classId;
                      if (currentClassId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('Chưa chọn lớp — không thể cấu hình TK quỹ')),
                        );
                        return;
                      }
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) =>
                            FundAccountSheet(classId: currentClassId),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== WIDGETS ==================

class _GreetingCard extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final VoidCallback? onTap;

  const _GreetingCard({
    required this.name,
    required this.email,
    required this.role,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      'owner' => 'Owner',
      'treasurer' => 'Thủ quỹ',
      _ => 'Thành viên',
    };

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xin chào $name',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                child: Text(roleLabel,
                    style: Theme.of(context).textTheme.labelMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClassCard extends StatelessWidget {
  final VoidCallback onJoin;
  const _EmptyClassCard({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn chưa tham gia lớp nào',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Nhấn “Tham gia bằng mã” để vào lớp.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.group_add),
              label: const Text('Tham gia bằng mã'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentClassCard extends StatelessWidget {
  final int classId;
  final String className;
  final num? balance;
  final VoidCallback onPickClass;
  final VoidCallback? onOpenMembers;

  const _CurrentClassCard({
    required this.classId,
    required this.className,
    required this.balance,
    required this.onPickClass,
    this.onOpenMembers,
  });

  // format tiền Việt đơn giản (dấu chấm ngăn cách ngàn)
  String _formatVn(num v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = balance == null ? '—' : '${_formatVn(balance!)} đ';

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: const Icon(Icons.class_),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(className,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Mã lớp: $classId',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onPickClass,
                  child: const Text('Danh sách lớp'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Số dư hiện tại: $balanceText',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _ActionsGrid extends StatelessWidget {
  final List<Widget> children;
  const _ActionsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: children,
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
