import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/recycle_bin_item.dart';
import '../theme.dart';
import '../widgets/v2_kit.dart';

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
      if (mounted) _toast('Restored ${item.label}');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _purge(RecycleBinItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${item.label} forever?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<Api>().deleteRecycleItem(item.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: v2PagePadding(context),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeading(
                  title: 'Recently deleted',
                  subtitle: 'Restore within 30 days before items are purged automatically.',
                  trailing: IconAction(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    compact: true,
                    onPressed: _loading ? null : _load,
                  ),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        PillButton(
                          label: 'Retry',
                          icon: Icons.refresh,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  )
                else if (_items.isEmpty)
                  const V2Empty(
                    icon: Icons.delete_outline,
                    title: 'Recycle bin is empty',
                    message: 'Deleted notes, tasks, subjects, and grade components land here first.',
                  )
                else ...[
                  V2Badge(
                    '${_items.length} ${_items.length == 1 ? 'item' : 'items'} recoverable',
                    icon: Icons.auto_delete_outlined,
                    color: colors.amber,
                    dense: true,
                  ),
                  const SizedBox(height: 10),
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: colors.textDim.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                _iconFor(item.type),
                                size: 18,
                                color: colors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    [
                                      _labelFor(item.type),
                                      if (item.deletedAt != null)
                                        'deleted ${_shortDate(item.deletedAt!)}',
                                      if (item.expiresAt != null)
                                        'expires ${_shortDate(item.expiresAt!)}',
                                    ].join(' · '),
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconAction(
                              icon: Icons.restore,
                              tooltip: 'Restore',
                              compact: true,
                              color: colors.emerald,
                              onPressed: () => _restore(item),
                            ),
                            const SizedBox(width: 6),
                            IconAction(
                              icon: Icons.delete_forever_outlined,
                              tooltip: 'Delete forever',
                              compact: true,
                              color: colors.rose,
                              onPressed: () => _purge(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

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
