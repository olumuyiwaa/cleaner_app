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
    final name = ref.watch(sessionProvider).valueOrNull?.firstName ?? '';

    return DefaultTabController(
      length: JobsTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            name.isEmpty ? context.t('jobs.title') : context.t('jobs.hi', {'name': name}),
          ),
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
      loading: () => const LoadingView(),
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

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => JobCard(
              job: list[i],
              showDate: tab != JobsTab.today,
              onTap: () => context.push('/job/${list[i].id}'),
            ),
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

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap, this.showDate = false});

  final Job job;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;
    final active = job.phase == JobPhase.working || job.phase == JobPhase.onTheWay;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: active
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: phaseColor(job.phase), width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showDate
                          ? '${f.day(job.start)} · ${f.timeRange(job.start, job.end)}'
                          : f.timeRange(job.start, job.end),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  JobStatusPill(job: job),
                ],
              ),
              const SizedBox(height: 8),
              Text(job.serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: hint),
                  const SizedBox(width: 6),
                  Expanded(child: Text(job.address, style: TextStyle(color: hint))),
                ],
              ),
              if (job.customerFirstName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: hint),
                    const SizedBox(width: 6),
                    Text(job.customerName, style: TextStyle(color: hint)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
