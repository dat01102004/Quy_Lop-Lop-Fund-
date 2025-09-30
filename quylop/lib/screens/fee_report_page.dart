import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session.dart';
import '../repos/fee_cycle_repository.dart';

class FeeReportPage extends ConsumerStatefulWidget {
  const FeeReportPage({super.key});
  @override
  ConsumerState<FeeReportPage> createState() => _FeeReportPageState();
}

class _FeeReportPageState extends ConsumerState<FeeReportPage> {
  List<Map<String, dynamic>> cycles = [];
  Map<String, dynamic>? report;
  String? err;
  bool loading = true;
  int? selectedId;

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  Future<void> _loadCycles() async {
    final classId = ref.read(sessionProvider).classId;
    if (classId == null) {
      setState(() { err = 'Chưa có lớp hiện tại'; loading = false; });
      return;
    }
    try {
      final list = await ref.read(feeCycleRepositoryProvider).listCycles(classId);
      setState(() {
        cycles = list;
        if (cycles.isNotEmpty) selectedId = cycles.first['id'] as int?;
      });
      if (selectedId != null) await _loadReport();
    } on DioException catch (e) {
      setState(() { err = e.response?.data?.toString() ?? e.message; });
    } catch (e) {
      setState(() { err = e.toString(); });
    } finally { setState(() { loading = false; }); }
  }

  Future<void> _loadReport() async {
    final classId = ref.read(sessionProvider).classId!;
    if (selectedId == null) return;
    setState(() { loading = true; });
    try {
      final r = await ref.read(feeCycleRepositoryProvider).report(classId, selectedId!);
      setState(() { report = r; err = null; });
    } on DioException catch (e) {
      setState(() { err = e.response?.data?.toString() ?? e.message; });
    } catch (e) {
      setState(() { err = e.toString(); });
    } finally { setState(() { loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo kỳ thu')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
          if (cycles.isNotEmpty) InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Chọn kỳ thu',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedId,
                items: [
                  for (final c in cycles)
                    DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text('${c['name']}'),
                    )
                ],
                onChanged: (v) async {
                  setState(() { selectedId = v; });
                  await _loadReport();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (loading && report == null) const LinearProgressIndicator(),
          if (report != null) _ReportCard(report: report!),
        ]),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final totalIncome = report['total_income'] ?? report['income'] ?? 0;
    final totalExpense = report['total_expense'] ?? report['expense'] ?? 0;
    final balance = report['balance'] ?? (totalIncome - totalExpense);

    Widget row(String label, Object value, {Color? color, FontWeight? fw}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value', style: TextStyle(color: color, fontWeight: fw)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Tổng hợp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          row('Tổng thu', totalIncome, color: Colors.green[700]),
          row('Tổng chi', totalExpense, color: Colors.red[700]),
          const Divider(),
          row('Số dư', balance, fw: FontWeight.w700),
        ]),
      ),
    );
  }
}
