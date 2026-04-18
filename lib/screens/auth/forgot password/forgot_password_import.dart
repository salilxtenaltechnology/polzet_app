import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../../../../api/app_api.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/auth_button.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/text_field/primary_textfield.dart';
import '../change password/change_password.dart';

part 'forgot_password_screen.dart';
