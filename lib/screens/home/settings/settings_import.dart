import 'dart:async';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/app_api.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/themes/theme_provider.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/app_icons.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/diolog/custom_diolog.dart';
import '../../../widgets/show_toast.dart';
import '../../auth/login/login_import.dart';

import '../profile/edit_profile/edit_profile.dart';
import 'account/private_account.dart';
import 'help and support/help_support.dart';
import 'language/language_import.dart';
import 'notifications/notifications.dart';
import 'privacy/privacy_policy.dart';
import 'security/security.dart';
import 'terms and policy/terms_and_conditions.dart';

part 'settings.dart';
