class AppConfig {
  // Backing Google Apps Script web app — same endpoint the web portal uses.
  static const String scriptUrl =
      'https://script.google.com/macros/s/AKfycbw56mogmOpMbayoil4lFFTGGpUmyBkvQcHRUMkUQzUZuujmhbA7UAAsNHl4WyhjTuzg3A/exec';

  /// Built-in super-admins. These always work, regardless of the Users sheet
  /// — mirrors the DEFAULT_USERS / SUPER_ADMIN block in the web portal.
  static const List<Map<String, String>> builtInAdmins = [
    {
      'username': 'anil',
      'password': 'anil@022',
      'displayName': 'Anil',
      'role': 'admin',
    },
    {
      'username': 'admin',
      'password': 'admin123',
      'displayName': 'Super Admin',
      'role': 'admin',
    },
  ];

  static const List<String> statusOptions = [
    'On Site',
    'In Office',
    'Work From Home',
    'On Leave',
    'Holiday',
    'Weekend',
  ];

  static const List<String> workTypes = [
    'Project',
    'Service',
    'Office Work',
    'BMS Integration',
    'Site Survey',
  ];
}
