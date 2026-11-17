import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config.dart';
import '../../core/location_service.dart';
import '../../core/providers.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

/// Sends the cleaner's position to dispatch while a job is in progress.
///
/// It keeps running when the app is in the background: on Android through a
/// foreground-service notification, on iOS through background location
/// updates. It stops by itself once the job is no longer in progress (for
/// example it was completed from another device), and when asked to.
class LiveLocation extends Notifier<String?> {
  StreamSubscription<Position>? _sub;
  Timer? _check;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// The id of the job being tracked, or null.
  @override
  String? build() {
    ref.onDispose(_teardown);
    return null;
  }

  Future<void> start(String jobId) async {
    if (state == jobId) return;
    await stop();

    // Ask for permission the usual way first; no permission, no tracking.
    final first = await ref.read(locationServiceProvider).currentPosition();
    if (first == null) return;
    state = jobId;
    unawaited(_send(first));

    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
        intervalDuration: AppConfig.locationPingInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Tod Cleaning',
          notificationText: 'Sharing your location while you work',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 30);
    }

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        // At most one ping per interval, however often the phone reports.
        if (DateTime.now().difference(_lastSent) >= AppConfig.locationPingInterval) {
          _send(p);
        }
      },
      onError: (_) {},
    );

    // Every few minutes make sure the job is still in progress.
    _check = Timer.periodic(const Duration(minutes: 5), (_) => _stillWorking());
  }

  Future<void> _send(Position p) async {
    _lastSent = DateTime.now();
    try {
      await ref.read(jobsRepositoryProvider).pingLocation((lat: p.latitude, lng: p.longitude));
    } catch (_) {
      // Pings are best effort.
    }
  }

  Future<void> _stillWorking() async {
    final id = state;
    if (id == null) return;
    try {
      final job = await ref.read(jobsRepositoryProvider).get(id);
      if (job.phase != JobPhase.working) await stop();
    } catch (_) {
      // Offline: keep going, try again at the next check.
    }
  }

  Future<void> stop() async {
    _teardown();
    state = null;
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _check?.cancel();
    _check = null;
  }
}

final liveLocationProvider = NotifierProvider<LiveLocation, String?>(LiveLocation.new);
