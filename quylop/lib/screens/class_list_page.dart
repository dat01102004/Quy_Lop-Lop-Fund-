// lib/screens/class_list_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repos/class_repository.dart';
import '../services/session.dart';

class ClassListPage extends ConsumerStatefulWidget {
  const ClassListPage({super.key});

  @override
  ConsumerState<ClassListPage> createState() => _ClassListPageState();
}

class _ClassListPageState extends ConsumerState<ClassListPage> {
  List<Map<String, dynamic>> _classes = [];
  String? _err;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final list = await ref.read(classRepositoryProvider).myClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
      });
    } on DioException catch (e) {
      setState(() {
        _err = e.response?.data?.toString() ?? e.message;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectClass(Map<String, dynamic> c) async {
    final classIdAny = c['id'] ?? c['class_id'];
    if (classIdAny == null) return;

    final String role = (c['role'] ?? 'member').toString();

    final notifier = ref.read(sessionProvider.notifier);

    // setClass với int
    if (classIdAny is int) {
      await notifier.setClass(classIdAny);
    } else {
      final idInt = int.tryParse(classIdAny.toString());
      if (idInt != null) await notifier.setClass(idInt);
    }

    // setRole luôn là String non-null
    await notifier.setRole(role);

    if (!mounted) return;
    Navigator.of(context).pop(c); // quay về Home
  }

  Future<void> _createClassDialog() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo lớp'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Tên lớp',
            hintText: 'VD: CNTT K22',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Tạo')),
        ],
      ),
    );

    if (ok != true) return;
    final name = ctl.text.trim();
    if (name.isEmpty) return;

    try {
      final res = await ref.read(classRepositoryProvider).createClass(name);
      // Tùy BE: nếu trả { class: {...} } thì dùng dòng dưới, nếu trả {...} thì dùng res trực tiếp
      final Map<String, dynamic> cls =
      (res['class'] is Map) ? Map<String, dynamic>.from(res['class']) : Map<String, dynamic>.from(res);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tạo lớp: ${cls['name']} — mã: ${cls['code'] ?? '-'}')),
      );
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.response?.data?.toString() ?? e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _goJoinByCode() {
    Navigator.of(context).pushNamed('/join').then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final hasToken = (session.token != null && session.token!.isNotEmpty);
    final bool canCreate = hasToken; // đã đăng nhập thì được tạoate = true;
    final bool canJoin = true; // ai cũng join được

    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách lớp đã tham gia')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.red)),
              ),
            if (_classes.isEmpty)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có lớp nào'),
                ),
              ),
            ..._classes.map((c) {
              final name = (c['name'] ?? '').toString();
              final code = (c['code'] ?? '').toString();
              final roleStr = (c['role'] ?? 'member').toString();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.class_),
                  title: Text(name.isEmpty ? 'Lớp #${c['id']}' : name),
                  subtitle: Text(code.isNotEmpty ? 'Mã: $code' : 'ID: ${c['id']}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      roleStr == 'owner'
                          ? 'Owner'
                          : (roleStr == 'treasurer' ? 'Thủ quỹ' : 'Thành viên'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  onTap: () => _selectClass(c),
                ),
              );
            }),
          ],
        ),
      ),

      // FAB theo vai trò
      floatingActionButton: _RoleFab(
        showJoin: canJoin,
        showCreate: canCreate,
        onJoin: _goJoinByCode,
        onCreate: _createClassDialog,
      ),
    );
  }
}

class _RoleFab extends StatelessWidget {
  final bool showJoin;
  final bool showCreate;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  const _RoleFab({
    required this.showJoin,
    required this.showCreate,
    required this.onJoin,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (showJoin) {
      buttons.add(
        FloatingActionButton.extended(
          heroTag: 'fab-join',
          onPressed: onJoin,
          icon: const Icon(Icons.group_add),
          label: const Text('Tham gia lớp'),
        ),
      );
    }
    if (showCreate) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 12));
      buttons.add(
        FloatingActionButton.extended(
          heroTag: 'fab-create',
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Tạo lớp'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: buttons,
    );
  }
}
