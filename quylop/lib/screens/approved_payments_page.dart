// lib/screens/approved_payments_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../repos/payment_repository.dart';
import '../repos/fee_cycle_repository.dart';
import '../services/session.dart';

class ApprovedPaymentsPage extends ConsumerStatefulWidget {
  final int classId;
  const ApprovedPaymentsPage({super.key, required this.classId});

  @override
  ConsumerState<ApprovedPaymentsPage> createState() => _ApprovedPaymentsPageState();
}

class _ApprovedPaymentsPageState extends ConsumerState<ApprovedPaymentsPage> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cycles = [];
  int? _feeCycleId;

  final NumberFormat _money = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      // Lấy danh sách kỳ để render dropdown, sau đó mới load dữ liệu.
      final cycles = await ref.read(feeCycleRepositoryProvider).listCycles(widget.classId);
      if (!mounted) return;
      setState(() => _cycles = cycles);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final items = await repo.listApproved(
        classId: widget.classId,
        feeCycleId: _feeCycleId,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showImage(String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: .5,
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // giữ ref.watch để khi session đổi class/role thì rebuild
    ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách đã duyệt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, style: const TextStyle(color: Colors.red)),
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Bộ lọc kỳ thu
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Chọn kỳ thu',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _feeCycleId,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Tất cả kỳ')),
                    ..._cycles.map(
                          (c) => DropdownMenuItem<int?>(
                        value: c['id'] as int,
                        child: Text(c['name']?.toString() ?? 'Kỳ'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _feeCycleId = v;
                      _loading = true;
                    });
                    _load();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Chưa có phiếu đã duyệt.')),
              )
            else
              ..._items.map((e) {
                // ✅ Lấy tên người nộp
                final who = (e['payer_name'] ??
                    e['member_name'] ??
                    e['payer_email'] ??
                    '')
                    .toString();

                // ✅ Số tiền
                final num amountNum = (e['amount'] is num)
                    ? (e['amount'] as num)
                    : (int.tryParse('${e['amount']}') ?? 0);
                final amount = _money.format(amountNum);

                // ✅ Thông tin khác
                final cycle = (e['cycle_name'] ?? '').toString();
                final approvedBy =
                (e['verified_by_name'] ?? e['approved_by_name'] ?? '').toString();
                final when = (e['approved_at'] ??
                    e['verified_at'] ??
                    e['created_at'] ??
                    '')
                    .toString();

                // ✅ Ảnh minh chứng (hỗ trợ cả 2 key)
                final url = (e['proof_path'] ?? e['proof_url'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: url.isEmpty
                        ? const Icon(Icons.receipt_long_outlined)
                        : InkWell(
                      onTap: () => _showImage(url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          url,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    title: Text('$who • $amount đ'),
                    subtitle: Text([
                      if (cycle.isNotEmpty) 'Kỳ: $cycle',
                      if (approvedBy.isNotEmpty) 'Duyệt bởi: $approvedBy',
                      if (when.isNotEmpty) 'Lúc: $when',
                    ].join('\n')),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
