import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

/// The cleaning checklist. Ticking an item is saved straight away; if the
/// save fails the tick is rolled back so the screen never lies about what
/// the office can see.
class ChecklistSection extends ConsumerStatefulWidget {
  const ChecklistSection({
    super.key,
    required this.jobId,
    required this.items,
    required this.editable,
  });

  final String jobId;
  final List<ChecklistItem> items;
  final bool editable;

  @override
  ConsumerState<ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<ChecklistSection> {
  late List<ChecklistItem> _items = widget.items;
  final Set<String> _saving = {};

  @override
  void didUpdateWidget(covariant ChecklistSection old) {
    super.didUpdateWidget(old);
    // Take fresh data from the server unless a save is in flight.
    if (_saving.isEmpty) _items = widget.items;
  }

  Future<void> _toggle(ChecklistItem item, bool value) async {
    setState(() {
      _saving.add(item.id);
      _items = [for (final i in _items) i.id == item.id ? i.copyWith(done: value) : i];
    });
    try {
      await ref.read(jobsRepositoryProvider).setChecklistItem(widget.jobId, item.id, value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [for (final i in _items) i.id == item.id ? i.copyWith(done: !value) : i];
      });
      showError(context, e);
    } finally {
      if (mounted) setState(() => _saving.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i.done).length;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.checklist, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('job.checklist'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  context.t('job.checklistProgress', {'done': '$done', 'total': '${_items.length}'}),
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: _items.isEmpty ? 0 : done / _items.length,
            minHeight: 3,
          ),
          for (final item in _items)
            CheckboxListTile(
              value: item.done,
              onChanged: (widget.editable && item.id.isNotEmpty)
                  ? (v) => _toggle(item, v ?? false)
                  : null,
              title: Text(
                item.label,
                style: TextStyle(
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? Theme.of(context).hintColor : null,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
        ],
      ),
    );
  }
}

String _contentTypeFor(String filename) {
  final n = filename.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic') || n.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Before / after proof photos. Photos are uploaded straight to storage and
/// then registered on the booking.
class PhotosSection extends ConsumerStatefulWidget {
  const PhotosSection({
    super.key,
    required this.jobId,
    required this.photos,
    required this.canAdd,
    required this.onUploaded,
  });

  final String jobId;
  final List<JobPhoto> photos;
  final bool canAdd;
  final VoidCallback onUploaded;

  @override
  ConsumerState<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<PhotosSection> {
  final _picker = ImagePicker();

  /// Thumbnails of photos added during this visit to the screen (the API
  /// does not hand out image URLs to cleaners, only that a photo exists).
  final Map<String, List<Uint8List>> _local = {'BEFORE': [], 'AFTER': []};
  String? _uploading;

  int _count(String stage) => widget.photos.where((p) => p.stage == stage).length;

  Future<void> _add(String stage) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.t('photo.camera')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.t('photo.gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() => _uploading = stage);
      await ref.read(jobsRepositoryProvider).uploadPhoto(
            bookingId: widget.jobId,
            stage: stage,
            bytes: bytes,
            contentType: _contentTypeFor(picked.name),
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() => _local[stage]!.add(bytes));
      widget.onUploaded();
      showInfo(context, context.t('photo.saved'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  context.t('job.photos'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _stage(context, 'BEFORE', context.t('photo.before')),
            const Divider(height: 28),
            _stage(context, 'AFTER', context.t('photo.after')),
          ],
        ),
      ),
    );
  }

  Widget _stage(BuildContext context, String stage, String title) {
    final count = _count(stage);
    final uploading = _uploading == stage;
    final thumbs = _local[stage]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title · ${context.t('photo.count', {'n': '$count'})}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (widget.canAdd)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _uploading == null ? () => _add(stage) : null,
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(context.t('photo.add')),
              ),
          ],
        ),
        if (thumbs.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: thumbs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(thumbs[i], width: 72, height: 72, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
