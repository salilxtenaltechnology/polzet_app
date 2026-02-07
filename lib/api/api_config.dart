class ApiConfig {
  static const bool useHttps = true; // toggle this for http/https

  // prodbackend.polzet.in :  For Produation
  // testbackend.polzet.in : For Test
  // www.polzet.com : Official Domain

  static String get baseUrl {
    const protocol = useHttps ? 'https' : 'http';
    const domain = 'testbackend.polzet.in';
    return '$protocol://$domain/api';
  }

  // https://testbackend.polzet.in

  static String get baseUrlImage {
    const protocol = useHttps ? 'https' : 'http';
    const domain = 'testbackend.polzet.in';
    return '$protocol://$domain';
  }

  static String get sharePostBaseUrl {
    const domain = 'www.testbackend.polzet.in';
    return 'https://$domain';
  }
}
