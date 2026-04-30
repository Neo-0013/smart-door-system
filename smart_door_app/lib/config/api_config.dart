/// api_config.dart — Central configuration for API URL
/// Change SERVER_URL to your Cloudflare Tunnel URL when deploying
library;

class ApiConfig {
  /// LAPTOP TESTING: http://localhost:8000
  /// Android Emulator: http://10.0.2.2:8000
  /// Physical Android Device: http://<your-laptop-ip>:8000  (e.g. http://192.168.1.5:8000)
  /// Production (Cloudflare): https://xxx.trycloudflare.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.124.13.194:8000', 
  );

  static String get httpBase => baseUrl;
  static String get wsBase => baseUrl.replaceFirst('http', 'ws').replaceFirst('https', 'wss');

  // Endpoints
  static String get login => '$httpBase/auth/login';
  static String get me => '$httpBase/auth/me';
  static String get setupPin => '$httpBase/auth/setup-pin';
  static String get verifyPin => '$httpBase/auth/verify-pin';
  static String get setupTotp => '$httpBase/auth/setup-totp';
  static String get verifyOtp => '$httpBase/auth/verify-otp';
  static String get createInvite => '$httpBase/users/invite';

  static String get doorStatus => '$httpBase/door/status';
  static String get doorLock => '$httpBase/door/lock';
  static String get doorUnlock => '$httpBase/door/unlock';

  static String get alerts => '$httpBase/alerts';
  static String alertApprove(int id) => '$httpBase/alerts/$id/approve';
  static String alertReject(int id) => '$httpBase/alerts/$id/reject';

  static String get logs => '$httpBase/logs';
  static String get persons => '$httpBase/persons';
  static String get users => '$httpBase/users';

  static String imageUrl(String filename) => '$httpBase/images/$filename';
  static String get wsEndpoint => '$wsBase/ws';
}
