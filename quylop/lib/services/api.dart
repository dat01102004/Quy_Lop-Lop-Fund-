// lib/services/api.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../env.dart';
import 'session.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBase,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Accept': 'application/json'},
  ));

  final s = ref.watch(sessionProvider);
  if (s.token != null) {
    dio.options.headers['Authorization'] = 'Bearer ${s.token}';
  }

  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) {
      if (e.response?.statusCode == 401) {
        ref.read(sessionProvider.notifier).logout();
      }
      handler.next(e);
    },
  ));
  return dio;
});
