import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import '../jobs/job_models.dart';
import '../jobs/job_ui.dart';
import '../jobs/jobs_repository.dart';
import '../jobs/jobs_screen.dart' show JobCard;

/// Every job in a calendar month (key is the first day of that month).
final monthJobsProvider =
    FutureProvider.autoDispose.family<List<Job>, DateTime>((ref, month) async {
  final repo = ref.watch(jobsRepositoryProvider);
  final jobs = await repo.list(
    from: month,
    to: DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(seconds: 1)),
  );
  jobs.sort((a, b) => a.start.compareTo(b.start));
  return jobs;
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = _firstOf(DateTime.now());
  late DateTime _selected = startOfDay(DateTime.now());

  static DateTime _firstOf(DateTime d) => DateTime(d.year, d.month, 1);

  void _goToMonth(DateTime m) {
    final first = _firstOf(m);
    final now = DateTime.now();
    setState(() {
      _month = first;
      // Keep the selection inside the visible month: today if it is this
      // month, otherwise the 1st.
      _selected = (first.year == now.year && first.month == now.month)
          ? startOfDay(now)
          : first;
    });
  }

  void _shift(int months) => _goToMonth(DateTime(_month.year, _month.month + months, 1));

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final jobs = ref.watch(monthJobsProvider(_month));
    final byDay = <DateTime, List<Job>>{};
    for (final j in jobs.valueOrNull ?? const <Job>[]) {
      byDay.putIfAbsent(startOfDay(j.start), () => []).add(j);
    }
    final dayJobs = byDay[_selected] ?? const <Job>[];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthJobsProvider(_month));
            await ref.read(monthJobsProvider(_month).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              ScreenHeader(
                title: context.t('calendar.title'),
                trailing: Material(
                  color: Theme.of(context).cardTheme.color,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => _goToMonth(DateTime.now()),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Text(
                        context.t('calendar.today'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -200) _shift(1);
                  if (v > 200) _shift(-1);
                },
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            RoundIconButton(
                              icon: Icons.chevron_left_rounded,
                              semanticLabel: context.t('calendar.prev'),
                              size: 40,
                              onTap: () => _shift(-1),
                            ),
                            Expanded(
                              child: Text(
                                _capital(f.monthYear(_month)),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            RoundIconButton(
                              icon: Icons.chevron_right_rounded,
                              semanticLabel: context.t('calendar.next'),
                              size: 40,
                              onTap: () => _shift(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _weekdays(context),
                        const SizedBox(height: 4),
                        _grid(context, byDay),
                        if (jobs.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SectionHeading(_capital(f.dayLong(_selected))),
              if (jobs.hasError)
                ErrorView(
                  error: jobs.error!,
                  onRetry: () => ref.invalidate(monthJobsProvider(_month)),
                )
              else if (dayJobs.isEmpty && !jobs.isLoading)
                SizedBox(
                  height: 200,
                  child: EmptyView(
                    icon: Icons.event_available_outlined,
                    title: context.t('calendar.empty'),
                  ),
                )
              else
                for (var i = 0; i < dayJobs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  JobCard(
                    job: dayJobs[i],
                    onTap: () => context.push('/job/${dayJobs[i].id}'),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _weekdays(BuildContext context) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;
    // 2024-01-01 was a Monday: weeks start on Monday.
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                _capital(f.weekdayShort(DateTime(2024, 1, 1 + i))),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: hint),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grid(BuildContext context, Map<DateTime, List<Job>> byDay) {
    final lead = _month.weekday - 1; // blanks before the 1st (Monday first)
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final rows = ((lead + days) / 7).ceil();
    final today = startOfDay(DateTime.now());
    final theme = Theme.of(context);

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(builder: (context) {
                    final n = r * 7 + c - lead + 1;
                    if (n < 1 || n > days) return const SizedBox(height: 52);
                    final date = DateTime(_month.year, _month.month, n);
                    final selected = date == _selected;
                    final isToday = date == today;
                    final jobs = byDay[date] ?? const <Job>[];
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '${context.fmt.dayLong(date)}, ${jobs.length}',
                      child: ExcludeSemantics(
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _selected = date),
                          child: SizedBox(
                            height: 52,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    border: (isToday && !selected)
                                        ? Border.all(
                                            color: theme.colorScheme.primary,
                                            width: 1.5)
                                        : null,
                                  ),
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      fontWeight: (isToday || selected)
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: selected
                                          ? theme.colorScheme.onPrimary
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  height: 6,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final j in jobs.take(3))
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 1.2),
                                          decoration: BoxDecoration(
                                            color: phaseColor(j.phase),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
