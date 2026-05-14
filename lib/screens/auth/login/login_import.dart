import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../provider/user_provider.dart';

import '../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../main.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/country/country_model.dart';
import '../../../widgets/button/auth_button.dart';
import '../../../widgets/country_code/custom_country_code.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/text_field/primary_textfield.dart';
import '../forgot password/new_forgot_password_screen.dart';
part 'login_screen.dart';
