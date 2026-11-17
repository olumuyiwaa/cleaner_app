import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/providers.dart';
import '../auth/auth_models.dart';

// ── Models ─────────────────────────────────────────────────────────────

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  /// 0 = Sunday … 6 = Saturday (the server's convention).
  final int dayOfWeek;

  /// "HH:mm"
  final String startTime;
  final String endTime;

  AvailabilitySlot copyWith({String? startTime, String? endTime}) => AvailabilitySlot(
        dayOfWeek: dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
      );

  Map<String, dynamic> toJson() =>
      {'dayOfWeek': dayOfWeek, 'startTime': startTime, 'endTime': endTime};

  factory AvailabilitySlot.fromJson(Map<String, dynamic> j) => AvailabilitySlot(
        dayOfWeek: intOf(j['dayOfWeek']),
        startTime: str(j['startTime']) ?? '09:00',
        endTime: str(j['endTime']) ?? '17:00',
      );
}

enum LeaveType { vacation, sick, personal, other }

extension LeaveTypeApi on LeaveType {
  String get api => name.toUpperCase();

  static LeaveType parse(String? v) => LeaveType.values.firstWhere(
        (t) => t.api == v,
        orElse: () => LeaveType.other,
      );
}

class Leave {
  const Leave({
    required this.id,
    required this.type,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.reason,
    this.decisionNote,
  });

  final String id;
  final LeaveType type;

  /// PENDING, APPROVED, REJECTED or CANCELLED
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;
  final String? decisionNote;

  factory Leave.fromJson(Map<String, dynamic> j) => Leave(
        id: str(j['id']) ?? '',
        type: LeaveTypeApi.parse(str(j['type'])),
        status: str(j['status']) ?? 'PENDING',
        startsAt: dateOf(j['startsAt']) ?? DateTime.now(),
        endsAt: dateOf(j['endsAt']) ?? DateTime.now(),
        reason: str(j['reason']),
        decisionNote: str(j['decisionNote']),
      );
}

class MyDocument {
  const MyDocument({
    required this.id,
    required this.type,
    required this.title,
    this.expiresAt,
    this.notes,
  });

  final String id;
  final String type;
  final String title;
  final DateTime? expiresAt;
  final String? notes;

  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory MyDocument.fromJson(Map<String, dynamic> j) => MyDocument(
        id: str(j['id']) ?? '',
        type: str(j['type']) ?? 'OTHER',
        title: str(j['title']) ?? '',
        expiresAt: dateOf(j['expiresAt']),
        notes: str(j['notes']),
      );
}

class StripeStatus {
  const StripeStatus({
    required this.connected,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
  });

  final bool connected;
  final bool payoutsEnabled;
  final bool detailsSubmitted;

  factory StripeStatus.fromJson(Map<String, dynamic> j) => StripeStatus(
        connected: boolOf(j['connected']),
        payoutsEnabled: boolOf(j['payoutsEnabled']),
        detailsSubmitted: boolOf(j['detailsSubmitted']),
      );
}

// ── Repository ─────────────────────────────────────────────────────────

class MeRepository {
  MeRepository(this._api);

  final ApiClient _api;

  Future<CleanerProfile> updatePhone(String phone) async =>
      CleanerProfile.fromJson(mapOf(await _api.put('/cleaners/me', body: {'phone': phone})));

  Future<CleanerProfile> uploadAvatar(Uint8List bytes, String contentType) async {
    final signed = mapOf(await _api.post(
      '/cleaners/me/avatar-upload-url',
      body: {'contentType': contentType, 'filename': 'avatar.jpg'},
    ));
    final uploadUrl = str(signed['uploadUrl']);
    final avatarKey = str(signed['avatarKey']);
    if (uploadUrl == null || avatarKey == null) {
      throw ApiException('Unexpected response from the server');
    }
    await _api.putBytes(uploadUrl, bytes, contentType);
    return CleanerProfile.fromJson(
      mapOf(await _api.put('/cleaners/me', body: {'avatarKey': avatarKey})),
    );
  }

  // Availability
  Future<List<AvailabilitySlot>> availability() async =>
      mapsOf(await _api.get('/cleaners/me/availability')).map(AvailabilitySlot.fromJson).toList();

  Future<void> saveAvailability(List<AvailabilitySlot> slots) => _api.put(
        '/cleaners/me/availability',
        body: {'slots': slots.map((s) => s.toJson()).toList()},
      );

  // Leave
  Future<List<Leave>> leave() async =>
      mapsOf(await _api.get('/cleaners/me/leave')).map(Leave.fromJson).toList();

  Future<void> requestLeave({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) =>
      _api.post('/cleaners/me/leave', body: {
        'type': type.api,
        'startDate': Fmt.apiDate(start),
        'endDate': Fmt.apiDate(end),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<void> withdrawLeave(String id) => _api.delete('/cleaners/me/leave/$id');

  // Documents
  Future<List<MyDocument>> documents() async =>
      mapsOf(await _api.get('/cleaners/me/documents')).map(MyDocument.fromJson).toList();

  Future<void> uploadDocument({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    required String title,
    required String type,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final signed = mapOf(await _api.post(
      '/cleaners/me/documents/upload-url',
      body: {'contentType': contentType, 'filename': filename},
    ));
    final uploadUrl = str(signed['uploadUrl']);
    final storageKey = str(signed['storageKey']);
    if (uploadUrl == null || storageKey == null) {
      throw ApiException('Unexpected response from the server');
    }
    await _api.putBytes(uploadUrl, bytes, contentType);
    await _api.post('/cleaners/me/documents', body: {
      'title': title,
      'type': type,
      'storageKey': storageKey,
      'mimeType': contentType,
      'fileSize': bytes.length,
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  Future<String> documentUrl(String id) async {
    final data = mapOf(await _api.get('/cleaners/me/documents/$id/download-url'));
    final url = str(data['downloadUrl']);
    if (url == null) throw ApiException('Unexpected response from the server');
    return url;
  }

  // Stripe
  Future<StripeStatus> stripeStatus() async =>
      StripeStatus.fromJson(mapOf(await _api.get('/cleaners/me/stripe/status')));

  Future<String> stripeOnboardingUrl() async {
    final data = mapOf(await _api.post('/cleaners/me/stripe/onboarding-link', body: {
      'returnUrl': AppConfig.stripeReturnUrl,
      'refreshUrl': AppConfig.stripeReturnUrl,
    }));
    final url = str(data['url']);
    if (url == null) throw ApiException('Unexpected response from the server');
    return url;
  }
}

final meRepositoryProvider =
    Provider<MeRepository>((ref) => MeRepository(ref.watch(apiClientProvider)));

final availabilityProvider = FutureProvider.autoDispose<List<AvailabilitySlot>>(
  (ref) => ref.watch(meRepositoryProvider).availability(),
);

final leaveProvider = FutureProvider.autoDispose<List<Leave>>(
  (ref) => ref.watch(meRepositoryProvider).leave(),
);

final documentsProvider = FutureProvider.autoDispose<List<MyDocument>>(
  (ref) => ref.watch(meRepositoryProvider).documents(),
);

final stripeStatusProvider = FutureProvider.autoDispose<StripeStatus>(
  (ref) => ref.watch(meRepositoryProvider).stripeStatus(),
);
