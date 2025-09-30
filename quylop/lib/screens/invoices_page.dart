import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session.dart';
import '../repos/invoice_repository.dart';
import 'invoice_detail_page.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});
  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  List<Map<String, dynamic>> items = [];
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(sessionProvider);
    final classId = s.classId;
    if (classId == null) {
      setState(() {
        err = 'Bạn chưa tham gia lớp nào';
        loading = false;
      });
      return;
    }
    try {
      final list = await ref.read(invoiceRepositoryProvider).myInvoices(classId);

      // Đảm bảo luôn có 'title' cho mỗi item (fallback fee_cycle.name -> Invoice #id)
      final mapped = list.map<Map<String, dynamic>>((it) {
        final feeCycle = it['fee_cycle'] as Map<String, dynamic>?;
        final idStr = (it['id'] ?? '').toString();
        final title = (it['title'] as String?) ??
            (feeCycle?['name'] as String?) ??
            'Invoice #$idStr';
        return {
          ...it,
          'title': title,
        };
      }).toList();

      setState(() {
        items = mapped;
        err = null;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.message;
      setState(() {
        err = status != null ? "Lỗi $status: $msg" : msg ?? "Có lỗi xảy ra";
      });
      debugPrint("Chi tiết DioException: ${e.response?.data}");
    } catch (e) {
      setState(() {
        err = "Lỗi: ${e.runtimeType}";
      });
      debugPrint("Chi tiết exception: $e");
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green;
      case 'verified':
        return Colors.blue;
      case 'submitted':
        return Colors.orange;
      default:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn của tôi')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: err != null
            ? ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                err!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        )
            : ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = items[i];
            final id = (it['id'] as num).toInt();
            final amount = it['amount'];
            final status = (it['status'] ?? '') as String;
            final title = (it['title'] as String?) ??
                (it['fee_cycle']?['name'] as String?) ??
                'Invoice #$id';

            return ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(
                title, // 👈 Hiển thị tên hoá đơn/kỳ thu
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Số tiền: $amount'),
              trailing: Chip(
                label: Text(status),
                backgroundColor: _statusColor(status).withOpacity(.15),
                labelStyle: TextStyle(color: _statusColor(status)),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(invoiceId: id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
