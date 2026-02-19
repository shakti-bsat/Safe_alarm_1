import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import 'escalation_screen.dart';
import 'home_screen.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen>
    with TickerProviderStateMixin {
  final TripService _tripService = TripService();
  Timer? _autoEscalateTimer;
  Timer? _countdownTimer;
  int _autoEscalateSeconds = 30;
  int _remaining = 30;
  late AnimationController _shakeController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _startAutoEscalateTimer();
  }

  void _startAutoEscalateTimer() {
    final session = _tripService.activeSession;
    // If no more snoozes, countdown is shorter and leads to emergency
    _remaining = _autoEscalateSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _autoEscalate();
      }
    });
  }

  Future<void> _autoEscalate() async {
    if (!mounted) return;
    final session = _tripService.activeSession;
    if (session != null && !session.canSnooze) {
      // No more snoozes — emergency
      await _tripService.triggerEmergency();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EscalationScreen()),
        );
      }
    } else {
      // Auto-snooze once silently
      await _tripService.snooze();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _onConfirm() async {
    _countdownTimer?.cancel();
    await _tripService.confirmSafeArrival();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (r) => false,
      );
    }
  }

  Future<void> _onSnooze() async {
    _countdownTimer?.cancel();
    final session = _tripService.activeSession;
    if (session == null || !session.canSnooze) {
      // No more snoozes — trigger emergency
      await _onEmergency();
      return;
    }
    final minutes = session.nextSnoozeMinutes;
    await _tripService.snooze();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OK, checking again in $minutes minutes'),
          backgroundColor: const Color(0xFF1A1A2E),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _onEmergency() async {
    _countdownTimer?.cancel();
    await _tripService.triggerEmergency();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EscalationScreen()),
      );
    }
  }

  @override
  void dispose() {
    _autoEscalateTimer?.cancel();
    _countdownTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _tripService.activeSession;
    final snoozeLeft = session != null
        ? TripSession.snoozeWindows.length - session.snoozeCount
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Pulsing alert icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 100 + _pulseController.value * 8,
                    height: 100 + _pulseController.value * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          const Color(0xFFFF9500).withOpacity(0.1 + _pulseController.value * 0.05),
                    ),
                    child: child,
                  );
                },
                child: const Icon(Icons.access_time,
                    size: 48, color: Color(0xFFFF9500)),
              ),
              const SizedBox(height: 32),
              const Text(
                'Are you safe?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your ETA has passed. Please confirm you arrived safely.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 16,
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Countdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.3)),
                ),
                child: Text(
                  'Auto-escalating in $_remaining seconds',
                  style: const TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              if (snoozeLeft > 0 && snoozeLeft < 3) ...[
                const SizedBox(height: 8),
                Text(
                  '$snoozeLeft snooze${snoozeLeft == 1 ? '' : 's'} remaining',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13),
                ),
              ],
              const Spacer(),
              // Main buttons
              // ON - Safe arrival
              GestureDetector(
                onTap: _onConfirm,
                child: Container(
                  width: double.infinity,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF30D158),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF30D158).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('I\'M SAFE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('Confirm safe arrival',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Snooze
              GestureDetector(
                onTap: snoozeLeft > 0 ? _onSnooze : null,
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    color: snoozeLeft > 0
                        ? const Color(0xFF1A1A2E)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: snoozeLeft > 0
                          ? const Color(0xFF6B4EFF).withOpacity(0.4)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.snooze,
                          color: snoozeLeft > 0
                              ? const Color(0xFF6B4EFF)
                              : Colors.white.withOpacity(0.2),
                          size: 24),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snoozeLeft > 0
                                ? 'SNOOZE (+${session?.nextSnoozeMinutes ?? 0} min)'
                                : 'NO MORE SNOOZES',
                            style: TextStyle(
                              color: snoozeLeft > 0
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            snoozeLeft > 0
                                ? 'I\'m delayed but safe'
                                : 'Emergency will be triggered',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // OFF - Emergency
              GestureDetector(
                onTap: _onEmergency,
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFFF3B30), size: 24),
                      SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EMERGENCY',
                              style: TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text('Alert my contacts now',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
