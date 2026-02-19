import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ⚠️ SECURITY WARNING:
// These credentials are stored in the app binary.
// This is acceptable for development/MVP but should be moved
// to a backend server before public release.
// Minimum protection: Enable Twilio's "Geo Permissions" and
// "Allowed phone numbers" in your Twilio Console to limit abuse.

class TwilioConfig {
  static const String accountSid = 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  static const String authToken = 'your_auth_token_here';
  static const String fromPhone = '+12194913xxxx';
}

/// Result model for SOS operations
class SOSResult {
  final bool success;
  final String? sid;
  final String? error;

  const SOSResult({required this.success, this.sid, this.error});

  @override
  String toString() =>
      success ? 'SOSResult(success, sid: $sid)' : 'SOSResult(failed: $error)';
}

class TwilioSOSService {
  // Singleton
  TwilioSOSService._();
  static final TwilioSOSService instance = TwilioSOSService._();

  final String _baseUrl =
      'https://api.twilio.com/2010-04-01/Accounts/${TwilioConfig.accountSid}/Messages.json';

  // Basic Auth header
  String get _authHeader {
    final credentials = '${TwilioConfig.accountSid}:${TwilioConfig.authToken}';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  // ── Single Contact SOS ──────────────────────────────────────────────────

  Future<SOSResult> sendSOS({
    required String toPhone,
    required String message,
    bool attachLocation = true,
  }) async {
    try {
      Map<String, dynamic>? locationData;
      if (attachLocation) {
        locationData = await _getCurrentLocation();
      }

      final cleanTo = _formatPhone(toPhone);
      final body = _buildMessage(message, locationData);

      return await _sendSMS(to: cleanTo, body: body);
    } catch (e) {
      return SOSResult(success: false, error: e.toString());
    }
  }

  // ── Batch SOS (Multiple Emergency Contacts) ─────────────────────────────

  Future<List<Map<String, dynamic>>> sendBatchSOS({
    required List<String> contacts,
    required String message,
    bool attachLocation = true,
  }) async {
    // Get location once, reuse for all contacts
    Map<String, dynamic>? locationData;
    if (attachLocation) {
      locationData = await _getCurrentLocation();
    }

    final body = _buildMessage(message, locationData);

    final results = await Future.wait(
      contacts.map((phone) async {
        final cleanTo = _formatPhone(phone);
        final result = await _sendSMS(to: cleanTo, body: body);
        return {
          'phone': cleanTo,
          'success': result.success,
          'error': result.error,
        };
      }),
    );

    return results;
  }

  // ── Core SMS Sender ─────────────────────────────────────────────────────

  Future<SOSResult> _sendSMS({
    required String to,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': _authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': to,
          'From': TwilioConfig.fromPhone,
          'Body': body,
        },
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return SOSResult(success: true, sid: json['sid']);
      } else {
        return SOSResult(
          success: false,
          error: json['message'] ?? 'Unknown Twilio error',
        );
      }
    } catch (e) {
      return SOSResult(success: false, error: e.toString());
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!clean.startsWith('+')) {
      clean = clean.length == 10 ? '+91$clean' : '+$clean';
    }
    return clean;
  }

  String _buildMessage(String message, Map<String, dynamic>? location) {
    String body = message;
    if (location != null) {
      body +=
          '\n\n📍 Location: https://maps.google.com/?q=${location['latitude']},${location['longitude']}';
    }
    final time = DateTime.now().toLocal().toString().substring(0, 16);
    body += '\n\nSent via SafeAlarm at $time';
    return body;
  }

  Future<Map<String, dynamic>?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (_) {
      // Location failure must NEVER block an SOS
      return null;
    }
  }
}
