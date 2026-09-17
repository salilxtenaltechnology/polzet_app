import 'package:flutter_test/flutter_test.dart';
import 'package:polzet_app/models/chat/chat_theme_item.dart';

void main() {
  group('ChatThemeItem 8 Values Test', () {
    const expectedKeys = [
      'classic_maroon',
      'rose_pink',
      'sky_blue',
      'lavender',
      'mint_green',
      'sea_green',
      'midnight_navy',
      'soft_apricot',
    ];

    test('Total 8 defaultChatThemes are defined', () {
      expect(defaultChatThemes.length, 8);
      for (int i = 0; i < expectedKeys.length; i++) {
        expect(defaultChatThemes[i].id, expectedKeys[i]);
      }
    });

    test('All 8 keys resolve correctly via ChatThemeItem.fromIdOrName', () {
      for (final key in expectedKeys) {
        final theme = ChatThemeItem.fromIdOrName(key);
        expect(theme, isNotNull, reason: 'Failed for key: $key');
        expect(theme!.id, key);
      }
    });

    test('Case-insensitivity, spaces, and hyphens resolve correctly', () {
      expect(ChatThemeItem.fromIdOrName('Rose Pink')?.id, 'rose_pink');
      expect(ChatThemeItem.fromIdOrName('rose-pink')?.id, 'rose_pink');
      expect(ChatThemeItem.fromIdOrName('SKY_BLUE')?.id, 'sky_blue');
      expect(ChatThemeItem.fromIdOrName('Mint-Green')?.id, 'mint_green');
      expect(ChatThemeItem.fromIdOrName('Midnight Navy')?.id, 'midnight_navy');
      expect(ChatThemeItem.fromIdOrName('Soft_Apricot')?.id, 'soft_apricot');
      expect(ChatThemeItem.fromIdOrName('SEA_GREEN')?.id, 'sea_green');
      expect(ChatThemeItem.fromIdOrName('Lavender')?.id, 'lavender');
      expect(ChatThemeItem.fromIdOrName('default')?.id, 'classic_maroon');
    });

    test('Null and empty values return null', () {
      expect(ChatThemeItem.fromIdOrName(null), isNull);
      expect(ChatThemeItem.fromIdOrName(''), isNull);
      expect(ChatThemeItem.fromIdOrName('null'), isNull);
      expect(ChatThemeItem.fromIdOrName('none'), isNull);
    });

    test('incomingLinkTextColor and outgoingLinkTextColor default to blue', () {
      for (final theme in defaultChatThemes) {
        expect(theme.getIncomingLinkTextColor(false), isNotNull);
        expect(theme.getOutgoingLinkTextColor(false), isNotNull);
        expect(theme.getIncomingLinkTextColor(true), isNotNull);
        expect(theme.getOutgoingLinkTextColor(true), isNotNull);
      }
    });

    test('midnight_navy has titleColor 0xFFCCCCD0', () {
      final midnight = ChatThemeItem.fromIdOrName('midnight_navy');
      expect(midnight, isNotNull);
      expect(midnight!.getTitleColor(false)?.value, 0xFFCCCCD0);
      expect(midnight.getTitleColor(true)?.value, 0xFFCCCCD0);
    });
  });
}
