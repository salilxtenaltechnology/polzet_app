// ignore_for_file: undefined_hidden_name
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:glass/glass.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/app_api.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/posts/user_post_model.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/card/user_things_card.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/simmer/chase/profile_chase_simmer.dart';
import '../../poll/poll_images.dart';
import '../../poll/poll_question.dart';
import '../chase/user_chase.dart';
import '../edit_profile/edit_profile.dart';
import 'image_posts_list.dart';
import 'questions_posts_list.dart';
import '../public/public_profile.dart';

part '../user_profile.dart';
