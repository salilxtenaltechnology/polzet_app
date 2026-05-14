class ApiConfig {
  static const bool useHttps = true;

  // prodbackend.polzet.in :  For Produation
  // testbackend.polzet.in : For Test
  // www.polzet.com : Official Domain

  static String domainUrl =
      'testbackend.polzet.in'; // Change this to your backend domain

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


// https://testbackend.polzet.in
// https://prodbackend.polzet.in

// dart run build_runner build