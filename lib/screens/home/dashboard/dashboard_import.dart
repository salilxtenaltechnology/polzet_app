import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:convert';


import '../../../api/services/validator/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/connection/no_internet_screen.dart';
import '../../../widgets/loader.dart';
import '../home feed/home_feed_post_card.dart';
import '../profile/edit_profile/edit_profile.dart';
import '../suggested users/suggested_users_list.dart';
import 'suggested_users.dart';

part 'dashboard.dart';
