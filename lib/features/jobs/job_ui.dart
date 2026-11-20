import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'job_models.dart';

String phaseLabel(BuildContext context, JobPhase phase) => switch (phase) {
      JobPhase.upcoming => context.t('job.phase.upcoming'),
      JobPhase.onTheWay => context.t('job.phase.onTheWay'),
      JobPhase.working => context.t('job.phase.working'),
      JobPhase.done => context.t('job.phase.done'),
      JobPhase.cancelled => context.t('job.phase.cancelled'),
    };

Color phaseColor(JobPhase phase) => switch (phase) {
      JobPhase.upcoming => Brand.blue,
      JobPhase.onTheWay => const Color(0xFFD98200),
      JobPhase.working => Brand.green,
      JobPhase.done => const Color(0xFF6B7585),
      JobPhase.cancelled => const Color(0xFFC8372D),
    };

class JobStatusPill extends StatelessWidget {
  const JobStatusPill({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: phaseLabel(context, job.phase),
        color: phaseColor(job.phase),
      );
}

IconData phaseIcon(JobPhase phase) => switch (phase) {
      JobPhase.upcoming => Icons.event_outlined,
      JobPhase.onTheWay => Icons.directions_car_outlined,
      JobPhase.working => Icons.cleaning_services_outlined,
      JobPhase.done => Icons.check_circle_outline,
      JobPhase.cancelled => Icons.cancel_outlined,
    };

/// How far along a job is, for progress bars: planned, on the way, working, done.
double phaseProgress(JobPhase phase) => switch (phase) {
      JobPhase.upcoming => 0.25,
      JobPhase.onTheWay => 0.5,
      JobPhase.working => 0.75,
      JobPhase.done => 1.0,
      JobPhase.cancelled => 0.0,
    };

/// 2h 30m, or an empty string for a non-positive span.
String durationText(DateTime start, DateTime end) {
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
