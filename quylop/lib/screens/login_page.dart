import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../repos/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController(text: 'owner@example.com');
  final _password = TextEditingController(text: '123456');
  bool _loading = false;
  String? _error;

  Future<void> _doLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).login(
        _email.text.trim(), _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message']?.toString() ?? 'Đăng nhập thất bại');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Đăng nhập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Mật khẩu'), obscureText: true),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _doLogin,
                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Đăng nhập'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pushNamed('/register'),
                child: const Text('Chưa có tài khoản? Đăng ký'),
              ),

            ]),
          ),
        ),
      ),
    );
  }
}
