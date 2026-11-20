import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import '../auth/session_controller.dart';
import 'job_models.dart';
import 'job_ui.dart';
import 'jobs_providers.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  JobsTab _tab = JobsTab.today;

  Future<void> _refresh() async {
    ref.invalidate(jobsProvider);
    await ref.read(jobsProvider(_tab).future);
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showInfo(context, context.t('job.cannotOpen'));
  }

  Uri _directions(Job job) {
    final destination = (job.latitude != null && job.longitude != null)
        ? '${job.latitude},${job.longitude}'
        : Uri.encodeComponent(job.address);
    return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destination');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).valueOrNull;
    final name = profile?.firstName ?? '';
    final today = ref.watch(jobsProvider(JobsTab.today));
    final list = ref.watch(jobsProvider(_tab));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              ScreenHeader(
                title: name.isEmpty
                    ? context.t('jobs.title')
                    : context.t('jobs.welcome', {'name': name}),
                subtitle: context.fmt.dayLong(DateTime.now()),
                trailing: GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: CircleAvatar(
                    radius: 22,
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
              _hero(context, today),
              SectionHeading(context.t('jobs.title')),
              PillTabs(
                labels: [
                  context.t('jobs.today'),
                  context.t('jobs.upcoming'),
                  context.t('jobs.past'),
                ],
                selected: JobsTab.values.indexOf(_tab),
                onChanged: (i) => setState(() => _tab = JobsTab.values[i]),
              ),
              const SizedBox(height: 14),
              ..._jobs(context, list),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, AsyncValue<List<Job>> today) {
    return today.when(
      loading: () => const _HeroSkeleton(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(jobsProvider(JobsTab.today)),
      ),
      data: (jobs) {
        final f = context.fmt;
        final remaining = jobs
            .where((j) =>
                j.phase != JobPhase.done && j.phase != JobPhase.cancelled)
            .toList();
        final next = remaining.isEmpty ? null : remaining.first;
        final summary = jobs.isEmpty
            ? context.t('jobs.empty.today')
            : (next == null
                ? context.t('jobs.allDone')
                : (jobs.length == 1
                    ? context.t('jobs.summary.one')
                    : context.t('jobs.summary.many', {'n': '${jobs.length}'})));

        return HeroCard(
          chip: summary,
          label: next == null ? context.t('jobs.today') : context.t('jobs.nextJob'),
          value: next == null
              ? '${jobs.length - remaining.length}/${jobs.length}'
              : f.timeRange(next.start, next.end),
          footer: next == null
              ? null
              : Column(
                  children: [
                    Text(
                      next.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
          actions: [
            HeroAction(
              icon: Icons.navigation_outlined,
              label: context.t('job.navigate'),
              onTap: next == null ? null : () => _open(_directions(next)),
            ),
            HeroAction(
              icon: Icons.call_outlined,
              label: context.t('job.call'),
              onTap: (next?.customerPhone == null)
                  ? null
                  : () => _open(Uri(scheme: 'tel', path: next!.customerPhone)),
            ),
            HeroAction(
              icon: Icons.chat_bubble_outline,
              label: context.t('job.chat'),
              onTap: next == null ? null : () => context.push('/job/${next.id}/chat'),
            ),
            HeroAction(
              icon: Icons.assignment_outlined,
              label: context.t('job.title'),
              onTap: next == null ? null : () => context.push('/job/${next.id}'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _jobs(BuildContext context, AsyncValue<List<Job>> list) {
    return list.when(
      loading: () => const [_CardSkeleton(), SizedBox(height: 12), _CardSkeleton()],
      error: (e, _) => [
        ErrorView(error: e, onRetry: () => ref.invalidate(jobsProvider(_tab))),
      ],
      data: (jobs) {
        if (jobs.isEmpty) {
          return [
            SizedBox(
              height: 260,
              child: EmptyView(
                icon: Icons.event_available_outlined,
                title: context.t('jobs.empty.${_tabKey(_tab)}'),
                message: _tab == JobsTab.today
                    ? context.t('jobs.empty.todayHint')
                    : null,
              ),
            ),
          ];
        }
        final nextIndex = _tab == JobsTab.today
            ? jobs.indexWhere((j) =>
                j.phase != JobPhase.done && j.phase != JobPhase.cancelled)
            : -1;
        return [
          for (var i = 0; i < jobs.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            JobCard(
              job: jobs[i],
              showDate: _tab != JobsTab.today,
              nextUp: i == nextIndex,
              onTap: () => context.push('/job/${jobs[i].id}'),
            ),
          ],
        ];
      },
    );
  }

  static String _tabKey(JobsTab tab) => switch (tab) {
        JobsTab.today => 'today',
        JobsTab.upcoming => 'upcoming',
        JobsTab.past => 'past',
      };
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
        child: SizedBox(
          height: 250,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Skeleton(width: 44, height: 44, radius: 14),
                SizedBox(width: 12),
                Skeleton(width: 140, height: 18),
              ]),
              SizedBox(height: 14),
              Skeleton(height: 56, radius: 18),
            ],
          ),
        ),
      );
}

/// A job as an inset card: service and phase on top, time, progress and place
/// in the panel below.
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
    final color = phaseColor(job.phase);
    final percent = (phaseProgress(job.phase) * 100).round();
    final duration = durationText(job.start, job.end);
    final timeText = showDate
        ? '${f.day(job.start)} · ${f.timeRange(job.start, job.end)}'
        : f.timeRange(job.start, job.end);

    return InsetCard(
      icon: phaseIcon(job.phase),
      iconColor: color,
      title: job.serviceName,
      onTap: onTap,
      trailing: JobStatusPill(job: job),
      child: ProgressBlock(
        leftTop: timeText,
        rightTop: duration.isEmpty ? null : duration,
        value: phaseProgress(job.phase),
        color: color,
        leftBottom: nextUp && job.phase == JobPhase.upcoming
            ? '${context.t('jobs.nextUp')} · ${job.address}'
            : job.address,
        rightBottom: '$percent%',
      ),
    );
  }
}
