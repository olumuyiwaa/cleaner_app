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
