import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/recycle_bin_item.dart';
import '../widgets/animated_glass_background.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<RecycleBinItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<Api>().recycleBin();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load recycle bin: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(RecycleBinItem item) async {
    try {
      await context.read<Api>().restoreRecycleItem(item.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored ${item.label}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _purge(RecycleBinItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${item.label} forever?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<Api>().deleteRecycleItem(item.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Recycle bin'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _items.isEmpty
                    ? const Center(child: Text('Recycle bin is empty.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final item in _items)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(_iconFor(item.type)),
                                title: Text(item.label),
                                subtitle: Text(
                                  [
                                    _labelFor(item.type),
                                    if (item.deletedAt != null)
                                      'deleted ${item.deletedAt!.toIso8601String().substring(0, 10)}',
                                    if (item.expiresAt != null)
                                      'expires ${item.expiresAt!.toIso8601String().substring(0, 10)}',
                                  ].join(' · '),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Restore',
                                      icon: const Icon(Icons.restore),
                                      onPressed: () => _restore(item),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete forever',
                                      icon: const Icon(Icons.delete_forever_outlined),
                                      onPressed: () => _purge(item),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }

  static String _labelFor(String type) => switch (type) {
        'note' => 'Note',
        'work' => 'School work',
        'subject' => 'Subject',
        'grade' => 'Grade component',
        'session' => 'Study session',
        'attendance' => 'Attendance record',
        _ => 'Item',
      };

  static IconData _iconFor(String type) => switch (type) {
        'note' => Icons.note_alt_outlined,
        'work' => Icons.assignment_outlined,
        'subject' => Icons.book_outlined,
        'grade' => Icons.grading_outlined,
        'session' => Icons.timer_outlined,
        'attendance' => Icons.fact_check_outlined,
        _ => Icons.inventory_2_outlined,
      };
}
