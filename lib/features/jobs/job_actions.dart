import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'offline_queue.dart';

/// Runs a job action now, or queues it when there is no connection.
///
/// Returns true when the server got it, false when it was queued. If earlier
/// actions are already waiting, this one joins the queue straight away so
/// the server always sees things in the order they happened (for example the
/// "after" photo before "complete").
Future<bool> sendOrQueue(
  WidgetRef ref, {
  required ActionKind kind,
  required String jobId,
  Map<String, dynamic> data = const {},
  required Future<void> Function() send,
}) async {
  final queue = ref.read(offlineQueueProvider.notifier);

  if (ref.read(offlineQueueProvider).isNotEmpty) {
    await queue.enqueue(kind, jobId, data);
    queue.flush();
    return false;
  }
  try {
    await send();
    return true;
  } on ApiException catch (e) {
    if (!e.isNetwork) rethrow;
    await queue.enqueue(kind, jobId, data);
    return false;
  }
}
