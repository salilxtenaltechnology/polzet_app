
import 'dart:async';
import 'dart:io';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/services/notification/notification_services.dart';
import '../../core/connectivity/connectivity_overlay.dart';
import '../../core/navigation/notification_router.dart';
import '../../data/token/shared_preferences.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../provider/connection_provider.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/bottom navigation bar/bottom_navigation_bar.dart';
import '../../widgets/bottomsheets/feedback/feedback_bottomsheet.dart';
import '../../widgets/button/custom_floating_button.dart';
import '../../widgets/connection/no_internet_screen.dart';
import '../../widgets/custom_text_styles.dart';
import '../../widgets/error/connectivity_wrapper.dart';
import '../../widgets/error/offline_banner.dart';
import '../../widgets/poll/new_poll_bottomsheet.dart';
import '../terms_acceptance/terms_acceptance.dart';
import 'dashboard/dashboard_import.dart';
import '../../../provider/user_provider.dart';
import 'insights/insights_screen.dart';
import 'message/message_list.dart';
import 'notifications/notification.dart';
import 'poll/poll_pop.dart';
import 'profile/posts/user_profile_import.dart';
import 'search/global_search.dart';

part 'home_screen.dart';
