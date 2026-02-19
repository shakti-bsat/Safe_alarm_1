import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus { active, confirmed, escalated, cancelled }

class TripContact {
  final String name;
  final String phone;
  final String email;

  TripContact({required this.name, required this.phone, this.email = ''});

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
      };

  factory TripContact.fromMap(Map<String, dynamic> map) => TripContact(
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
      );
}

class TripSession {
  final String id;
  final DateTime startTime;
  final DateTime eta;
  final List<TripContact> contacts;
  TripStatus status;
  double? lastLatitude;
  double? lastLongitude;
  int snoozeCount;
  DateTime? lastSnoozeTime;
  int currentSnoozeMinutes;

  TripSession({
    required this.id,
    required this.startTime,
    required this.eta,
    required this.contacts,
    this.status = TripStatus.active,
    this.lastLatitude,
    this.lastLongitude,
    this.snoozeCount = 0,
    this.lastSnoozeTime,
    this.currentSnoozeMinutes = 5,
  });

  // Progressive snooze windows: 5 → 3 → 2 → auto-escalate
  static const List<int> snoozeWindows = [5, 3, 2];

  bool get canSnooze => snoozeCount < snoozeWindows.length;

  int get nextSnoozeMinutes {
    if (snoozeCount < snoozeWindows.length) {
      return snoozeWindows[snoozeCount];
    }
    return 0;
  }

  DateTime? get currentDeadline {
    if (lastSnoozeTime == null) return eta;
    return lastSnoozeTime!.add(Duration(minutes: currentSnoozeMinutes));
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'startTime': Timestamp.fromDate(startTime),
        'eta': Timestamp.fromDate(eta),
        'contacts': contacts.map((c) => c.toMap()).toList(),
        'status': status.name,
        'lastLatitude': lastLatitude,
        'lastLongitude': lastLongitude,
        'snoozeCount': snoozeCount,
        'lastSnoozeTime':
            lastSnoozeTime != null ? Timestamp.fromDate(lastSnoozeTime!) : null,
        'currentSnoozeMinutes': currentSnoozeMinutes,
      };

  factory TripSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripSession(
      id: data['id'] ?? doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      eta: (data['eta'] as Timestamp).toDate(),
      contacts: (data['contacts'] as List<dynamic>? ?? [])
          .map((c) => TripContact.fromMap(c as Map<String, dynamic>))
          .toList(),
      status: TripStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TripStatus.active,
      ),
      lastLatitude: data['lastLatitude']?.toDouble(),
      lastLongitude: data['lastLongitude']?.toDouble(),
      snoozeCount: data['snoozeCount'] ?? 0,
      lastSnoozeTime: data['lastSnoozeTime'] != null
          ? (data['lastSnoozeTime'] as Timestamp).toDate()
          : null,
      currentSnoozeMinutes: data['currentSnoozeMinutes'] ?? 5,
    );
  }
}
