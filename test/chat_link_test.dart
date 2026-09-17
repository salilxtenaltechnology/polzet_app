import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  final RegExp urlRegex = RegExp(
    r'((?:https?:\/\/|www\.|(?:[a-zA-Z0-9-]+\.)?polzet\.(?:com|in)\/)[^\s<>()]+(?:\([^\s<>()]+\)|[^\s`!()\[\]{};:\x27"\x22.,<>?«»“”‘’]))|(polzet:\/\/[^\s]+)',
    caseSensitive: false,
  );

  String? extractProfileUsernameFromUri(Uri uri) {
    try {
      if (uri.scheme.toLowerCase() == 'polzet') {
        final host = uri.host.toLowerCase();
        if (host == 'post') {
          return null;
        }
        if (host == 'profile') {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            final username = segments[0].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
        } else if (host.isNotEmpty && host != 'g' && host != 'group') {
          final username = uri.host.replaceFirst(RegExp(r'^@'), '').trim();
          if (username.isNotEmpty) return username;
        }
      }

      final host = uri.host.toLowerCase();
      final isPolzetHost = host.contains('polzet.com') ||
          host.contains('polzet.in') ||
          host == 'www.polzet.com' ||
          host == 'testfrontend.polzet.in';

      if (isPolzetHost) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isEmpty) return null;

        if (segments[0].toLowerCase() == 'post') {
          return null;
        }

        if (segments[0].toLowerCase() == 'g' ||
            segments[0].toLowerCase() == 'group') {
          return null;
        }

        if (segments[0].toLowerCase() == 'profile') {
          if (segments.length >= 2) {
            final username = segments[1].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
          return null;
        }

        if (segments.length == 1) {
          final first = segments[0].toLowerCase();
          const reservedRoutes = {
            'post',
            'profile',
            'g',
            'group',
            'static',
            'assets',
            'terms',
            'privacy',
            'about',
            'help',
            'faq',
            'settings',
            'login',
            'signup',
            'register',
            'api',
          };
          if (!reservedRoutes.contains(first)) {
            final username = segments[0].replaceFirst(RegExp(r'^@'), '').trim();
            if (username.isNotEmpty) return username;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String formatUrl(String rawUrl) {
    String formattedUrl = rawUrl.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://') &&
        !formattedUrl.startsWith('polzet://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    return formattedUrl;
  }

  String getDateSeparator(DateTime date, {DateTime? simulatedNow}) {
    final now = simulatedNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(msgDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference > 1 && difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  group('Profile Link Extraction and Regex Tests', () {
    test('Matches and parses https://www.polzet.com/mileco_555', () {
      const text = 'Hey check out https://www.polzet.com/mileco_555 profile!';
      final match = urlRegex.firstMatch(text);
      expect(match, isNotNull);
      final rawUrl = match!.group(0)!;
      expect(rawUrl, 'https://www.polzet.com/mileco_555');

      final uri = Uri.parse(formatUrl(rawUrl));
      expect(extractProfileUsernameFromUri(uri), 'mileco_555');
    });

    test('Matches and parses "text": "https://www.polzet.com/mileco_555"', () {
      const text = '"text": "https://www.polzet.com/mileco_555"';
      final match = urlRegex.firstMatch(text);
      expect(match, isNotNull);
      final rawUrl = match!.group(0)!;
      expect(rawUrl, 'https://www.polzet.com/mileco_555');

      final uri = Uri.parse(formatUrl(rawUrl));
      expect(extractProfileUsernameFromUri(uri), 'mileco_555');
    });

    test('Matches and parses polzet.com/mileco_555 without scheme', () {
      const text = 'Visit polzet.com/mileco_555 now';
      final match = urlRegex.firstMatch(text);
      expect(match, isNotNull);
      final rawUrl = match!.group(0)!;

      final uri = Uri.parse(formatUrl(rawUrl));
      expect(extractProfileUsernameFromUri(uri), 'mileco_555');
    });

    test('Matches and parses https://www.polzet.com/profile/mileco_555', () {
      const text = 'https://www.polzet.com/profile/mileco_555';
      final match = urlRegex.firstMatch(text);
      expect(match, isNotNull);

      final uri = Uri.parse(formatUrl(match!.group(0)!));
      expect(extractProfileUsernameFromUri(uri), 'mileco_555');
    });

    test('Custom scheme polzet://profile/mileco_555', () {
      final uri = Uri.parse('polzet://profile/mileco_555');
      expect(extractProfileUsernameFromUri(uri), 'mileco_555');
    });

    test('Ignores post URLs for profile extraction', () {
      final uri = Uri.parse('https://www.polzet.com/post/mileco_555/123');
      expect(extractProfileUsernameFromUri(uri), isNull);
    });

    test('Ignores external URLs for profile extraction', () {
      final uri = Uri.parse('https://google.com/search');
      expect(extractProfileUsernameFromUri(uri), isNull);
    });
  });

  group('Date Separator Tests', () {
    final now = DateTime(2026, 9, 5);

    test('Returns Today for same day', () {
      expect(getDateSeparator(DateTime(2026, 9, 5, 14, 30), simulatedNow: now), 'Today');
    });

    test('Returns Yesterday for 1 day ago', () {
      expect(getDateSeparator(DateTime(2026, 9, 4, 10, 0), simulatedNow: now), 'Yesterday');
    });

    test('Returns day name for 2-6 days ago', () {
      expect(getDateSeparator(DateTime(2026, 9, 3), simulatedNow: now), 'Thursday');
      expect(getDateSeparator(DateTime(2026, 9, 1), simulatedNow: now), 'Tuesday');
    });

    test('Returns "d MMMM yyyy" for older dates (Ex: 20 August 2026)', () {
      expect(getDateSeparator(DateTime(2026, 8, 20), simulatedNow: now), '20 August 2026');
      expect(getDateSeparator(DateTime(2025, 1, 15), simulatedNow: now), '15 January 2025');
    });
  });
}
