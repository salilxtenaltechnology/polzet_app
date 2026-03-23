import 'dart:async';
import 'dart:io';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:polzet_app/api/services/api_service.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'dart:convert';

import '../../../../api/app_api.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/constants/app_strings.dart';

import '../../../api/services/fcm/fcm_service.dart';
import '../../../api/services/notification/notification_services.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/auth_button.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/text_field/primary_textfield.dart';
import '../../home/home_imports.dart';
import '../signup/signup_imports.dart';

part 'email_varify_screen.dart';
