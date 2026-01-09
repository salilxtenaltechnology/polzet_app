class ApiConfig {
  static const bool useHttps = true; // toggle this for http/https

  // prodbackend.polzet.in :  For Produation
  // testbackend.polzet.in : For Test
  // www.polzet.com : Domain

  static String get baseUrl {
    final protocol = useHttps ? 'https' : 'http';
    final domain = 'testbackend.polzet.in';
    return '$protocol://$domain/api';
  }

  // https://testbackend.polzet.in

  static String get baseUrlImage {
    final protocol = useHttps ? 'https' : 'http';
    final domain = 'testbackend.polzet.in';
    return '$protocol://$domain';
  }
}
