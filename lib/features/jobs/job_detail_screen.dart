import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';
import 'job_models.dart';
import 'job_ui.dart';
import 'job_actions.dart';
import 'job_widgets.dart';
import 'offline_queue.dart';
import 'jobs_providers.dart';
import 'jobs_repository.dart';
import 'live_location.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _busy = false;

  void _refresh() {
    ref.invalidate(jobProvider(widget.jobId));
    ref.invalidate(jobsProvider);
  }

  /// Runs a server action with a busy state, then refreshes the job.
  Future<void> _run(Future<bool> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      final sent = await action();
      if (!mounted) return;
      successFeedback();
      _refresh();
      showInfo(context, sent ? (success ?? '') : context.t('offline.queued'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// While the job is in progress, keep dispatch updated (also in the
  /// background); stop as soon as it is finished.
  void _syncPing(bool working) {
    final live = ref.read(liveLocationProvider.notifier);
    if (working) {
      live.start(widget.jobId);
    } else if (ref.read(liveLocationProvider) == widget.jobId) {
      live.stop();
    }
  }

  Future<void> _onMyWay() => _run(
        () => sendOrQueue(
          ref,
          kind: ActionKind.onMyWay,
          jobId: widget.jobId,
          send: () => ref.read(jobsRepositoryProvider).onMyWay(widget.jobId),
        ),
        success: context.t('job.onMyWaySent'),
      );

  Future<void> _checkIn() => _run(
        () async {
          final at = await ref.read(locationServiceProvider).currentPosition();
          return sendOrQueue(
            ref,
            kind: ActionKind.start,
            jobId: widget.jobId,
            data: {
              if (at != null) 'lat': at.lat,
              if (at != null) 'lng': at.lng
            },
            send: () => ref
                .read(jobsRepositoryProvider)
                .checkInAndStart(widget.jobId, at),
          );
        },
        success: context.t('job.checkedIn'),
      );

  Future<void> _complete(Job job) async {
    final notes = await _askCompletion(job);
    if (notes == null || !mounted) return;
    await _run(
      () async {
        final at = await ref.read(locationServiceProvider).currentPosition();
        return sendOrQueue(
          ref,
          kind: ActionKind.complete,
          jobId: widget.jobId,
          data: {
            if (at != null) 'lat': at.lat,
            if (at != null) 'lng': at.lng,
            if (notes.isNotEmpty) 'notes': notes,
          },
          send: () => ref
              .read(jobsRepositoryProvider)
              .complete(widget.jobId, at: at, notes: notes),
        );
      },
      success: context.t('job.completed'),
    );
  }

  /// Returns the optional note, or null when cancelled.
  Future<String?> _askCompletion(Job job) {
    final controller = TextEditingController();
    final warnings = <String>[
      if (job.checklist.isNotEmpty && job.checklistDone < job.checklist.length)
        context.t('job.warnChecklist', {
          'n': '${job.checklist.length - job.checklistDone}',
        }),
      if (job.photoCount('AFTER') +
              pendingPhotos(ref.read(offlineQueueProvider), job.id, 'AFTER') ==
          0)
        context.t('job.warnPhotos'),
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('job.completeTitle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: Color(0xFFD98200)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(w)),
                    ],
                  ),
                ),
              Text(ctx.t('job.completeMessage')),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: ctx.t('job.notes')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.t('job.complete')),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(Job job) async {
    final destination = (job.latitude != null && job.longitude != null)
        ? '${job.latitude},${job.longitude}'
        : Uri.encodeComponent(job.address);
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showInfo(context, context.t('job.cannotOpen'));
  }

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) showInfo(context, context.t('job.cannotOpen'));
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobProvider(widget.jobId));
    final queue = ref.watch(offlineQueueProvider);
    final waiting = queue.where((a) => a.jobId == widget.jobId).length;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: RoundIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => context.pop(),
            ),
          ),
        ),
        title: Text(context.t('job.title')),
      ),
      body: job.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(jobProvider(widget.jobId)),
        ),
        data: (job) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncPing(job.phase == JobPhase.working);
          });
          final resolvedJob = applyPending(job, queue);
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await ref.read(jobProvider(widget.jobId).future);
                  },
                  child: _body(context, resolvedJob, waiting),
                ),
              ),
              if (resolvedJob.phase != JobPhase.done &&
                  resolvedJob.phase != JobPhase.cancelled)
                _bottomBar(context, resolvedJob),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, Job job, int waiting) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;
    final phase = job.phase;
    final working = phase == JobPhase.working;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (waiting > 0) ...[
          _banner(
              context,
              Icons.cloud_upload_outlined,
              context.t('offline.waiting', {'n': '$waiting'}),
              const Color(0xFFD98200)),
          const SizedBox(height: 12),
        ],
        // Header: status icon, service, day, extras
        Row(
          children: [
            IconTile(icon: phaseIcon(phase), color: phaseColor(phase), size: 56),
            const Spacer(),
            JobStatusPill(job: job),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          job.serviceName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
        const SizedBox(height: 4),
        Text(f.dayLong(job.start), style: TextStyle(color: hint, fontSize: 15)),
        if (job.extras.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final extra in job.extras)
                StatusPill(
                  label: extra,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ],
        if (job.assignment?.isTeamLead == true) ...[
          const SizedBox(height: 8),
          Text(context.t('job.teamLead'), style: TextStyle(color: hint)),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProgressBlock(
              leftTop: f.timeRange(job.start, job.end),
              rightTop: durationText(job.start, job.end).isEmpty
                  ? null
                  : durationText(job.start, job.end),
              value: phaseProgress(phase),
              color: phaseColor(phase),
              leftBottom: phaseLabel(context, phase),
              rightBottom: '${(phaseProgress(phase) * 100).round()}%',
            ),
          ),
        ),
        if (phase != JobPhase.cancelled) ...[
          const SizedBox(height: 12),
          // Milestones: planned, on the way, working, done
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
              child: _Progress(phase: phase),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Where and who
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 20, color: hint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.address,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: hint),
                    const SizedBox(width: 8),
                    Expanded(child: Text(job.customerName)),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: _toolButton(
                        context,
                        Icons.navigation_outlined,
                        context.t('job.navigate'),
                        () => _openMaps(job),
                      ),
                    ),
                    if (job.customerPhone != null)
                      Expanded(
                        child: _toolButton(
                          context,
                          Icons.call_outlined,
                          context.t('job.call'),
                          () => _call(job.customerPhone!),
                        ),
                      ),
                    if (phase != JobPhase.cancelled)
                      Expanded(
                        child: _toolButton(
                          context,
                          Icons.chat_bubble_outline,
                          context.t('job.chat'),
                          () => context.push('/job/${job.id}/chat'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (job.hasNotes) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('job.accessNotes'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _note(context, Icons.pin_outlined,
                      context.t('job.accessCode'), job.accessCode,
                      copyable: true),
                  _note(context, Icons.key_outlined,
                      context.t('job.keyLocation'), job.keyLocation),
                  _note(context, Icons.local_parking, context.t('job.parking'),
                      job.parkingInstructions),
                  _note(context, Icons.pets_outlined, context.t('job.pets'),
                      job.petNotes),
                  _note(context, Icons.info_outline,
                      context.t('job.instructions'), job.specialInstructions),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        if (phase == JobPhase.done || phase == JobPhase.cancelled)
          _actions(context, job),

        if (job.checklist.isNotEmpty &&
            (working || phase == JobPhase.done)) ...[
          const SizedBox(height: 16),
          ChecklistSection(
            jobId: job.id,
            items: job.checklist,
            editable: working,
          ),
        ],
        if (working || phase == JobPhase.done) ...[
          const SizedBox(height: 12),
          PhotosSection(
            jobId: job.id,
            photos: job.photos,
            pending: {
              'BEFORE': pendingPhotos(
                  ref.watch(offlineQueueProvider), job.id, 'BEFORE'),
              'AFTER': pendingPhotos(
                  ref.watch(offlineQueueProvider), job.id, 'AFTER'),
            },
            canAdd: working,
            onUploaded: _refresh,
          ),
        ],
      ],
    );
  }

  /// The main buttons, pinned to the bottom so they are always in thumb reach.
  Widget _bottomBar(BuildContext context, Job job) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _actions(context, job),
        ),
      ),
    );
  }

  /// The primary buttons for the current stage of the job.
  Widget _actions(BuildContext context, Job job) {
    switch (job.phase) {
      case JobPhase.upcoming:
        return Column(
          children: [
            _centeredActionButton(
              onPressed: _busy
                  ? null
                  : () {
                      tapFeedback();
                      _checkIn();
                    },
              icon: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.login),
              label: context.t('job.checkIn'),
            ),
            const SizedBox(height: 10),
            _centeredActionButton(
              outlined: true,
              onPressed: _busy
                  ? null
                  : () {
                      tapFeedback();
                      _onMyWay();
                    },
              icon: const Icon(Icons.directions_walk),
              label: context.t('job.onMyWay'),
            ),
          ],
        );
      case JobPhase.onTheWay:
        return _centeredActionButton(
          onPressed: _busy
              ? null
              : () {
                  tapFeedback();
                  _checkIn();
                },
          icon: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.login),
          label: context.t('job.checkIn'),
        );
      case JobPhase.working:
        return _centeredActionButton(
          onPressed: _busy
              ? null
              : () {
                  tapFeedback();
                  _complete(job);
                },
          icon: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.check_circle_outline),
          label: context.t('job.complete'),
        );
      case JobPhase.done:
        return _banner(context, Icons.check_circle, context.t('job.doneBanner'),
            const Color(0xFF3F8A10));
      case JobPhase.cancelled:
        return _banner(context, Icons.cancel_outlined,
            context.t('job.cancelledBanner'), const Color(0xFFC8372D));
    }
  }

  Widget _centeredActionButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    bool outlined = false,
  }) {
    final child = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return outlined
        ? OutlinedButton(onPressed: onPressed, child: child)
        : FilledButton(onPressed: onPressed, child: child);
  }

  Widget _banner(
      BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _toolButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(
    BuildContext context,
    IconData icon,
    String label,
    String? value, {
    bool copyable = false,
  }) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onLongPress: copyable
            ? () {
                Clipboard.setData(ClipboardData(text: value));
                showInfo(context, context.t('common.copied'));
              }
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: hint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: hint)),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four dots showing where the job is: planned, on the way, working, done.
class _Progress extends StatelessWidget {
  const _Progress({required this.phase});

  final JobPhase phase;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (JobPhase.upcoming, context.t('job.step.planned')),
      (JobPhase.onTheWay, context.t('job.step.onTheWay')),
      (JobPhase.working, context.t('job.step.working')),
      (JobPhase.done, context.t('job.step.done')),
    ];
    final current = steps.indexWhere((s) => s.$1 == phase);
    final color = phaseColor(phase);
    final hint = Theme.of(context).hintColor;

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 3,
                              color: i <= current
                                  ? color
                                  : hint.withValues(alpha: 0.25)),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? color : Colors.transparent,
                        border: Border.all(
                          color: i <= current
                              ? color
                              : hint.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: i < current || phase == JobPhase.done
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox()
                          : Container(
                              height: 3,
                              color: i < current
                                  ? color
                                  : hint.withValues(alpha: 0.25)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  steps[i].$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == current ? FontWeight.w800 : FontWeight.w500,
                    color: i == current ? color : hint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
