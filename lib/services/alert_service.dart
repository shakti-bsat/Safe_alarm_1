import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/trip_session.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Replace with your Twilio credentials or Firebase Function URL
  static const String _twilioAccountSid = 'YOUR_TWILIO_ACCOUNT_SID';
  static const String _twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
  static const String _twilioFromNumber = 'YOUR_TWILIO_PHONE_NUMBER';

  // Firebase Cloud Function URL (set after deploying functions)
  static const String _functionBaseUrl =
      'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net';

  Future<void> sendEmergencyAlerts({required TripSession session}) async {
    final alertId = const Uuid().v4();
    final mapsLink = session.lastLatitude != null
        ? 'https://maps.google.com/?q=${session.lastLatitude},${session.lastLongitude}'
        : 'Location unavailable';

    final ackBaseUrl = '$_functionBaseUrl/acknowledgeAlert';

    for (int i = 0; i < session.contacts.length; i++) {
      final contact = session.contacts[i];
      final tier = i == 0 ? 'Tier 1' : 'Tier 2';
      final contactAlertId = '${alertId}_$i';

      // Store alert in Firestore for acknowledgment tracking
      await _db.collection('alerts').doc(contactAlertId).set({
        'tripId': session.id,
        'contactName': contact.name,
        'contactPhone': contact.phone,
        'tier': tier,
        'sentAt': Timestamp.now(),
        'acknowledged': false,
        'acknowledgedAt': null,
        'locationLink': mapsLink,
      });

      final ackLink = '$ackBaseUrl?alertId=$contactAlertId';
      final message = _buildAlertMessage(
        contactName: contact.name,
        tier: tier,
        mapsLink: mapsLink,
        ackLink: ackLink,
        session: session,
      );

      // Send SMS via Twilio
      await _sendSms(phone: contact.phone, message: message);

      // If Tier 1 not acknowledged after 3 min, auto-escalate to Tier 2
      if (i == 0 && session.contacts.length > 1) {
        _scheduleEscalationCheck(
          alertId: contactAlertId,
          session: session,
          ackLink: ackLink,
          mapsLink: mapsLink,
        );
      }
    }
  }

  String _buildAlertMessage({
    required String contactName,
    required String tier,
    required String mapsLink,
    required String ackLink,
    required TripSession session,
  }) {
    final etaStr = _formatTime(session.eta);
    return '''🚨 SAFEALARM ALERT [$tier]

Hi $contactName, this is an automated safety alert.

A person you're monitoring did NOT confirm safe arrival by $etaStr.

📍 Last known location: $mapsLink

⚠️ Please check on them immediately.

✅ Tap to acknowledge this alert:
$ackLink

If you cannot reach them, please contact emergency services.

— SafeAlarm System''';
  }

  Future<void> _sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      // Try via Firebase Cloud Function first (recommended)
      final response = await http.post(
        Uri.parse('$_functionBaseUrl/sendSmsAlert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'message': message}),
      );

      if (response.statusCode != 200) {
        // Fallback: direct Twilio API call
        await _sendTwilioDirectly(phone: phone, message: message);
      }
    } catch (e) {
      // Fallback to direct Twilio
      await _sendTwilioDirectly(phone: phone, message: message);
    }
  }

  Future<void> _sendTwilioDirectly({
    required String phone,
    required String message,
  }) async {
    final credentials = base64Encode(
        utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));
    await http.post(
      Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'From': _twilioFromNumber,
        'To': phone,
        'Body': message,
      },
    );
  }

  void _scheduleEscalationCheck({
    required String alertId,
    required TripSession session,
    required String ackLink,
    required String mapsLink,
  }) {
    Future.delayed(const Duration(minutes: 3), () async {
      final doc = await _db.collection('alerts').doc(alertId).get();
      if (doc.exists && !(doc.data()?['acknowledged'] ?? false)) {
        // Tier 1 did NOT acknowledge — escalate to Tier 2
        if (session.contacts.length > 1) {
          final tier2Contact = session.contacts[1];
          final t2AlertId = '${alertId}_t2_escalated';
          await _db.collection('alerts').doc(t2AlertId).set({
            'tripId': session.id,
            'contactName': tier2Contact.name,
            'contactPhone': tier2Contact.phone,
            'tier': 'Tier 2 (Escalated)',
            'sentAt': Timestamp.now(),
            'acknowledged': false,
            'acknowledgedAt': null,
            'escalatedFromAlert': alertId,
          });

          final message = '''🚨 ESCALATED SAFETY ALERT [Tier 2]

Tier 1 contact did not respond. Escalating to you.

A person you're monitoring did NOT confirm safe arrival.

📍 Last known location: $mapsLink

⚠️ Please check on them IMMEDIATELY and contact emergency services if needed.

✅ Acknowledge: $ackLink

— SafeAlarm System''';

          await _sendSms(phone: tier2Contact.phone, message: message);
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAlertHistory(String tripId) async {
    final snapshot = await _db
        .collection('alerts')
        .where('tripId', isEqualTo: tripId)
        .orderBy('sentAt', descending: false)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
