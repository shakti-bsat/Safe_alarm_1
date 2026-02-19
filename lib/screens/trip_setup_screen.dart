import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trip_session.dart';
import '../services/trip_service.dart';
import '../services/location_service.dart';
import 'active_trip_screen.dart';

class TripSetupScreen extends StatefulWidget {
  final List<TripContact> savedContacts;
  const TripSetupScreen({super.key, required this.savedContacts});

  @override
  State<TripSetupScreen> createState() => _TripSetupScreenState();
}

class _TripSetupScreenState extends State<TripSetupScreen> {
  int _durationMinutes = 30;
  List<TripContact> _selectedContacts = [];
  bool _isStarting = false;

  final List<int> _presetDurations = [15, 20, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _selectedContacts = List.from(widget.savedContacts);
  }

  DateTime get _eta =>
      DateTime.now().add(Duration(minutes: _durationMinutes));

  String _formatEta() {
    final eta = _eta;
    final h = eta.hour % 12 == 0 ? 12 : eta.hour % 12;
    final m = eta.minute.toString().padLeft(2, '0');
    final period = eta.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _startTrip() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() => _isStarting = true);

    // Request location permission
    final hasPermission = await LocationService.requestPermissions();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Location permission needed for safety monitoring')),
      );
    }

    final session = await TripService().startTrip(
      eta: _eta,
      contacts: _selectedContacts,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveTripScreen(session: session)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Set Up Trip',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ETA section
            _SectionTitle(title: 'How long is your commute?'),
            const SizedBox(height: 16),
            // Duration slider
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_durationMinutes',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('min',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 20)),
                      ),
                    ],
                  ),
                  Text(
                    'Expected arrival: ${_formatEta()}',
                    style: TextStyle(
                        color: const Color(0xFF6B4EFF).withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF6B4EFF),
                      inactiveTrackColor:
                          const Color(0xFF6B4EFF).withOpacity(0.2),
                      thumbColor: const Color(0xFF6B4EFF),
                      overlayColor:
                          const Color(0xFF6B4EFF).withOpacity(0.15),
                    ),
                    child: Slider(
                      value: _durationMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      onChanged: (v) =>
                          setState(() => _durationMinutes = v.round()),
                    ),
                  ),
                  // Quick presets
                  Wrap(
                    spacing: 8,
                    children: _presetDurations.map((d) {
                      final selected = _durationMinutes == d;
                      return GestureDetector(
                        onTap: () => setState(() => _durationMinutes = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6B4EFF)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${d}m',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contacts section
            _SectionTitle(title: 'Alert contacts'),
            const SizedBox(height: 4),
            Text(
              'They\'ll be notified if you don\'t confirm arrival',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...widget.savedContacts.asMap().entries.map((e) {
              final contact = e.value;
              final tier = e.key == 0 ? 'Tier 1' : 'Tier 2';
              final selected = _selectedContacts.contains(contact);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedContacts.remove(contact);
                    } else {
                      _selectedContacts.add(contact);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6B4EFF).withOpacity(0.1)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6B4EFF).withOpacity(0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            const Color(0xFF6B4EFF).withOpacity(0.15),
                        child: Text(
                          contact.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF6B4EFF),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500)),
                            Text(contact.phone,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B4EFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tier,
                            style: const TextStyle(
                                color: Color(0xFF6B4EFF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: selected
                            ? const Color(0xFF6B4EFF)
                            : Colors.white.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 40),

            // Start button
            GestureDetector(
              onTap: _isStarting ? null : _startTrip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
                child: Center(
                  child: _isStarting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, color: Colors.white, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Start Monitoring',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}
