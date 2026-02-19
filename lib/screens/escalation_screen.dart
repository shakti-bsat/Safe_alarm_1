import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import '../services/alert_service.dart';
import 'home_screen.dart';

class EscalationScreen extends StatefulWidget {
  const EscalationScreen({super.key});

  @override
  State<EscalationScreen> createState() => _EscalationScreenState();
}

class _EscalationScreenState extends State<EscalationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  List<Map<String, dynamic>> _alerts = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _loadAlerts();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadAlerts());
  }

  Future<void> _loadAlerts() async {
    final session = TripService().activeSession;
    if (session == null) return;
    final alerts = await AlertService().getAlertHistory(session.id);
    if (mounted) setState(() => _alerts = alerts);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _callEmergencyServices() async {
    final uri = Uri.parse('tel:911');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openLocation() async {
    final session = TripService().activeSession;
    if (session?.lastLatitude != null) {
      final uri = Uri.parse(
          'https://maps.google.com/?q=${session!.lastLatitude},${session.lastLongitude}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = TripService().activeSession;

    return Scaffold(
      backgroundColor: const Color(0xFF150000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Alert header
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 90 + _pulseController.value * 10,
                    height: 90 + _pulseController.value * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF3B30)
                          .withOpacity(0.1 + _pulseController.value * 0.1),
                    ),
                    child: child,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 44, color: Color(0xFFFF3B30)),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Emergency Alert Sent',
                  style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your trusted contacts have been notified\nwith your location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15,
                      height: 1.4),
                ),
              ),
              const SizedBox(height: 32),
              // Alert status
              if (_alerts.isNotEmpty) ...[
                Text('Alert Status',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 8),
                ..._alerts.map((a) => _AlertTile(alert: a)),
                const SizedBox(height: 24),
              ],

              // Location info
              if (session?.lastLatitude != null)
                GestureDetector(
                  onTap: _openLocation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF6B4EFF)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Last Known Location',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                '${session!.lastLatitude!.toStringAsFixed(5)}, ${session.lastLongitude!.toStringAsFixed(5)}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new,
                            color: Colors.white.withOpacity(0.3),
                            size: 18),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Emergency call button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _callEmergencyServices,
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text('Call Emergency Services (911)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // I'm safe now
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    await TripService().confirmSafeArrival();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (r) => false,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF30D158)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('I\'m Safe Now — Cancel Alert',
                      style: TextStyle(
                          color: Color(0xFF30D158),
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final acknowledged = alert['acknowledged'] ?? false;
    final tier = alert['tier'] ?? 'Tier 1';
    final name = alert['contactName'] ?? 'Contact';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: acknowledged
              ? const Color(0xFF30D158).withOpacity(0.3)
              : const Color(0xFFFF9500).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            acknowledged ? Icons.check_circle : Icons.pending,
            color: acknowledged
                ? const Color(0xFF30D158)
                : const Color(0xFFFF9500),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                Text(
                  acknowledged ? 'Acknowledged ✓' : 'Awaiting response...',
                  style: TextStyle(
                    color: acknowledged
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF9500),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tier,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
