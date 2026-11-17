import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'me_data.dart';

const _docTypes = ['ID_CARD', 'CERTIFICATION', 'INSURANCE', 'OTHER'];

String _mimeFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, MyDocument d) async {
    try {
      final url = await ref.read(meRepositoryProvider).documentUrl(d.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showInfo(context, context.t('job.cannotOpen'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(documentsProvider);
    final f = context.fmt;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile.documents'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _UploadForm(),
          );
          if (added == true) ref.invalidate(documentsProvider);
        },
        icon: const Icon(Icons.upload_file),
        label: Text(context.t('documents.upload')),
      ),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(documentsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.folder_open_outlined,
              title: context.t('documents.empty'),
              message: context.t('documents.emptyHint'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(documentsProvider);
              await ref.read(documentsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final d = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      context.t('documents.type.${d.type}'),
                      if (d.expiresAt != null)
                        '${d.expired ? context.t('documents.expired') : context.t('documents.expires')} ${f.date(d.expiresAt!)}',
                    ].join(' · ')),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _open(context, ref, d),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _UploadForm extends ConsumerStatefulWidget {
  const _UploadForm();

  @override
  ConsumerState<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends ConsumerState<_UploadForm> {
  final _title = TextEditingController();
  String _type = _docTypes.first;
  DateTime? _expires;
  PlatformFile? _file;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _file = result.files.first;
      if (_title.text.isEmpty) _title.text = _file!.name.split('.').first;
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _expires = picked);
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null || file.bytes == null || _title.text.trim().isEmpty) {
      showInfo(context, context.t('documents.needFile'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(meRepositoryProvider).uploadDocument(
            bytes: file.bytes!,
            filename: file.name,
            contentType: _mimeFor(file.name),
            title: _title.text.trim(),
            type: _type,
            expiresAt: _expires,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('documents.upload'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _chooseFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_file?.name ?? context.t('documents.chooseFile')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.t('documents.title')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: context.t('documents.typeLabel')),
              items: [
                for (final t in _docTypes)
                  DropdownMenuItem(value: t, child: Text(context.t('documents.type.$t'))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickExpiry,
              icon: const Icon(Icons.event_outlined),
              label: Text(_expires == null
                  ? context.t('documents.setExpiry')
                  : context.fmt.date(_expires!)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(context.t('documents.upload')),
            ),
          ],
        ),
      ),
    );
  }
}
