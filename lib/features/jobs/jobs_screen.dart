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
        // extendBodyBehindAppBar so hero card can sit flush under the status bar
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty
                    ? context.t('jobs.title')
                    : context.t('jobs.hi', {'name': name}),
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
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () => context.go('/profile'),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  backgroundImage: profile?.avatarUrl == null
                      ? null
                      : NetworkImage(profile!.avatarUrl!),
                  child: profile?.avatarUrl == null
                      ? Text(
                          profile?.initials ?? '?',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: [
                Tab(text: context.t('jobs.today')),
                Tab(text: context.t('jobs.upcoming')),
                Tab(text: context.t('jobs.past')),
              ],
            ),
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
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(jobsProvider(tab))),
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
                    message: tab == JobsTab.today
                        ? context.t('jobs.empty.todayHint')
                        : null,
                  ),
                ),
              ],
            ),
          );
        }

        // On the Today tab the first job that is not finished is "next up".
        final nextIndex = tab == JobsTab.today
            ? list.indexWhere(
                (j) =>
                    j.phase != JobPhase.done && j.phase != JobPhase.cancelled,
              )
            : -1;
        final header = tab == JobsTab.today ? 1 : 0;

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            // Extra bottom padding for the floating pill nav
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            itemCount: list.length + header,
            separatorBuilder: (_, i) =>
                SizedBox(height: i == 0 && header == 1 ? 14 : 10),
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
    final left = jobs
        .where((j) => j.phase != JobPhase.done && j.phase != JobPhase.cancelled)
        .length;
    final summary = jobs.length == 1
        ? context.t('jobs.summary.one')
        : context.t('jobs.summary.many', {'n': '${jobs.length}'});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        left == 0 ? context.t('jobs.allDone') : summary,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
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
    final active =
        job.phase == JobPhase.working || job.phase == JobPhase.onTheWay;
    final muted = job.phase == JobPhase.done || job.phase == JobPhase.cancelled;
    final duration = _duration(context, job.start, job.end);

    final borderColor = (active || nextUp)
        ? color.withValues(alpha: 0.45)
        : Theme.of(context).dividerColor;

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: (active || nextUp) ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nextUp && !active) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.t('jobs.nextUp').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDate)
                                Text(
                                  f.day(job.start),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: hint,
                                  ),
                                ),
                              Text(
                                f.timeRange(job.start, job.end),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        JobStatusPill(job: job),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      job.serviceName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 7),
                    _line(Icons.place_outlined, job.address, hint, maxLines: 2),
                    if (job.customerFirstName.isNotEmpty)
                      _line(Icons.person_outline, job.customerName, hint),
                    if (duration.isNotEmpty)
                      _line(Icons.timer_outlined, duration, hint),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: hint.withValues(alpha: muted ? 0.7 : 1),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(
    IconData icon,
    String text,
    Color color, {
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
