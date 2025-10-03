import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/auth_repository.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _pass2Ctl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _dobCtl = TextEditingController(); // yyyy-MM-dd

  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _pass2Ctl.dispose();
    _phoneCtl.dispose();
    _dobCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 80, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      _dobCtl.text = "${picked.year.toString().padLeft(4, '0')}-"
          "${picked.month.toString().padLeft(2, '0')}-"
          "${picked.day.toString().padLeft(2, '0')}";
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    final pass2 = _pass2Ctl.text;
    final phone = _phoneCtl.text.trim();
    final dob = _dobCtl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      setState(() => _err = 'Vui lòng nhập đủ Họ tên, Email và mật khẩu trên 6 ký tự');
      return;
    }
    if (pass != pass2) {
      setState(() => _err = 'Xác nhận mật khẩu không khớp');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await ref.read(authRepositoryProvider).register(
        name: name,
        email: email,
        password: pass,
        passwordConfirmation: pass2,
        phone: phone.isEmpty ? null : phone,
        dobIso: dob.isEmpty ? null : dob,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công')),
      );
      // điều hướng sang Home (nếu app bạn về thẳng Home sau đăng ký)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      setState(() {
        _err = (e is Exception) ? e.toString() : 'Đăng ký thất bại';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _nameCtl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Họ tên',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtl,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu (Trên 6 ký tự)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass2Ctl,
            obscureText: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Xác nhận mật khẩu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Điện thoại (không bắt buộc)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: TextField(
                controller: _dobCtl,
                decoration: const InputDecoration(
                  labelText: 'Ngày sinh (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Tạo tài khoản'),
          ),
        ],
      ),
    );
  }
}