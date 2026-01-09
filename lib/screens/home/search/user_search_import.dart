import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../api/services/api_service.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/search/search_user_model.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/button/primary_button.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/simmer/search_user_simmer.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import '../profile/public/public_profile.dart';

part 'user_search.dart';
