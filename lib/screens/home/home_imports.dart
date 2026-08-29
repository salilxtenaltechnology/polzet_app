
import 'dart:async';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/new%20poll/add_new_poll.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/services/notification/notification_services.dart';
import 'profile/public/public_profile_screen.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/themes/app_text_styles.dart';
import '../../data/token/shared_preferences.dart';
import '../../api/services/link/deeplink_generator_service.dart';
import '../../api/services/update/app_update_service.dart';

import '../../widgets/show_toast.dart';
import 'profile/profile_screen.dart';
import 'search/posts/single_post_details.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/bottom_navigation_bar/bottom_navigation_bar.dart';
import 'dashboard/dashboard_import.dart';
import '../../../provider/user_provider.dart';
import 'insights/insights_screen.dart';
import 'message/message_list.dart';
import 'notifications/notification.dart';
import 'new poll/poll_pop.dart';
import 'search/global_search.dart';

part 'home_screen.dart';
