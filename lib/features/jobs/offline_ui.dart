import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'offline_queue.dart';

/// Wraps the main shell: keeps the offline queue running and tells the
/// cleaner when the server refused something that was waiting to be sent.
class QueueWatcher extends ConsumerStatefulWidget {
  const QueueWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<QueueWatcher> createState() => _QueueWatcherState();
}

class _QueueWatcherState extends ConsumerState<QueueWatcher> {
  late final ValueNotifier<DroppedAction?> _dropped;

  @override
  void initState() {
    super.initState();
    _dropped = ref.read(offlineQueueProvider.notifier).dropped;
    _dropped.addListener(_onDropped);
  }

  @override
  void dispose() {
    _dropped.removeListener(_onDropped);
    super.dispose();
  }

  void _onDropped() {
    final d = _dropped.value;
    if (d == null || !mounted) return;
    showInfo(context, context.t('offline.dropped', {'message': d.message}));
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the queue (timer, connectivity listener) alive.
    final waiting = ref.watch(offlineQueueProvider).length;

    return Column(
      children: [
        if (waiting > 0)
          Material(
            color: const Color(0xFFD98200),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => ref.read(offlineQueueProvider.notifier).flush(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t('offline.waiting', {'n': '$waiting'}),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Text(
                        context.t('offline.syncNow'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          // The banner already sits under the status bar.
          child: waiting > 0
              ? MediaQuery.removePadding(context: context, removeTop: true, child: widget.child)
              : widget.child,
        ),
      ],
    );
  }
}
