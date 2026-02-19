import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import 'trip_setup_screen.dart';
import 'active_trip_screen.dart';
import 'confirmation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TripService _tripService = TripService();
  List<TripContact> _savedContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _listenToTripChanges();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString('contacts') ?? '[]';
    final List decoded = jsonDecode(contactsJson);
    setState(() {
      _savedContacts = decoded
          .map((c) => TripContact.fromMap(c as Map<String, dynamic>))
          .toList();
    });
  }

  void _listenToTripChanges() {
    _tripService.sessionStream.listen((session) {
      if (!mounted) return;
      if (session != null && session.status == TripStatus.active) {
        // Check if ETA has lapsed
        if (_tripService.isEtaLapsed) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ConfirmationScreen()),
            (r) => false,
          );
        }
      } else if (session != null && session.status == TripStatus.escalated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EscalationScreen()),
          (r) => false,
        );
      }
    });
  }

  void _startTrip() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripSetupScreen(savedContacts: _savedContacts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<TripSession?>(
                stream: _tripService.sessionStream,
                initialData: _tripService.activeSession,
                builder: (context, snapshot) {
                  final session = snapshot.data;
                  if (session != null && session.status == TripStatus.active) {
                    return ActiveTripScreen(session: session);
                  }
                  return _buildIdleContent();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, size: 20, color: Color(0xFF6B4EFF)),
          ),
          const SizedBox(width: 12),
          const Text(
            'SafeAlarm',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: Colors.white.withOpacity(0.5)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildIdleContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Status indicator
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.03),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 8),
                Text(
                  'No active trip',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Stay Safe Tonight',
            style: TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Start monitoring before your commute.\nWe\'ll alert your contacts if you don\'t arrive.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          // Quick stats
          if (_savedContacts.isNotEmpty)
            _ContactsPreview(contacts: _savedContacts),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _startTrip,
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4EFF), Color(0xFF9B6BFF)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4EFF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Start Trip Monitoring',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ContactsPreview extends StatelessWidget {
  final List<TripContact> contacts;
  const _ContactsPreview({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, color: Color(0xFF6B4EFF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${contacts.length} trusted contact${contacts.length == 1 ? '' : 's'} ready',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            contacts.map((c) => c.name.split(' ')[0]).join(', '),
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
