import 'package:cleaner_app/features/jobs/job_models.dart';
import 'package:cleaner_app/features/jobs/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Job _job({String status = 'ASSIGNED', Map<String, dynamic>? assignment}) => Job.fromJson({
      'id': 'b1',
      'status': status,
      'scheduledStart': '2026-11-17T09:00:00Z',
      'scheduledEnd': '2026-11-17T11:00:00Z',
      'addressLine1': 'Damrak 1',
      'city': 'Amsterdam',
      'customer': {'firstName': 'Jan', 'lastName': 'de Vries'},
      'service': {'name': 'Standard clean'},
      'assignments': [assignment ?? {'id': 'a1'}],
      'checklist': {
        'items': [
          {'id': 'i1', 'label': 'Kitchen', 'done': false},
          {'id': 'i2', 'label': 'Bathroom', 'done': false},
        ],
      },
    });

QueuedAction _action(ActionKind kind, {String jobId = 'b1', Map<String, dynamic> data = const {}}) =>
    QueuedAction(id: '${kind.name}$jobId', kind: kind, jobId: jobId, at: DateTime(2026, 11, 17, 9), data: data);

void main() {
  test('queued actions survive a JSON round trip', () {
    final a = _action(ActionKind.checklist, data: {'itemId': 'i1', 'done': true});
    final back = QueuedAction.fromJson(a.toJson());
    expect(back.kind, ActionKind.checklist);
    expect(back.jobId, 'b1');
    expect(back.data['itemId'], 'i1');
    expect(back.data['done'], true);
  });

  test('pending start and complete move the job forward', () {
    expect(applyPending(_job(), [_action(ActionKind.onMyWay)]).phase, JobPhase.onTheWay);
    expect(applyPending(_job(), [_action(ActionKind.start)]).phase, JobPhase.working);
    expect(
      applyPending(_job(), [_action(ActionKind.start), _action(ActionKind.complete)]).phase,
      JobPhase.done,
    );
  });

  test('pending checklist ticks are shown', () {
    final job = applyPending(_job(), [
      _action(ActionKind.checklist, data: {'itemId': 'i2', 'done': true}),
    ]);
    expect(job.checklist.map((i) => i.done), [false, true]);
  });

  test('actions for other jobs are ignored', () {
    final job = applyPending(_job(), [_action(ActionKind.start, jobId: 'other')]);
    expect(job.phase, JobPhase.upcoming);
  });

  test('pending photos are counted per stage', () {
    final queue = [
      _action(ActionKind.photo, data: {'stage': 'AFTER'}),
      _action(ActionKind.photo, data: {'stage': 'AFTER'}),
      _action(ActionKind.photo, data: {'stage': 'BEFORE'}),
    ];
    expect(pendingPhotos(queue, 'b1', 'AFTER'), 2);
    expect(pendingPhotos(queue, 'b1', 'BEFORE'), 1);
    expect(pendingPhotos(queue, 'zzz', 'AFTER'), 0);
  });
}
