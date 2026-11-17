import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/json.dart';
import '../../core/location_service.dart';
import '../../core/providers.dart';
import 'job_models.dart';

class JobsRepository {
  JobsRepository(this._api);

  final ApiClient _api;

  Future<List<Job>> list({DateTime? from, DateTime? to}) async {
    final data = await _api.get('/cleaner/bookings/my', query: {
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return mapsOf(data).map(Job.fromJson).toList();
  }

  Future<Job> get(String id) async =>
      Job.fromJson(mapOf(await _api.get('/cleaner/bookings/$id')));

  Future<void> onMyWay(String id) =>
      _api.post('/cleaner/bookings/$id/on-my-way');

  /// Checks in and starts the job (same call the web cleaner app uses).
  Future<void> checkInAndStart(String id, LatLng? at) => _api.post(
        '/cleaner/bookings/$id/start',
        body: {if (at != null) 'lat': at.lat, if (at != null) 'lng': at.lng},
      );

  Future<void> complete(String id, {LatLng? at, String? notes}) => _api.post(
        '/cleaner/bookings/$id/complete',
        body: {
          if (at != null) 'lat': at.lat,
          if (at != null) 'lng': at.lng,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );

  Future<void> setChecklistItem(String bookingId, String itemId, bool done) =>
      _api.post('/checklists/$bookingId/items/$itemId/complete', body: {'done': done});

  /// Three steps: ask for a presigned URL, upload the bytes straight to
  /// storage, then register the photo on the booking.
  Future<void> uploadPhoto({
    required String bookingId,
    required String stage,
    required Uint8List bytes,
    required String contentType,
    required String filename,
  }) async {
    final signed = mapOf(await _api.post(
      '/cleaner/bookings/$bookingId/photos/upload-url',
      body: {'stage': stage, 'contentType': contentType, 'filename': filename},
    ));
    final uploadUrl = str(signed['uploadUrl']);
    final storageKey = str(signed['storageKey']);
    if (uploadUrl == null || storageKey == null) {
      throw ApiException('Unexpected response from the server');
    }
    await _api.putBytes(uploadUrl, bytes, contentType);
    await _api.post(
      '/cleaner/bookings/$bookingId/photos',
      body: {'stage': stage, 'storageKey': storageKey},
    );
  }

  Future<ChatThread> messages(String bookingId, {String? after}) async {
    final data = await _api.get(
      '/cleaner/bookings/$bookingId/messages',
      query: {if (after != null) 'after': after},
    );
    return ChatThread.fromJson(mapOf(data));
  }

  Future<void> sendMessage(String bookingId, String body) =>
      _api.post('/cleaner/bookings/$bookingId/messages', body: {'body': body});

  /// Live position for the dispatch map. Failures are ignored by callers.
  Future<void> pingLocation(LatLng at) => _api.post(
        '/cleaners/me/location',
        body: {'latitude': at.lat, 'longitude': at.lng},
      );
}

final jobsRepositoryProvider =
    Provider<JobsRepository>((ref) => JobsRepository(ref.watch(apiClientProvider)));
