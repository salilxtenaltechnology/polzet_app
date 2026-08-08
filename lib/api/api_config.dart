class ApiConfig {
  static const bool useHttps = true;

  // prodbackend.polzet.in :  For Produation
  // testbackend.polzet.in : For Test
  // www.polzet.com : Official Domain

  static String domainUrl = 'testbackend.polzet.in';

  static String get baseUrl {
    const protocol = useHttps ? 'https' : 'http';
    final domain = domainUrl;
    return '$protocol://$domain/api';
  }

  static String? normalizePaginationUrl(String? urlString) {
    if (urlString == null || urlString.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(urlString);
      String path = uri.path;

      if (path.startsWith('/api/')) {
        path = path.substring(4);
      } else if (path == '/api') {
        path = '';
      }

      if (!path.startsWith('/')) {
        path = '/$path';
      }

      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '$baseUrl$path$query';
    } catch (_) {
      return urlString;
    }
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

  static String get wsBaseUrl {
    const wsProtocol = useHttps ? 'wss' : 'ws';
    final domain = domainUrl;
    return '$wsProtocol://$domain';
  }

  static String get deepLinkHost {
    if (domainUrl.contains('testbackend.polzet.in')) {
      return 'testfrontend.polzet.in';
    } else {
      return 'www.polzet.com';
    }
  }
}

// https://prodbackend.polzet.in

// dart run build_runner build
// Add language new texts : flutter gen-l10n

// flutter run 2>&1 | grep -v "BLASTBufferQueue"
