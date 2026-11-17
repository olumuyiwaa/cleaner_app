import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

enum JobsTab { today, upcoming, past }

/// Jobs for one tab of the list.
///  - today:    everything scheduled today, in time order
///  - upcoming: the next 14 days after today, soonest first
///  - past:     the last 30 days before today, most recent first
final jobsProvider =
    FutureProvider.autoDispose.family<List<Job>, JobsTab>((ref, tab) async {
  final repo = ref.watch(jobsRepositoryProvider);
  final today = startOfDay(DateTime.now());

  switch (tab) {
    case JobsTab.today:
      final jobs = await repo.list(
        from: today,
        to: today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)),
      );
      jobs.sort((a, b) => a.start.compareTo(b.start));
      return jobs;
    case JobsTab.upcoming:
      final jobs = await repo.list(
        from: today.add(const Duration(days: 1)),
        to: today.add(const Duration(days: 15)),
      );
      jobs.sort((a, b) => a.start.compareTo(b.start));
      return jobs;
    case JobsTab.past:
      final jobs = await repo.list(
        from: today.subtract(const Duration(days: 30)),
        to: today.subtract(const Duration(seconds: 1)),
      );
      jobs.sort((a, b) => b.start.compareTo(a.start));
      return jobs;
  }
});

final jobProvider = FutureProvider.autoDispose.family<Job, String>(
  (ref, id) => ref.watch(jobsRepositoryProvider).get(id),
);
