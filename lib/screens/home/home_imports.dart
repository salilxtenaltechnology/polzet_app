import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../api/services/fcm/fcm_service.dart';
import '../../api/services/notification/notification_services.dart';
import '../../data/token/shared_preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/bottom navigation bar/bottom_navigation_bar.dart';
import '../../widgets/button/custom_floating_button.dart';
import '../../widgets/custom_text_styles.dart';
import '../../widgets/poll/new_poll_bottomsheet.dart';
import 'dashboard/dashboard_import.dart';
import '../../../provider/user_provider.dart';
import 'insights/insights_screen.dart';
import 'message/message_list.dart';
import 'notifications/notification.dart';
import 'poll/poll_pop.dart';
import 'profile/posts/user_profile_import.dart';
import 'search/user_search_import.dart';
import 'settings/settings_import.dart';

part 'home_screen.dart';
