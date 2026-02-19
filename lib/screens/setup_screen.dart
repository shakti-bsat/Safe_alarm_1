import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trip_session.dart';
import '../services/location_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  final List<TripContact> _contacts = [];

  // Contact form
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    setState(() => _currentPage++);
  }

  void _addContact() {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) return;
    setState(() {
      _contacts.add(TripContact(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      ));
      _nameController.clear();
      _phoneController.clear();
    });
  }

  Future<void> _completeSetup() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one trusted contact')),
      );
      return;
    }

    await LocationService.requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_complete', true);
    await prefs.setString(
      'contacts',
      jsonEncode(_contacts.map((c) => c.toMap()).toList()),
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WelcomePage(onNext: _nextPage),
          _ContactsPage(
            contacts: _contacts,
            nameController: _nameController,
            phoneController: _phoneController,
            onAdd: _addContact,
            onComplete: _completeSetup,
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.shield, size: 40, color: Color(0xFF6B4EFF)),
            ),
            const SizedBox(height: 32),
            const Text(
              'SafeAlarm',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Proactive safety monitoring that alerts your loved ones if you don\'t arrive safely.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            _FeatureRow(
              icon: Icons.timer_outlined,
              title: 'ETA Monitoring',
              subtitle: 'Set your expected arrival time',
            ),
            const SizedBox(height: 20),
            _FeatureRow(
              icon: Icons.people_outline,
              title: 'Trusted Contacts',
              subtitle: 'Automatic alerts if you don\'t confirm',
            ),
            const SizedBox(height: 20),
            _FeatureRow(
              icon: Icons.location_on_outlined,
              title: 'Live Location',
              subtitle: 'Contacts receive your GPS coordinates',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF6B4EFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF6B4EFF)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14)),
          ],
        ),
      ],
    );
  }
}

class _ContactsPage extends StatelessWidget {
  final List<TripContact> contacts;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onAdd;
  final VoidCallback onComplete;

  const _ContactsPage({
    required this.contacts,
    required this.nameController,
    required this.phoneController,
    required this.onAdd,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Add Trusted\nContacts',
              style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'These people will be alerted if you don\'t confirm safe arrival.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 15),
            ),
            const SizedBox(height: 32),
            // Name field
            _buildTextField(controller: nameController, label: 'Contact Name', icon: Icons.person_outline),
            const SizedBox(height: 12),
            _buildTextField(
                controller: phoneController,
                label: 'Phone Number (e.g. +1234567890)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, color: Color(0xFF6B4EFF)),
                label: const Text('Add Contact',
                    style: TextStyle(color: Color(0xFF6B4EFF))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6B4EFF)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (contacts.isNotEmpty) ...[
              Text('Contacts (${contacts.length})',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 13)),
              const SizedBox(height: 8),
              ...contacts.asMap().entries.map((e) => _ContactTile(
                    contact: e.value,
                    tier: e.key == 0 ? 'Tier 1' : 'Tier 2',
                  )),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Start Using SafeAlarm',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B4EFF)),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final TripContact contact;
  final String tier;
  const _ContactTile({required this.contact, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 18, color: Color(0xFF6B4EFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                Text(contact.phone,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tier,
                style: const TextStyle(
                    color: Color(0xFF6B4EFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
