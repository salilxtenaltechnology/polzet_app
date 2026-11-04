import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


import '../../../api/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/connection/no_internet_screen.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/dotted_border/dotted_border.dart';
import '../../../widgets/text_field/secondry_textfield.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../../api/services/image/image_picker_service.dart';
import '../home feed/home_feed_post_card.dart';
import '../new poll/type/new_anonymous_poll.dart';
import '../new poll/type/new_battel_poll.dart';
import '../new poll/type/new_hot_take_poll.dart';
import '../new poll/type/new_image_poll.dart';
import '../new poll/type/new_this_or_that.dart';
import '../profile/edit_profile/edit_profile.dart';
import '../suggested users/suggested_users_list.dart';
import '../topics/poll_topics.dart';
import 'suggested_users.dart';

part 'dashboard.dart';
