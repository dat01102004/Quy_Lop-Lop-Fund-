import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api.dart';       // dioProvider
import '../services/session.dart';   // sessionProvider để lấy token

final feeCycleRepositoryProvider = Provider<FeeCycleRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeeCycleRepository(ref, dio);
});

class FeeCycleRepository {
  final Ref _ref;
  final Dio _dio;
  FeeCycleRepository(this._ref, this._dio);

  // Đính kèm Bearer token cho mọi request
  Options _auth() {
    final token = _ref.read(sessionProvider).token;
    return Options(headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  /// Ép kiểu int an toàn
  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString();
    final onlyDigits = RegExp(r'-?\d+');
    final m = onlyDigits.firstMatch(s);
    if (m == null) return 0;
    return int.tryParse(m.group(0)!) ?? 0;
  }

  /// Danh sách kỳ thu
  Future<List<Map<String, dynamic>>> listCycles(int classId) async {
    final res = await _dio.get('/classes/$classId/fee-cycles', options: _auth());

    if (res.data is List) {
      return List<Map<String, dynamic>>.from(
        (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }

    if (res.data is Map) {
      final data = Map<String, dynamic>.from(res.data as Map);
      final raw = (data['fee_cycles'] ?? data['items'] ?? data['data'] ?? const []) as List;
      return List<Map<String, dynamic>>.from(
        raw.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }

    return const [];
  }

  /// Chi tiết 1 kỳ thu (nếu cần)
  Future<Map<String, dynamic>> getCycle(int classId, int cycleId) async {
    final res = await _dio.get(
      '/classes/$classId/fee-cycles/$cycleId',
      options: _auth(),
    );
    if (res.data is Map) {
      final m = Map<String, dynamic>.from(res.data as Map);
      final x = m['fee_cycle'] ?? m['data'] ?? m;
      return Map<String, dynamic>.from(x as Map);
    }
    return {};
  }

  /// Tạo kỳ thu
  Future<Map<String, dynamic>> createCycle({
    required int classId,
    required String name,
    String? term,
    required num amountPerMember,
    required String dueDateIso, // yyyy-MM-dd
  }) async {
    final res = await _dio.post(
      '/classes/$classId/fee-cycles',
      options: _auth(),
      data: {
        'name': name,
        if (term != null && term.isNotEmpty) 'term': term,
        'amount_per_member': amountPerMember,
        'due_date': dueDateIso,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Phát hoá đơn theo kỳ
  Future<Map<String, dynamic>> generateInvoices({
    required int classId,
    required int cycleId,
    int? amountPerMember,
  }) async {
    final res = await _dio.post(
      '/classes/$classId/fee-cycles/$cycleId/generate-invoices',
      options: _auth(),
      data: {
        if (amountPerMember != null) 'amount_per_member': amountPerMember,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Báo cáo kỳ thu (đồng bộ với ReportController@cycleSummary)
  Future<Map<String, dynamic>> report(int classId, int cycleId) async {
    final res = await _dio.get(
      '/classes/$classId/fee-cycles/$cycleId/report',
      options: _auth(),
    );
    final raw = Map<String, dynamic>.from(res.data as Map);

    // Chuẩn hoá kiểu số cho FE dùng an tâm
    return {
      ...raw,
      'active_members': _asInt(raw['active_members']),
      'amount_per_member': _asInt(raw['amount_per_member']),
      'expected_total': _asInt(raw['expected_total']),

      'unpaid_total': _asInt(raw['unpaid_total']),
      'submitted_total': _asInt(raw['submitted_total']),
      'verified_total': _asInt(raw['verified_total']),
      'paid_total': _asInt(raw['paid_total']),

      'total_income': _asInt(raw['total_income']),
      'total_expense': _asInt(raw['total_expense']),
      'balance': _asInt(raw['balance']),
    };
  }

  /// Số dư hiện tại của lớp (ReportController@classBalance)
  Future<Map<String, int>> classBalance(int classId) async {
    final res = await _dio.get(
      '/classes/$classId/balance',
      options: _auth(),
    );
    final m = Map<String, dynamic>.from(res.data as Map);
    return {
      'income': _asInt(m['income']),
      'expense': _asInt(m['expense']),
      'balance': _asInt(m['balance']),
    };
  }
}
