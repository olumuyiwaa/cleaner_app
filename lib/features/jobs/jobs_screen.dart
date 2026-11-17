import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import '../auth/session_controller.dart';
import 'job_models.dart';
import 'job_ui.dart';
import 'jobs_providers.dart';

class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).valueOrNull;
    final name = profile?.firstName ?? '';

    return DefaultTabController(
      length: JobsTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? context.t('jobs.title') : context.t('jobs.hi', {'name': name}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                context.fmt.dayLong(DateTime.now()),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: context.t('nav.profile'),
                onPressed: () => context.go('/profile'),
                icon: CircleAvatar(
                  radius: 19,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  backgroundImage:
                      profile?.avatarUrl == null ? null : NetworkImage(profile!.avatarUrl!),
                  child: profile?.avatarUrl == null
                      ? Text(
                          profile?.initials ?? '?',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: context.t('jobs.today')),
              Tab(text: context.t('jobs.upcoming')),
              Tab(text: context.t('jobs.past')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _JobsList(tab: JobsTab.today),
            _JobsList(tab: JobsTab.upcoming),
            _JobsList(tab: JobsTab.past),
          ],
        ),
      ),
    );
  }
}

class _JobsList extends ConsumerWidget {
  const _JobsList({required this.tab});

  final JobsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider(tab));

    return jobs.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(jobsProvider(tab))),
      data: (list) {
        Future<void> refresh() async {
          ref.invalidate(jobsProvider(tab));
          await ref.read(jobsProvider(tab).future);
        }

        if (list.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: EmptyView(
                    icon: Icons.event_available_outlined,
                    title: context.t('jobs.empty.$tabKey'),
                    message: tab == JobsTab.today ? context.t('jobs.empty.todayHint') : null,
                  ),
                ),
              ],
            ),
          );
        }

        // On the Today tab the first job that is not finished is "next up".
        final nextIndex = tab == JobsTab.today
            ? list.indexWhere(
                (j) => j.phase != JobPhase.done && j.phase != JobPhase.cancelled,
              )
            : -1;
        final header = tab == JobsTab.today ? 1 : 0;

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length + header,
            separatorBuilder: (_, i) => SizedBox(height: i == 0 && header == 1 ? 14 : 12),
            itemBuilder: (context, i) {
              if (header == 1 && i == 0) return _TodayHeader(jobs: list);
              final index = i - header;
              return JobCard(
                job: list[index],
                showDate: tab != JobsTab.today,
                nextUp: index == nextIndex,
                onTap: () => context.push('/job/${list[index].id}'),
              );
            },
          ),
        );
      },
    );
  }

  String get tabKey => switch (tab) {
        JobsTab.today => 'today',
        JobsTab.upcoming => 'upcoming',
        JobsTab.past => 'past',
      };
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.jobs});

  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final left = jobs
        .where((j) => j.phase != JobPhase.done && j.phase != JobPhase.cancelled)
        .length;
    final summary = jobs.length == 1
        ? context.t('jobs.summary.one')
        : context.t('jobs.summary.many', {'n': '${jobs.length}'});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.dayLong(DateTime.now()),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            left == 0 ? context.t('jobs.allDone') : summary,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

String _duration(BuildContext context, DateTime start, DateTime end) {
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.showDate = false,
    this.nextUp = false,
  });

  final Job job;
  final VoidCallback onTap;
  final bool showDate;
  final bool nextUp;

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;
    final color = phaseColor(job.phase);
    final active = job.phase == JobPhase.working || job.phase == JobPhase.onTheWay;
    final muted = job.phase == JobPhase.done || job.phase == JobPhase.cancelled;
    final duration = _duration(context, job.start, job.end);

    return Opacity(
      opacity: muted ? 0.72 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: (active || nextUp) ? color : Theme.of(context).dividerColor,
            width: (active || nextUp) ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nextUp && !active) ...[
                          Text(
                            context.t('jobs.nextUp').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDate)
                                    Text(
                                      f.day(job.start),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: hint,
                                      ),
                                    ),
                                  Text(
                                    f.timeRange(job.start, job.end),
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            JobStatusPill(job: job),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          job.serviceName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        _line(Icons.place_outlined, job.address, hint),
                        if (job.customerFirstName.isNotEmpty)
                          _line(Icons.person_outline, job.customerName, hint),
                        if (duration.isNotEmpty) _line(Icons.timer_outlined, duration, hint),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right, color: hint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );
}
