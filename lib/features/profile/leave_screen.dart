import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'me_data.dart';

class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  Color _color(String status) => switch (status) {
        'APPROVED' => const Color(0xFF3F8A10),
        'REJECTED' => const Color(0xFFC8372D),
        'CANCELLED' => const Color(0xFF6B7585),
        _ => const Color(0xFFD98200),
      };

  Future<void> _withdraw(BuildContext context, WidgetRef ref, Leave leave) async {
    final ok = await confirm(
      context,
      title: context.t('leave.withdraw'),
      message: context.t('leave.withdrawConfirm'),
      confirmLabel: context.t('leave.withdraw'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(meRepositoryProvider).withdrawLeave(leave.id);
      ref.invalidate(leaveProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leaveProvider);
    final f = context.fmt;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile.leave'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const _LeaveForm(),
          );
          if (created == true) ref.invalidate(leaveProvider);
        },
        icon: const Icon(Icons.add),
        label: Text(context.t('leave.request')),
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(leaveProvider)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.beach_access_outlined,
              title: context.t('leave.empty'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(leaveProvider);
              await ref.read(leaveProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final l = list[i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.t('leave.type.${l.type.name}'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            StatusPill(
                              label: context.t('leave.status.${l.status.toLowerCase()}'),
                              color: _color(l.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${f.date(l.startsAt)} – ${f.date(l.endsAt)}'),
                        if (l.reason != null) ...[
                          const SizedBox(height: 6),
                          Text(l.reason!, style: TextStyle(color: Theme.of(context).hintColor)),
                        ],
                        if (l.decisionNote != null) ...[
                          const SizedBox(height: 6),
                          Text('${context.t('leave.note')}: ${l.decisionNote}'),
                        ],
                        if (l.status == 'PENDING')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _withdraw(context, ref, l),
                              child: Text(context.t('leave.withdraw')),
                            ),
                          ),
                      ],
                    ),
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

class _LeaveForm extends ConsumerStatefulWidget {
  const _LeaveForm();

  @override
  ConsumerState<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends ConsumerState<_LeaveForm> {
  LeaveType _type = LeaveType.vacation;
  DateTime? _start;
  DateTime? _end;
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _start ?? now,
      firstDate: start ? now : (_start ?? now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) {
      showInfo(context, context.t('leave.pickDates'));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(meRepositoryProvider).requestLeave(
            type: _type,
            start: _start!,
            end: _end!,
            reason: _reason.text.trim(),
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
    final f = context.fmt;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('leave.request'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<LeaveType>(
              initialValue: _type,
              decoration: InputDecoration(labelText: context.t('leave.typeLabel')),
              items: [
                for (final t in LeaveType.values)
                  DropdownMenuItem(value: t, child: Text(context.t('leave.type.${t.name}'))),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(start: true),
                    child: Text(_start == null ? context.t('leave.from') : f.date(_start!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(start: false),
                    child: Text(_end == null ? context.t('leave.to') : f.date(_end!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.t('leave.reason')),
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
                  : Text(context.t('leave.submit')),
            ),
          ],
        ),
      ),
    );
  }
}
