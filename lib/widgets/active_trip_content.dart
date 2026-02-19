import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import 'package:safealarm/screens/active_trip_screen.dart';

class ActiveTripContent extends StatelessWidget {
  final TripSession session;
  const ActiveTripContent({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActiveTripScreen(session: session),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF30D158),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('MONITORING ACTIVE',
                          style: TextStyle(
                              color: Color(0xFF30D158),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.shield, color: Color(0xFF6B4EFF), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to view trip details',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
