class ApiConfig {
  static const bool useHttps = true; // toggle this for http/https

  // prodbackend.polzet.in :  For Produation
  // testbackend.polzet.in : For Test
  // www.polzet.com : Official Domain

  static String domainUrl =
      'prodbackend.polzet.in'; // Change this to your backend domain

  static String get baseUrl {
    const protocol = useHttps ? 'https' : 'http';
    final domain = domainUrl;
    return '$protocol://$domain/api';
  }

  static String get baseUrlImage {
    const protocol = useHttps ? 'https' : 'http';
    final domain = domainUrl;
    return '$protocol://$domain';
  }

  static String get sharePostBaseUrl {
    final domain = domainUrl;
    return 'https://$domain';
  }
}
