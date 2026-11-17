import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../auth/session_controller.dart';
import 'job_models.dart';
import 'jobs_providers.dart';
import 'jobs_repository.dart';

enum ActionKind { onMyWay, start, complete, checklist, photo }

/// A job action that could not reach the server and is waiting to be sent.
/// Actions are replayed in the order they happened, so "complete" never
/// arrives before the photos and checklist ticks that came before it.
class QueuedAction {
  QueuedAction({
    required this.id,
    required this.kind,
    required this.jobId,
    required this.at,
    this.data = const {},
    this.attempts = 0,
  });

  final String id;
  final ActionKind kind;
  final String jobId;

  /// When the cleaner did it (shown nowhere yet, kept for the audit trail).
  final DateTime at;
  final Map<String, dynamic> data;
  int attempts;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'jobId': jobId,
        'at': at.toIso8601String(),
        'data': data,
        'attempts': attempts,
      };

  factory QueuedAction.fromJson(Map<String, dynamic> j) => QueuedAction(
        id: j['id'] as String,
        kind: ActionKind.values.firstWhere((k) => k.name == j['kind']),
        jobId: j['jobId'] as String,
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        data: Map<String, dynamic>.from(j['data'] as Map? ?? {}),
        attempts: (j['attempts'] as int?) ?? 0,
      );
}

/// Why an action was given up on (the server refused it).
class DroppedAction {
  const DroppedAction(this.action, this.message);

  final QueuedAction action;
  final String message;
}

const _maxAttempts = 8;

/// Persisted, per-user queue of actions waiting for a connection.
/// It flushes when the network comes back, when the app returns to the
/// foreground, and every 30 seconds while anything is waiting.
class OfflineQueue extends Notifier<List<QueuedAction>> with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _flushing = false;
  String? _owner;

  /// Set when the server refuses a queued action; the UI shows it once.
  final ValueNotifier<DroppedAction?> dropped = ValueNotifier(null);

  @override
  List<QueuedAction> build() {
    _owner = ref.watch(sessionProvider.select((s) => s.valueOrNull?.id));

    WidgetsBinding.instance.addObserver(this);
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.isNotEmpty) flush();
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _connectivity?.cancel();
      _timer?.cancel();
    });

    final loaded = _load();
    if (loaded.isNotEmpty) Future.microtask(flush);
    return loaded;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && state.isNotEmpty) flush();
  }

  String get _key => 'offline_queue_${_owner ?? 'none'}';

  List<QueuedAction> _load() {
    if (_owner == null) return [];
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => QueuedAction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (state.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(state.map((a) => a.toJson()).toList()));
    }
  }

  Future<void> enqueue(ActionKind kind, String jobId, [Map<String, dynamic> data = const {}]) async {
    final action = QueuedAction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      jobId: jobId,
      at: DateTime.now(),
      data: data,
    );
    state = [...state, action];
    await _save();
  }

  /// Queues a photo: the image is copied into the app's own storage so it
  /// survives the app being closed before it is sent.
  Future<void> enqueuePhoto({
    required String jobId,
    required String stage,
    required List<int> bytes,
    required String contentType,
    required String filename,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/queued_photos');
    if (!await folder.exists()) await folder.create(recursive: true);
    final path = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}_$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    await enqueue(ActionKind.photo, jobId, {
      'stage': stage,
      'path': path,
      'contentType': contentType,
      'filename': filename,
    });
  }

  /// Tries to send everything waiting, oldest first. Stops at the first
  /// network failure and keeps the rest for next time.
  Future<void> flush() async {
    if (_flushing || state.isEmpty || _owner == null) return;
    _flushing = true;
    var sentAny = false;
    try {
      final repo = ref.read(jobsRepositoryProvider);
      while (state.isNotEmpty) {
        final action = state.first;
        try {
          await _send(repo, action);
          sentAny = true;
          await _remove(action);
        } on ApiException catch (e) {
          final retryable = e.isNetwork || (e.status ?? 0) >= 500 || e.status == 429;
          if (retryable) {
            action.attempts++;
            if (e.isNetwork || action.attempts < _maxAttempts) {
              await _save();
              break; // try again later, keep order
            }
          }
          dropped.value = DroppedAction(action, e.message);
          await _remove(action);
        }
      }
    } finally {
      _flushing = false;
    }
    if (sentAny) {
      ref.invalidate(jobsProvider);
      ref.invalidate(jobProvider);
    }
  }

  Future<void> _remove(QueuedAction action) async {
    if (action.kind == ActionKind.photo) {
      try {
        await File(action.data['path'] as String).delete();
      } catch (_) {}
    }
    state = state.where((a) => a.id != action.id).toList();
    await _save();
  }

  Future<void> _send(JobsRepository repo, QueuedAction a) async {
    final d = a.data;
    LatLng? at() => (d['lat'] is num && d['lng'] is num)
        ? (lat: (d['lat'] as num).toDouble(), lng: (d['lng'] as num).toDouble())
        : null;

    switch (a.kind) {
      case ActionKind.onMyWay:
        return repo.onMyWay(a.jobId);
      case ActionKind.start:
        return repo.checkInAndStart(a.jobId, at());
      case ActionKind.complete:
        return repo.complete(a.jobId, at: at(), notes: d['notes'] as String?);
      case ActionKind.checklist:
        return repo.setChecklistItem(a.jobId, d['itemId'] as String, d['done'] as bool);
      case ActionKind.photo:
        final file = File(d['path'] as String);
        if (!await file.exists()) return; // nothing left to send
        return repo.uploadPhoto(
          bookingId: a.jobId,
          stage: d['stage'] as String,
          bytes: await file.readAsBytes(),
          contentType: d['contentType'] as String,
          filename: d['filename'] as String,
        );
    }
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueue, List<QueuedAction>>(OfflineQueue.new);

/// Shows what the server will look like once the queue is sent, so the
/// screen reflects what the cleaner already did while offline.
Job applyPending(Job job, List<QueuedAction> queue) {
  final mine = queue.where((a) => a.jobId == job.id).toList();
  if (mine.isEmpty) return job;

  var result = job;
  var assignment = job.assignment ?? const Assignment(id: '', isTeamLead: false);
  var checklist = job.checklist;

  for (final a in mine) {
    switch (a.kind) {
      case ActionKind.onMyWay:
        assignment = assignment.copyWith(onMyWayAt: a.at);
      case ActionKind.start:
        assignment = assignment.copyWith(checkedInAt: a.at);
      case ActionKind.complete:
        assignment = assignment.copyWith(checkedOutAt: a.at);
      case ActionKind.checklist:
        checklist = [
          for (final i in checklist)
            i.id == a.data['itemId'] ? i.copyWith(done: a.data['done'] == true) : i,
        ];
      case ActionKind.photo:
        break;
    }
  }
  result = result.copyWithPending(assignment: assignment, checklist: checklist);
  return result;
}

/// Number of photos waiting to be sent for [jobId] at [stage].
int pendingPhotos(List<QueuedAction> queue, String jobId, String stage) => queue
    .where((a) => a.jobId == jobId && a.kind == ActionKind.photo && a.data['stage'] == stage)
    .length;
