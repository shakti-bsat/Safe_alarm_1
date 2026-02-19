import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_session.dart';
import 'alert_service.dart';
import 'notification_service.dart';

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AlertService _alertService = AlertService();

  TripSession? _activeSession;
  Timer? _etaTimer;
  Timer? _locationTimer;
  final StreamController<TripSession?> _sessionController =
      StreamController<TripSession?>.broadcast();

  Stream<TripSession?> get sessionStream => _sessionController.stream;
  TripSession? get activeSession => _activeSession;

  Future<TripSession> startTrip({
    required DateTime eta,
    required List<TripContact> contacts,
  }) async {
    final id = const Uuid().v4();
    final session = TripSession(
      id: id,
      startTime: DateTime.now(),
      eta: eta,
      contacts: contacts,
    );

    _activeSession = session;

    // Save to Firestore
    await _db.collection('trips').doc(id).set(session.toFirestore());

    // Start location tracking
    _startLocationTracking();

    // Schedule ETA check
    _scheduleEtaCheck(eta);

    _sessionController.add(_activeSession);

    // Show persistent notification
    await NotificationService.showTripActiveNotification(eta);

    return session;
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    if (_activeSession == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _activeSession!.lastLatitude = position.latitude;
      _activeSession!.lastLongitude = position.longitude;
      await _db.collection('trips').doc(_activeSession!.id).update({
        'lastLatitude': position.latitude,
        'lastLongitude': position.longitude,
      });
    } catch (e) {
      // Use last known position
    }
  }

  void _scheduleEtaCheck(DateTime eta) {
    _etaTimer?.cancel();
    final delay = eta.difference(DateTime.now());
    if (delay.isNegative) {
      _onEtaLapsed();
    } else {
      _etaTimer = Timer(delay, _onEtaLapsed);
    }
  }

  Future<void> _onEtaLapsed() async {
    if (_activeSession == null || _activeSession!.status != TripStatus.active) {
      return;
    }
    await NotificationService.showConfirmationRequired();
    _sessionController.add(_activeSession);
  }

  Future<void> confirmSafeArrival() async {
    if (_activeSession == null) return;
    _activeSession!.status = TripStatus.confirmed;
    await _db.collection('trips').doc(_activeSession!.id).update({
      'status': 'confirmed',
      'confirmedAt': Timestamp.now(),
    });
    await NotificationService.cancelAll();
    _cleanup();
    _sessionController.add(null);
  }

  Future<void> snooze() async {
    if (_activeSession == null) return;
    if (!_activeSession!.canSnooze) {
      // No more snoozes - escalate
      await triggerEmergency();
      return;
    }

    final snoozeMinutes =
        TripSession.snoozeWindows[_activeSession!.snoozeCount];
    _activeSession!.lastSnoozeTime = DateTime.now();
    _activeSession!.currentSnoozeMinutes = snoozeMinutes;
    _activeSession!.snoozeCount++;

    await _db.collection('trips').doc(_activeSession!.id).update({
      'snoozeCount': _activeSession!.snoozeCount,
      'lastSnoozeTime': Timestamp.now(),
      'currentSnoozeMinutes': snoozeMinutes,
    });

    // Schedule next check
    final nextDeadline = DateTime.now().add(Duration(minutes: snoozeMinutes));
    _scheduleEtaCheck(nextDeadline);

    await NotificationService.showSnoozeNotification(
        snoozeMinutes, _activeSession!.snoozeCount);
    _sessionController.add(_activeSession);
  }

  Future<void> triggerEmergency() async {
    if (_activeSession == null) return;

    // Update location one more time
    await _updateLocation();

    _activeSession!.status = TripStatus.escalated;

    await _db.collection('trips').doc(_activeSession!.id).update({
      'status': 'escalated',
      'escalatedAt': Timestamp.now(),
    });

    // Send alerts to all contacts
    await _alertService.sendEmergencyAlerts(
      session: _activeSession!,
    );

    await NotificationService.showEscalationNotification();
    _sessionController.add(_activeSession);
  }

  Future<void> cancelTrip() async {
    if (_activeSession == null) return;
    _activeSession!.status = TripStatus.cancelled;
    await _db.collection('trips').doc(_activeSession!.id).update({
      'status': 'cancelled',
    });
    await NotificationService.cancelAll();
    _cleanup();
    _sessionController.add(null);
  }

  void _cleanup() {
    _etaTimer?.cancel();
    _locationTimer?.cancel();
    _activeSession = null;
  }

  bool get isTripActive => _activeSession != null;
  bool get isEtaLapsed {
    if (_activeSession == null) return false;
    final deadline = _activeSession!.currentDeadline;
    return deadline != null && DateTime.now().isAfter(deadline);
  }
}
