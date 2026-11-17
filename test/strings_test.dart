import 'package:cleaner_app/core/l10n/strings.dart';
import 'package:cleaner_app/features/jobs/job_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dutch has every English key and no extras', () {
    expect(dutchKeys.difference(englishKeys), isEmpty);
    expect(englishKeys.difference(dutchKeys), isEmpty);
  });

  test('placeholders are replaced and unknown keys echo back', () {
    expect(trFor('en', 'jobs.hi', {'name': 'Anna'}), 'Hi Anna');
    expect(trFor('nl', 'jobs.hi', {'name': 'Anna'}), 'Hoi Anna');
    expect(trFor('en', 'no.such.key'), 'no.such.key');
  });

  test('job phase follows the assignment timestamps', () {
    Job make(String status, Map<String, dynamic> assignment) => Job.fromJson({
          'id': 'b1',
          'status': status,
          'scheduledStart': '2026-11-17T09:00:00Z',
          'scheduledEnd': '2026-11-17T11:00:00Z',
          'addressLine1': 'Damrak 1',
          'city': 'Amsterdam',
          'customer': {'firstName': 'Jan', 'lastName': 'de Vries'},
          'service': {'name': 'Standard clean'},
          'assignments': [assignment],
        });

    expect(make('ASSIGNED', {'id': 'a'}).phase, JobPhase.upcoming);
    expect(make('ASSIGNED', {'id': 'a', 'onMyWayAt': '2026-11-17T08:00:00Z'}).phase,
        JobPhase.onTheWay);
    expect(make('IN_PROGRESS', {'id': 'a', 'checkedInAt': '2026-11-17T09:00:00Z'}).phase,
        JobPhase.working);
    expect(make('COMPLETED', {'id': 'a'}).phase, JobPhase.done);
    expect(make('CANCELLED', {'id': 'a'}).phase, JobPhase.cancelled);
    expect(make('ASSIGNED', {'id': 'a'}).address, 'Damrak 1, Amsterdam');
  });
}
