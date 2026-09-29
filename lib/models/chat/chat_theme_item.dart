// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class ChatThemeItem {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color incomingBubbleColor;
  final Color outgoingBubbleColor;
  final Color? incomingMessageTextColor;
  final Color? outgoingMessageTextColor;
  final Color? incomingCardColor;
  final Color? outgoingCardColor;
  final Color? incomingLinkTextColor;
  final Color? outgoingLinkTextColor;
  final Color? unselectedBorderColor;
  final Color? messageBarColor;
  final Color? dateColor;
  final Color? messageTimeColor;
  final Color? titleColor;

  // Dark mode colors
  final Color? darkBackgroundColor;
  final Color? darkIncomingBubbleColor;
  final Color? darkOutgoingBubbleColor;
  final Color? darkIncomingMessageTextColor;
  final Color? darkOutgoingMessageTextColor;
  final Color? darkIncomingCardColor;
  final Color? darkOutgoingCardColor;
  final Color? darkIncomingLinkTextColor;
  final Color? darkOutgoingLinkTextColor;
  final Color? darkMessageBarColor;
  final Color? darkDateColor;
  final Color? darkMessageTimeColor;
  final Color? darkUnselectedBorderColor;
  final Color? darkTitleColor;

  const ChatThemeItem({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.incomingBubbleColor,
    required this.outgoingBubbleColor,
    this.incomingMessageTextColor,
    this.outgoingMessageTextColor,
    this.incomingCardColor,
    this.outgoingCardColor,
    this.incomingLinkTextColor,
    this.outgoingLinkTextColor,
    this.unselectedBorderColor,
    this.messageBarColor,
    this.dateColor,
    this.messageTimeColor,
    this.titleColor,
    this.darkBackgroundColor,
    this.darkIncomingBubbleColor,
    this.darkOutgoingBubbleColor,
    this.darkIncomingMessageTextColor,
    this.darkOutgoingMessageTextColor,
    this.darkIncomingCardColor,
    this.darkOutgoingCardColor,
    this.darkIncomingLinkTextColor,
    this.darkOutgoingLinkTextColor,
    this.darkMessageBarColor,
    this.darkDateColor,
    this.darkMessageTimeColor,
    this.darkUnselectedBorderColor,
    this.darkTitleColor,
  });

  Color getBgColor(bool isDark) =>
      (isDark ? darkBackgroundColor : null) ?? backgroundColor;

  Color getIncomingColor(bool isDark) =>
      (isDark ? darkIncomingBubbleColor : null) ?? incomingBubbleColor;

  Color getOutgoingColor(bool isDark) =>
      (isDark ? darkOutgoingBubbleColor : null) ?? outgoingBubbleColor;

  Color? getIncomingMessageTextColor(bool isDark) =>
      (isDark ? darkIncomingMessageTextColor : null) ??
      incomingMessageTextColor;

  Color? getOutgoingMessageTextColor(bool isDark) =>
      (isDark ? darkOutgoingMessageTextColor : null) ??
      outgoingMessageTextColor;

  Color? getIncomingCardColor(bool isDark) =>
      (isDark ? darkIncomingCardColor : null) ?? incomingCardColor;

  Color? getOutgoingCardColor(bool isDark) =>
      (isDark ? darkOutgoingCardColor : null) ?? outgoingCardColor;

  Color? getIncomingLinkTextColor(bool isDark) =>
      (isDark ? darkIncomingLinkTextColor : null) ??
      incomingLinkTextColor ??
      Colors.blue;

  Color? getOutgoingLinkTextColor(bool isDark) =>
      (isDark ? darkOutgoingLinkTextColor : null) ??
      outgoingLinkTextColor ??
      Colors.blue;

  Color? getMessageBarColor(bool isDark) =>
      (isDark ? darkMessageBarColor : null) ?? messageBarColor;

  Color? getDateColor(bool isDark) =>
      (isDark ? darkDateColor : null) ?? dateColor;

  Color? getMessageTimeColor(bool isDark) =>
      (isDark ? darkMessageTimeColor : null) ?? messageTimeColor;

  Color? getTitleColor(bool isDark) =>
      (isDark ? darkTitleColor : null) ?? titleColor;

  Color? getUnselectedBorderColor(bool isDark) =>
      (isDark ? darkUnselectedBorderColor : null) ??
      (isDark ? null : unselectedBorderColor);

  static ChatThemeItem? fromIdOrName(dynamic value) {
    if (value == null) return null;
    if (value is ChatThemeItem) return value;
    final str = value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (str.isEmpty || str == 'null' || str == 'none') {
      return null;
    }

    if (str == 'default') {
      return defaultChatThemes.first;
    }

    for (final theme in defaultChatThemes) {
      final themeId = theme.id
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
      final themeName = theme.name
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
      if (themeId == str || themeName == str) {
        return theme;
      }
    }
    return null;
  }
}

