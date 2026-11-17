import 'package:cleaner_app/core/format.dart';
import 'package:cleaner_app/features/auth/auth_models.dart';
import 'package:cleaner_app/features/earnings/earnings_screen.dart';
import 'package:cleaner_app/features/jobs/job_models.dart';
import 'package:cleaner_app/features/profile/me_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('nl');
  });

  test('money formats cents in both languages', () {
    expect(Fmt('en').money(12550), contains('125.50'));
    expect(Fmt('nl').money(12550), contains('125,50'));
  });

  test('api dates use year-month-day', () {
    expect(Fmt.apiDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('earnings summary parses', () {
    final s = EarningsSummary.fromJson({
      'pendingCents': 5000,
      'lifetimePaidCents': 120000,
      'recentEarnings': [
        {'id': 'e1', 'amountCents': 2500, 'status': 'PAID', 'earnedAt': '2026-11-01T10:00:00Z'},
      ],
      'recentPayouts': [
        {
          'id': 'p1',
          'totalCents': 2500,
          'status': 'PAID',
          'periodStart': '2026-10-01T00:00:00Z',
          'periodEnd': '2026-10-31T00:00:00Z',
        },
      ],
    });
    expect(s.pendingCents, 5000);
    expect(s.earnings.single.status, 'PAID');
    expect(s.payouts.single.totalCents, 2500);
  });

  test('missing fields do not crash parsing', () {
    expect(EarningsSummary.fromJson({}).earnings, isEmpty);
    expect(Job.fromJson({}).phase, JobPhase.upcoming);
    expect(ChatThread.fromJson({}).open, true);
    expect(ChatThread.fromJson({'open': false}).open, false);
  });

  test('profile initials and name', () {
    final p = CleanerProfile.fromJson({
      'id': 'c1',
      'user': {'firstName': 'Anna', 'lastName': 'Jansen', 'email': 'a@b.nl'},
      'business': {'name': 'Tod Cleaning'},
    });
    expect(p.initials, 'AJ');
    expect(p.fullName, 'Anna Jansen');
  });

  test('leave and availability parse', () {
    final l = Leave.fromJson({
      'id': 'l1',
      'type': 'SICK',
      'status': 'PENDING',
      'startsAt': '2026-11-20T00:00:00Z',
      'endsAt': '2026-11-21T00:00:00Z',
    });
    expect(l.type, LeaveType.sick);
    expect(LeaveType.vacation.api, 'VACATION');

    final slot = AvailabilitySlot.fromJson({'dayOfWeek': 1, 'startTime': '08:00', 'endTime': '12:00'});
    expect(slot.toJson(), {'dayOfWeek': 1, 'startTime': '08:00', 'endTime': '12:00'});
  });

  test('document expiry', () {
    final past = MyDocument.fromJson({'id': 'd', 'title': 'ID', 'expiresAt': '2020-01-01T00:00:00Z'});
    final none = MyDocument.fromJson({'id': 'd', 'title': 'ID'});
    expect(past.expired, true);
    expect(none.expired, false);
  });

  test('photo view url is read', () {
    final p = JobPhoto.fromJson({'id': 'p', 'stage': 'AFTER', 'viewUrl': 'https://x/y.jpg'});
    expect(p.viewUrl, 'https://x/y.jpg');
  });
}
