import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api.dart';
import '../services/session.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentRepository(ref, dio);
});

class PaymentRepository {
  final Ref _ref;
  final Dio _dio;
  PaymentRepository(this._ref, this._dio);

  Options _auth() {
    final token = _ref.read(sessionProvider).token;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// ================== SUBMITTED LIST (group theo kỳ) ==================
  Future<List<Map<String, dynamic>>> listPaymentsGrouped(
      int classId, {
        String status = 'submitted',
      }) async {
    final res = await _dio.get(
      '/classes/$classId/payments',
      queryParameters: {'status': status, 'group': 'cycle'},
      options: _auth(),
    );
    final data =
    (res.data is Map) ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
    final list = (data['cycles'] is List) ? data['cycles'] as List : const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// ================== APPROVED LIST (phẳng) ==================
  /// GET /classes/{classId}/payments/approved
  /// Trả về:
  /// - ưu tiên mảng 'payments' từ BE
  /// - nếu BE trả group theo kỳ {cycles:[{..., payments:[...]}, ...]}, sẽ flatten
  Future<List<Map<String, dynamic>>> listApproved({
    required int classId,
    int? feeCycleId,
  }) async {
    final res = await _dio.get(
      '/classes/$classId/payments/approved',
      queryParameters: feeCycleId != null ? {'fee_cycle_id': feeCycleId} : null,
      options: _auth(),
    );

    final data =
    (res.data is Map) ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};

    // Case 1: BE trả trực tiếp { payments: [...] }
    if (data['payments'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['payments'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

    // Case 2: BE trả group theo kỳ { cycles: [{ payments:[...] }, ...] }
    if (data['cycles'] is List) {
      final cycles = data['cycles'] as List;
      final flattened = <Map<String, dynamic>>[];
      for (final c in cycles) {
        final m = Map<String, dynamic>.from(c as Map);
        final ps = (m['payments'] is List) ? m['payments'] as List : const [];
        flattened.addAll(ps.map((e) => Map<String, dynamic>.from(e)));
      }
      return flattened;
    }

    // Case 3: fallback — không đúng format
    return const [];
  }

  /// ================== APPROVED LIST (giữ group theo kỳ) ==================
  /// Nếu bạn muốn hiển thị theo nhóm kỳ thu
  Future<List<Map<String, dynamic>>> listApprovedGrouped({
    required int classId,
  }) async {
    final res = await _dio.get(
      '/classes/$classId/payments/approved',
      // BE hiện không nhận tham số group, nếu cần có thể thêm ở server
      options: _auth(),
    );
    final data =
    (res.data is Map) ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
    final list = (data['cycles'] is List) ? data['cycles'] as List : const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// ================== DANH SÁCH PAYMENTS THEO STATUS ==================
  Future<List<Map<String, dynamic>>> listPayments({
    required int classId,
    String status = 'submitted',
  }) async {
    final res = await _dio.get(
      '/classes/$classId/payments',
      queryParameters: {'status': status},
      options: _auth(),
    );

    final body = res.data;
    if (body is Map && body['payments'] is List) {
      return List<Map<String, dynamic>>.from(
        (body['payments'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    if (body is List) {
      return List<Map<String, dynamic>>.from(
        body.map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return const [];
  }

  /// ================== CHI TIẾT PAYMENT ==================
  Future<Map<String, dynamic>> paymentDetail({
    required int classId,
    required int paymentId,
  }) async {
    final res = await _dio.get(
      '/classes/$classId/payments/$paymentId',
      options: _auth(),
    );
    final body = res.data;
    if (body is Map && body['payment'] is Map) {
      return Map<String, dynamic>.from(body['payment']);
    }
    return Map<String, dynamic>.from(body as Map);
  }

  /// ================== DUYỆT / TỪ CHỐI ==================
  Future<void> verifyPayment({
    required int classId,
    required int paymentId,
    required bool approve,
    String? note,
  }) async {
    await _dio.post(
      '/classes/$classId/payments/$paymentId/verify',
      data: {'action': approve ? 'approve' : 'reject', if (note != null) 'note': note},
      options: _auth(),
    );
  }
}
