class ApiConfig {
  static const String apiOrigin = String.fromEnvironment(
    'API_ORIGIN',
    // defaultValue: 'https://resale-relapsing-darkening.ngrok-free.dev',
    defaultValue: 'http://192.168.24.18:5013',
  );

  static const String apiBaseUrl = '$apiOrigin/api';

  static String resolveMediaUrl(String? url) {
    final u = (url ?? '').trim();
    if (u.isEmpty) return '';
    final lower = u.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return u;
    if (u.startsWith('/')) return '$apiOrigin$u';
    return '$apiOrigin/$u';
  }
}

