import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'me_data.dart';

/// Weekly working hours. Days are shown Monday first; the API numbers
/// them 0 = Sunday.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  static const _order = [1, 2, 3, 4, 5, 6, 0];

  List<AvailabilitySlot>? _slots;
  bool _saving = false;

  Future<void> _pick(int index, {required bool start}) async {
    final slot = _slots![index];
    final current = _parse(start ? slot.startTime : slot.endTime);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final text = _format(picked);
    setState(() {
      _slots![index] = start ? slot.copyWith(startTime: text) : slot.copyWith(endTime: text);
    });
  }

  TimeOfDay _parse(String v) {
    final p = v.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    for (final s in _slots!) {
      if (s.startTime.compareTo(s.endTime) >= 0) {
        showInfo(context, context.t('availability.invalid'));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(meRepositoryProvider).saveAvailability(_slots!);
      ref.invalidate(availabilityProvider);
      if (mounted) showInfo(context, context.t('availability.saved'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(availabilityProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile.availability'))),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(availabilityProvider)),
        data: (loaded) {
          _slots ??= [...loaded];
          return _form(context);
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final slots = _slots!;
    final days = context.t('availability.days').split(',');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            context.t('availability.hint'),
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        for (final day in _order)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          days[day],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: context.t('availability.addSlot'),
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => slots.add(
                              AvailabilitySlot(
                                dayOfWeek: day,
                                startTime: '09:00',
                                endTime: '17:00',
                              ),
                            )),
                      ),
                    ],
                  ),
                  if (!slots.any((s) => s.dayOfWeek == day))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.t('availability.off'),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ),
                  for (var i = 0; i < slots.length; i++)
                    if (slots[i].dayOfWeek == day)
                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(84, 44)),
                            onPressed: () => _pick(i, start: true),
                            child: Text(slots[i].startTime),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('–'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(84, 44)),
                            onPressed: () => _pick(i, start: false),
                            child: Text(slots[i].endTime),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: context.t('common.remove'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => slots.removeAt(i)),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(context.t('common.save')),
        ),
      ],
    );
  }
}