const List<ChatThemeItem> defaultChatThemes = [
  ChatThemeItem(
    id: 'classic_maroon',
    name: 'Classic Maroon',
    backgroundColor: Color(0xFFFFFFFF),
    incomingBubbleColor: Color(0xFFF3F4F6),
    outgoingBubbleColor: Color(0xFF9B3046),
    incomingMessageTextColor: Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0xFFFFFFFF),
    outgoingCardColor: Color(0xFFFFFFFF),
    incomingLinkTextColor: Colors.blue,
    outgoingLinkTextColor: Color(0xFF41A7FB),
    unselectedBorderColor: Color(0xFFECEEF1),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF05070E),
    darkIncomingBubbleColor: Color(0xFF2A2A2E),
    darkOutgoingBubbleColor: Color(0xFF8B263E),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0xFF2A2A2E),
    darkOutgoingCardColor: Color(0xFF8B263E),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkMessageBarColor: Color(0x338B263E),
    darkDateColor: Color(0xFF2A2A2E),
    darkMessageTimeColor: Color(0xFFBFBFBF),
  ),
  ChatThemeItem(
    id: 'rose_pink',
    name: 'Rose Pink',
    backgroundColor: Color(0xFFFCE9F1),
    incomingBubbleColor: Color(0xFFFEF4F9),
    outgoingBubbleColor: Color(0xFFFEBACE),
    incomingMessageTextColor: Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0x59FEBACE),
    outgoingCardColor: Color(0xFFFEBACE),
    incomingLinkTextColor: Color(0XFFB52F55),
    outgoingLinkTextColor: Color(0XFFB52F55),
    messageBarColor: Color(0x33FEBACE),
    dateColor: Color(0xFFFDD4DF),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF1F1218),
    darkIncomingBubbleColor: Color(0xFF33202A),
    darkOutgoingBubbleColor: Color(0xFFD96A8A),
    darkIncomingMessageTextColor: Color(0XFFD1D1D6),
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x33D96A8A),
    darkOutgoingCardColor: Color(0xFFD96A8A),
    darkIncomingLinkTextColor: Color(0XFFFFC7D7),
    darkOutgoingLinkTextColor: Color(0xFFFCCFDC),
    darkMessageBarColor: Color(0x33D96A8A),
    darkDateColor: Color(0xFF3D1923),
    darkMessageTimeColor: Color(0xFFC4C4C4),
  ),
  ChatThemeItem(
    id: 'sky_blue',
    name: 'Sky Blue',
    backgroundColor: Color(0xFFE5F1FD),
    incomingBubbleColor: Color(0xFFFAFCFE),
    outgoingBubbleColor: Color(0xFF93D2FD),
    incomingMessageTextColor: Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0x5993D2FD),
    outgoingCardColor: Color(0xFF93D2FD),
    incomingLinkTextColor: Color(0xFF1677B8),
    outgoingLinkTextColor: Color(0xFF1677B8),
    messageBarColor: Color(0x3392D2FD),
    dateColor: Color(0xFFCCE5FD),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF0D1924),
    darkIncomingBubbleColor: Color(0xFF172A3A),
    darkOutgoingBubbleColor: Color(0xFF3B9EDB),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x333B9EDB),
    darkOutgoingCardColor: Color(0xFF3B9EDB),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkMessageBarColor: Color(0x333B9EDB),
    darkDateColor: Color(0xFF16283A),
    darkMessageTimeColor: Color(0xFFC4C4C4),
  ),
  ChatThemeItem(
    id: 'lavender',
    name: 'Lavender',
    backgroundColor: Color(0xFFECE4FD),
    incomingBubbleColor: Color(0xFFF5F1FE),
    outgoingBubbleColor: Color(0xFFCFBAFD),
    incomingMessageTextColor:  Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0xFFF5F1FE),
    outgoingCardColor: Color(0xFFCFBAFD),
    incomingLinkTextColor: Color(0xFF7451B8),
    outgoingLinkTextColor: Color(0xFF7451B8),
    messageBarColor: Color(0x33CFBAFD),
    dateColor: Color(0xFFDCCEFA),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF140E1E),
    darkIncomingBubbleColor: Color(0xFF281C3D),
    darkOutgoingBubbleColor: Color(0xFF9563FE),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x339B7BE8),
    darkOutgoingCardColor: Color(0xFF9B7BE8),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkMessageBarColor: Color(0x339563FE),
    darkDateColor: Color(0xFF281C3D),
    darkMessageTimeColor: Color(0xFFC7B3EC),
  ),
  ChatThemeItem(
    id: 'mint_green',
    name: 'Mint Green',
    backgroundColor: Color(0xFFDEF4DC),
    incomingBubbleColor: Color(0xFFF5FAF5),
    outgoingBubbleColor: Color(0xFF91CD97),
    incomingMessageTextColor: Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0x5991CD97),
    outgoingCardColor: Color(0xFF91CD97),
    incomingLinkTextColor: Color(0xFF287A3D),
    outgoingLinkTextColor:  Color(0xFF287A3D),
    messageBarColor: Color(0x3391CD97),
    dateColor: Color(0xD488C198),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF101C14),
    darkIncomingBubbleColor: Color(0xFF173424),
    darkOutgoingBubbleColor: Color(0xFF4BB568),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x3367B978),
    darkOutgoingCardColor: Color(0xFF67B978),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkMessageBarColor: Color(0x334BB568),
    darkDateColor: Color(0xFF173424),
    darkMessageTimeColor: Color(0xFFA3D8B3),
  ),
  ChatThemeItem(
    id: 'sea_green',
    name: 'Sea Green',
    backgroundColor: Color(0xFFE2F5F3),
    incomingBubbleColor: Color(0xFFF4FCFB),
    outgoingBubbleColor: Color(0xFF72C9C0),
    incomingMessageTextColor: Color(0XFF595959),
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0x5972C9C0),
    outgoingCardColor: Color(0xFF72C9C0),
    incomingLinkTextColor: Color(0xFF167B76),
    outgoingLinkTextColor: Color(0xFF167B76),
    messageBarColor: Color(0x3372C9C0),
    dateColor: Color(0xFFA6D9D4),
    messageTimeColor: Color(0xFF707070),
    darkBackgroundColor: Color(0xFF0A1718),
    darkIncomingBubbleColor: Color(0xFF143133),
    darkOutgoingBubbleColor: Color(0xFF2CB5B7),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x3348AFA7),
    darkOutgoingCardColor: Color(0xFF48AFA7),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkMessageBarColor: Color(0x332CB5B7),
    darkDateColor: Color(0xFF143133),
    darkMessageTimeColor: Color(0xFF9CDCDD),
  ),
  ChatThemeItem(
    id: 'midnight_navy',
    name: 'Midnight Navy',
    backgroundColor: Color(0xFF0A1523),
    incomingBubbleColor: Color(0xFF9EAFC0),
    outgoingBubbleColor: Color(0xFF24425D),
    incomingMessageTextColor: Colors.black,
    outgoingMessageTextColor: Colors.white,
    incomingCardColor: Color(0xFF152333),
    outgoingCardColor: Color(0xFF3D6387),
    incomingLinkTextColor: Color(0xFF42698D),
    outgoingLinkTextColor: Color(0xFFCFE8FF),
    titleColor: Color(0xFFCCCCD0),
    messageBarColor: Color(0x3324425D),
    dateColor: Color(0xFF546D84),
    messageTimeColor: Color(0xFFC4C4C4),
    darkBackgroundColor: Color(0xFF080F18),
    darkIncomingBubbleColor: Color(0xFF152333),
    darkOutgoingBubbleColor: Color(0xFF3D6387),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x593D6387),
    darkOutgoingCardColor: Color(0xFF3D6387),
    darkIncomingLinkTextColor: Colors.blue,
    darkOutgoingLinkTextColor: Colors.blue,
    darkTitleColor: Color(0xFFCCCCD0),
    darkMessageBarColor: Color(0x333D6387),
    darkDateColor: Color(0xFF122133),
    darkMessageTimeColor: Color(0xFFC4C4C4),
  ),
  ChatThemeItem(
    id: 'soft_apricot',
    name: 'Soft Apricot',
    backgroundColor: Color(0xFFFEE5DC),
    incomingBubbleColor: Color(0xFFFDF7F4),
    outgoingBubbleColor: Color(0xFFF4794D),
    incomingMessageTextColor: Colors.black,
    outgoingMessageTextColor: Colors.white,
    incomingCardColor:Color(0x59F4794D),
    outgoingCardColor: Color(0xFFF4794D),
    incomingLinkTextColor: Color(0xFFFF7240),
    outgoingLinkTextColor: Color(0xFFFFD6C7), 
    messageBarColor: Color(0x33F4794D),
    dateColor: Color(0xFFFFBBA3),
    messageTimeColor: Color(0xFF898989),
    darkBackgroundColor: Color(0xFF211412),
    darkIncomingBubbleColor: Color(0xFF39221E),
    darkOutgoingBubbleColor: Color(0xFFF57E53),
    darkIncomingMessageTextColor: Colors.white,
    darkOutgoingMessageTextColor: Colors.white,
    darkIncomingCardColor: Color(0x33F57E53),
    darkOutgoingCardColor: Color(0xFFF57E53),
    darkIncomingLinkTextColor: Color(0XFFFFE5DB),
    darkOutgoingLinkTextColor: Color(0XFFFFE5DB),
    darkMessageBarColor: Color(0x33F57E53),
    darkDateColor: Color(0xFF3A2216),
    darkMessageTimeColor: Color(0xFFC4C4C4),
  ),
];
