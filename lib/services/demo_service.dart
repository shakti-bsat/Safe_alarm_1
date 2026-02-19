/// DemoService — toggle this for hackathon demo mode
/// When demoMode = true:
///   - SMS alerts are printed to console instead of sending
///   - Battery simulation shows a mock low-battery scenario
///   - No real Twilio API calls are made
class DemoService {
  static bool demoMode = false; // Set to true for demo without Twilio

  static void log(String category, String message) {
    if (demoMode) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📱 [DEMO] $category');
      print(message);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  static Future<void> simulateDelay([int ms = 800]) async {
    if (demoMode) {
      await Future.delayed(Duration(milliseconds: ms));
    }
  }
}
