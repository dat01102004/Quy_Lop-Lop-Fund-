import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session.dart';
import '../repos/payment_repository.dart';
import 'payment_review_detail_page.dart';

class PaymentReviewPage extends ConsumerStatefulWidget {
  const PaymentReviewPage({super.key});
  @override
  ConsumerState<PaymentReviewPage> createState() => _PaymentReviewPageState();
}

class _PaymentReviewPageState extends ConsumerState<PaymentReviewPage> {
  List<Map<String, dynamic>> groups = [];
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final classId = ref.read(sessionProvider).classId;
    if (classId == null) { setState(() { err = 'Chưa có lớp hiện tại'; loading = false; }); return; }
    try {
      final list = await ref.read(paymentRepositoryProvider).listPaymentsGrouped(classId);
      setState(() { groups = list; err = null; });
    } catch (e) {
      setState(() { err = e.toString(); });
    } finally { setState(() { loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && groups.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Phiếu nộp chờ duyệt')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final g = groups[i];
            final payments = (g['payments'] as List?) ?? const [];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(g['cycle_name']?.toString() ?? 'Kỳ thu'),
                subtitle: Text('${payments.length} phiếu chờ duyệt'),
                children: [
                  for (final p in payments)
                    ListTile(
                      title: Text(p['payer_name']?.toString() ?? ''),
                      subtitle: Text('Invoice #${p['invoice_id']} • Số tiền: ${p['amount']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PaymentReviewDetailPage(paymentId: (p['id'] as num).toInt()),
                          ),
                        ).then((changed) {
                          if (changed == true) _load();
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
