// lib/pages/join_class_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repos/class_repository.dart';
import '../repos/auth_repository.dart';        // để hydrate nhẹ sau khi join (tuỳ chọn)
import '../services/session.dart';

class JoinClassPage extends ConsumerStatefulWidget {
  const JoinClassPage({super.key});

  @override
  ConsumerState<JoinClassPage> createState() => _JoinClassPageState();
}

class _JoinClassPageState extends ConsumerState<JoinClassPage> {
  final _codeCtl = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    final code = _codeCtl.text.trim();

    if (code.isEmpty) {
      setState(() => _err = 'Vui lòng nhập mã lớp');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final repo = ref.read(classRepositoryProvider);
      final res = await repo.joinByCode(code);

      // Chấp nhận nhiều kiểu payload từ BE:
      // 1) { class: { id: 1, ... }, role: "member" }
      // 2) { class_id: 1, role: "member" }
      final dynamic rawId = (res['class']?['id'] ?? res['class_id']);
      final int? classId = switch (rawId) {
        int v => v,
        String v => int.tryParse(v),
        _ => null,
      };

      final String role = (res['role']?.toString() ?? 'member');
      if (classId == null) {
        throw Exception('Thiếu hoặc không đọc được classId trong phản hồi');
      }

      // Cập nhật session
      ref.read(sessionProvider.notifier).setClassInfo(
        classId: classId,
        role: role,
      );

      // (Tuỳ chọn) gọi hydrate ngắn để kéo thêm thông tin user/lớp nếu cần
      try {
        await ref
            .read(authRepositoryProvider)
            .hydrateAfterStartup()
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // ignore nếu BE chưa hỗ trợ
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tham gia lớp thành công')),
      );

      // Trở về Home và xoá history
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message']?.toString() ??
          e.response!.data.toString())
          : (e.response?.data?.toString() ?? e.message);
      setState(() => _err = msg);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tham gia lớp bằng mã')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.red)),
              ),
            TextField(
              controller: _codeCtl,
              decoration: const InputDecoration(
                labelText: 'Mã lớp',
                hintText: 'Nhập mã lớp được cung cấp',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _join(),
              enabled: !_loading,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _join,
                child: _loading
                    ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tham gia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
