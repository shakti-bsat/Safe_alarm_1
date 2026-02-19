import '../services/twilio_sos_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import 'confirmation_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final TripSession session;
  const ActiveTripScreen({super.key, required this.session});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });

    // Listen for escalation events
    TripService().sessionStream.listen((session) {
      if (!mounted) return;
      if (session == null || session.status == TripStatus.confirmed) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else if (session.status == TripStatus.escalated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EscalationScreen()),
        );
      }
    });
  }

  void _updateRemaining() {
    final eta = widget.session.eta;
    final now = DateTime.now();
    if (now.isAfter(eta)) {
      setState(() => _remaining = Duration.zero);
      _timer?.cancel();
      // Navigate to confirmation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ConfirmationScreen()),
        );
      }
    } else {
      setState(() => _remaining = eta.difference(now));
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final totalSeconds = widget.session.eta
        .difference(widget.session.startTime)
        .inSeconds
        .toDouble();
    if (totalSeconds <= 0) return 1;
    final elapsed = DateTime.now()
        .difference(widget.session.startTime)
        .inSeconds
        .toDouble();
    return (elapsed / totalSeconds).clamp(0, 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eta = widget.session.eta;
    final h = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final m = eta.minute.toString().padLeft(2, '0');
    final period = eta.hour < 12 ? 'AM' : 'PM';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF30D158),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Monitoring Active',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _showCancelDialog(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // Countdown circle
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = 1.0 + _pulseController.value * 0.03;
                return Transform.scale(
                  scale: pulse,
                  child: child,
                );
              },
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 4,
                        backgroundColor:
                            const Color(0xFF6B4EFF).withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6B4EFF)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield,
                            color: Color(0xFF6B4EFF), size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_remaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'until check-in',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'ETA: $h:$m $period',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm arrival when you get home',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
            ),
            const Spacer(),
            // Contacts being monitored
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Will alert if you don\'t check in:',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  ...widget.session.contacts.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  const Color(0xFF6B4EFF).withOpacity(0.15),
                              child: Text(
                                e.value.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF6B4EFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(e.value.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                            const Spacer(),
                            Text(
                              e.key == 0 ? 'Tier 1' : 'Tier 2',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
// SOS Button
            GestureDetector(
              onLongPress: () async {
                final contacts =
                    widget.session.contacts.map((c) => c.phone).toList();

                final results = await TwilioSOSService.instance.sendBatchSOS(
                  contacts: contacts,
                  message: '🚨 I need help! This is an emergency.',
                  attachLocation: true,
                );

                if (!mounted) return;
                final successCount =
                    results.where((r) => r['success'] == true).length;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      successCount == contacts.length
                          ? '✅ SOS sent to all ${contacts.length} contact(s)!'
                          : '⚠️ SOS sent to $successCount/${contacts.length} contact(s).',
                    ),
                    backgroundColor:
                        successCount > 0 ? Colors.green : Colors.red,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'HOLD FOR SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
// Manual safe arrival button
            const SizedBox(height: 16),
            // Manual safe arrival button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => TripService().confirmSafeArrival(),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('I\'m Home Safe',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF30D158),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Cancel monitoring?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Your contacts won\'t be notified if you cancel.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Active',
                style: TextStyle(color: Color(0xFF6B4EFF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              TripService().cancelTrip();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Cancel Trip',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// Needed for escalation navigation from this file
class EscalationScreen extends StatelessWidget {
  const EscalationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A1A),
      body: Center(
          child: Text('Loading...', style: TextStyle(color: Colors.white))),
    );
  }
}
