import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';

import '../../../api/services/api_service.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/category/category.dart';
import '../../../models/posts/homefeed_posts_model.dart';
import '../../../widgets/simmer/home_posts_simmer.dart';
import '../home feed/home_feed_post_card.dart';

part 'dashboard.dart';
