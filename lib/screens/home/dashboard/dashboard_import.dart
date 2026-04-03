import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:provider/provider.dart';
import 'dart:convert';


import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/category/category.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/connection/no_internet_screen.dart';
import '../../../widgets/shimmer/home_posts_simmer.dart';
import '../home feed/home_feed_post_card.dart';
import '../profile/edit_profile/edit_profile.dart';
import '../suggestion users/suggestion_users.dart';
import 'suggested_users.dart';

part 'dashboard.dart';
