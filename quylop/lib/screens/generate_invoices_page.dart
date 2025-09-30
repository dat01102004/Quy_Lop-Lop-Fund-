import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session.dart';
import '../repos/fee_cycle_repository.dart';

class GenerateInvoicesPage extends ConsumerStatefulWidget {
  const GenerateInvoicesPage({super.key});
  @override
  ConsumerState<GenerateInvoicesPage> createState() => _GenerateInvoicesPageState();
}

class _GenerateInvoicesPageState extends ConsumerState<GenerateInvoicesPage> {
  // Data
  List<Map<String, dynamic>> _cycles = [];
  int? _selectedId; // id của kỳ nếu tên gõ trùng
  bool _loading = true;
  String? _err;
  Map<String, dynamic>? _lastResult;

  // Inputs
  final _cycleNameCtl = TextEditingController();
  final _amountCtl = TextEditingController(); // để trống => dùng default của kỳ
  DateTime? _dueDate; // chỉ dùng khi tạo kỳ mới

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  Future<void> _loadCycles() async {
    final classId = ref.read(sessionProvider).classId;
    if (classId == null) {
      setState(() {
        _err = 'Chưa có lớp hiện tại';
        _loading = false;
      });
      return;
    }
    try {
      final list = await ref.read(feeCycleRepositoryProvider).listCycles(classId);
      setState(() {
        _cycles = list;
        if (_cycles.isNotEmpty) {
          // gợi ý mặc định tên đầu tiên
          _cycleNameCtl.text = (_cycles.first['name'] ?? '').toString();
          _selectedId = _cycles.first['id'] as int?;
          _amountCtl.text = (_cycles.first['amount_per_member'] ?? '').toString();
        }
      });
    } on DioException catch (e) {
      setState(() => _err = e.response?.data?.toString() ?? e.message);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _syncSelectedIdByName(String name) {
    final hit = _cycles.firstWhere(
          (c) => (c['name'] ?? '').toString() == name,
      orElse: () => {},
    );
    if (hit.isNotEmpty) {
      _selectedId = hit['id'] as int?;
      _amountCtl.text = (hit['amount_per_member'] ?? '').toString();
    } else {
      _selectedId = null; // tên mới -> sẽ tạo kỳ mới
    }
    setState(() {});
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _generate() async {
    final classId = ref.read(sessionProvider).classId!;
    final name = _cycleNameCtl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên kỳ thu')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _lastResult = null;
      _err = null;
    });

    try {
      // Nếu không trùng kỳ nào -> tạo kỳ mới (cần hạn nộp)
      int cycleId;
      if (_selectedId != null) {
        cycleId = _selectedId!;
      } else {
        if (_dueDate == null) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chọn hạn nộp để tạo kỳ thu mới')),
          );
          return;
        }

        final amountPerMember =
            num.tryParse(_amountCtl.text.trim().isEmpty ? '0' : _amountCtl.text.trim()) ?? 0;

        final created = await ref.read(feeCycleRepositoryProvider).createCycle(
          classId: classId,
          name: name,
          amountPerMember: amountPerMember,
          dueDateIso: _dueDate!.toIso8601String().substring(0, 10), // yyyy-MM-dd
        );

        // lấy id từ response (tuỳ BE)
        cycleId = (created['id'] ??
            (created['fee_cycle']?['id'])) as int;

        // thêm vào list local để lần sau gợi ý
        _cycles.insert(0, {
          'id': cycleId,
          'name': name,
          'amount_per_member': amountPerMember,
        });
        _selectedId = cycleId;
      }

      // Phát hóa đơn (cho phép override amountPerMember nếu muốn)
      final amountOverride = int.tryParse(_amountCtl.text.trim());
      final res = await ref.read(feeCycleRepositoryProvider).generateInvoices(
        classId: classId,
        cycleId: cycleId,
        amountPerMember: amountOverride,
      );
      setState(() => _lastResult = res);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã phát: ${res['created']} • bỏ qua: ${res['skipped']}')),
      );
      // Navigator.pop(context, true); // nếu muốn quay lại ngay thì mở dòng này
    } on DioException catch (e) {
      setState(() => _err = e.response?.data?['message']?.toString() ?? e.message);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _cycles.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Phát hóa đơn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),

          // ===== Nhập tên kỳ thu (Autocomplete từ kỳ có sẵn) =====
          Text('Tên kỳ thu', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue text) {
              final q = text.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<String>.empty();
              return _cycles
                  .map((c) => (c['name'] ?? '').toString())
                  .where((n) => n.toLowerCase().contains(q));
            },
            onSelected: (val) {
              _cycleNameCtl.text = val;
              _syncSelectedIdByName(val);
            },
            fieldViewBuilder: (ctx, textCtl, focus, onSubmit) {
              // đồng bộ giá trị với controller chính
              textCtl.text = _cycleNameCtl.text;
              textCtl.selection = TextSelection.fromPosition(
                TextPosition(offset: textCtl.text.length),
              );
              return TextField(
                controller: textCtl,
                focusNode: focus,
                decoration: const InputDecoration(
                  hintText: 'Nhập tên kỳ thu ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  _cycleNameCtl.text = v;
                  _syncSelectedIdByName(v);
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // ===== Số tiền / thành viên =====
          TextField(
            controller: _amountCtl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số tiền / thành viên (bỏ trống = dùng mặc định của kỳ)',
              border: OutlineInputBorder(),
            ),
          ),

          // ===== Chỉ hiện chọn hạn nộp khi tên kỳ là mới (không trùng) =====
          if (_selectedId == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event),
              label: Text(
                _dueDate == null
                    ? 'Chọn hạn nộp cho kỳ mới'
                    : 'Hạn nộp: ${_dueDate!.toIso8601String().substring(0, 10)}',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tên kỳ chưa trùng với kỳ nào → tạo kỳ mới (cần hạn nộp).',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],

          const SizedBox(height: 16),

          // ===== Submit =====
          ElevatedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.send),
            label: const Text('Phát hóa đơn'),
          ),

          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Text(
              'Kết quả: tạo mới ${_lastResult!['created']}, '
                  'bỏ qua ${_lastResult!['skipped']} / tổng ${_lastResult!['total_members']}',
            ),
          ],
        ],
      ),
    );
  }
}
