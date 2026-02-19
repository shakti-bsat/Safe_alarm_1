import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6B4EFF);
  static const primaryLight = Color(0xFF9B6BFF);
  static const background = Color(0xFF0A0A1A);
  static const surface = Color(0xFF1A1A2E);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF888888);
}

class AppStrings {
  static const appName = 'SafeAlarm';
  static const tagline = 'Arrive Safe. Every Time.';

  // Confirmation screen
  static const areYouSafe = 'Are you safe?';
  static const imSafe = "I'M SAFE";
  static const snooze = 'SNOOZE';
  static const emergency = 'EMERGENCY';

  // Escalation
  static const alertSent = 'Emergency Alert Sent';
  static const callEmergency = 'Call Emergency Services (911)';
  static const imSafeNow = "I'm Safe Now — Cancel Alert";
}

class AppDurations {
  static const snoozeWindows = [5, 3, 2]; // minutes
  static const autoEscalateSeconds = 30;
  static const locationUpdateInterval = Duration(seconds: 30);
  static const tier1AckTimeout = Duration(minutes: 3);
}
