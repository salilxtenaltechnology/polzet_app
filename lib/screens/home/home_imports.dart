
import 'dart:async';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/services/notification/notification_services.dart';
import '../../core/navigation/notification_router.dart';
import '../../core/themes/app_text_styles.dart';
import '../../data/token/shared_preferences.dart';
import '../../api/services/link/deeplink_generator_service.dart';
import '../flow/flow_screens.dart';
import 'search/posts/single_post_details.dart';
import '../../gen/assets.gen.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../provider/connection_provider.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/bottom_navigation_bar/bottom_navigation_bar.dart';
import '../../core/utils/bottomsheet_util.dart';
import '../terms_acceptance/terms_acceptance.dart';
import 'dashboard/dashboard_import.dart';
import '../../../provider/user_provider.dart';
import 'group/create_group.dart';
import 'insights/insights_screen.dart';
import 'message/message_list.dart';
import 'notifications/notification.dart';
import 'poll/poll_pop.dart';
import 'profile/posts/user_profile_import.dart';
import 'search/global_search.dart';

part 'home_screen.dart';
