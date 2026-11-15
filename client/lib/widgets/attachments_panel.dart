import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../models/attachment.dart';
import '../utils/format.dart';

/// Lists, uploads, opens, and deletes attachments for one resource.
class AttachmentsPanel extends StatefulWidget {
  const AttachmentsPanel({
    super.key,
    required this.resourceType,
    required this.resourceId,
  });

  final String resourceType; // 'works' | 'notes'
  final int resourceId;

  /// Opens the panel inside a scrollable dialog.
  static Future<void> show(
    BuildContext context, {
    required String resourceType,
    required int resourceId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Attachments'),
        content: SizedBox(
          width: 420,
          child: AttachmentsPanel(resourceType: resourceType, resourceId: resourceId),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  State<AttachmentsPanel> createState() => _AttachmentsPanelState();
}

class _AttachmentsPanelState extends State<AttachmentsPanel> {
  List<Attachment> _items = [];
  bool _loading = true;
  bool _uploading = false;
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
      final items = await context.read<Api>().attachments(widget.resourceType, widget.resourceId);
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load attachments: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final api = context.read<Api>();
    final picked = await FilePicker.pickFiles(dialogTitle: 'Attach a file');
    if (picked.isEmpty) return;
    final file = picked.first;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      await api.uploadAttachmentBytes(
            resourceType: widget.resourceType,
            resourceId: widget.resourceId,
            bytes: bytes,
            fileName: file.name,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded ${file.name}')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(Attachment attachment) async {
    final api = context.read<Api>();
    try {
      final bytes = await api.downloadAttachment(attachment.id);
      final dir = await getTemporaryDirectory();
      final safeName = attachment.originalName.replaceAll(RegExp(r'[^\w.\- ]'), '_');
      final file = File('${dir.path}/cm_${attachment.id}_$safeName');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: attachment.mimeType);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
      }
    }
  }

  Future<void> _delete(Attachment attachment) async {
    final api = context.read<Api>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${attachment.originalName}?'),
        content: const Text('The file is removed from this record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteAttachment(attachment.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _items.isEmpty ? 'No attachments yet' : '${_items.length} file(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_items.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = _items[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(a)),
                  title: Text(a.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(formatBytes(a.sizeBytes)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => _open(a),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _delete(a),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(Attachment a) {
    if (a.isImage) return Icons.image_outlined;
    if (a.isPdf) return Icons.picture_as_pdf_outlined;
    return switch (a.extension) {
      'doc' || 'docx' => Icons.description_outlined,
      'ppt' || 'pptx' => Icons.slideshow_outlined,
      'txt' => Icons.notes_outlined,
      _ => Icons.attach_file,
    };
  }
}
