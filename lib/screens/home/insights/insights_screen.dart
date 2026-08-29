// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/api_service.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../models/insights/insights_model.dart';
import '../../../provider/user_provider.dart';
import '../../../widgets/connection/no_internet_screen.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/dotted_border/dotted_border.dart';
import '../../../widgets/loader.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final ApiService _apiService = ApiService();
  InsightsModel? insightsModel;
  bool _loading = true;
  String? errorMessage;
  bool _isWaitlistJoined = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.cachedInsightsData != null) {
      insightsModel = userProvider.cachedInsightsData;
      _loading = false;
    }
    _checkWaitlistStatus();
    _fetchData();
  }

  Future<void> _checkWaitlistStatus() async {
    final joined = await SharedPrefService.isVipWaitlistJoined();
    if (mounted && joined != _isWaitlistJoined) {
      setState(() {
        _isWaitlistJoined = joined;
      });
    }
  }

  Future<void> _fetchData() async {
    try {
      final data = await _apiService.getInsightsData();
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.cachedInsightsData = data;
        setState(() {
          insightsModel = data;
          _loading = false;
          errorMessage = null;
        });
      }
    } on SocketException catch (e) {
      debugPrint('No internet connection');
      if (mounted) {
        setState(() {
          _loading = false;
          if (insightsModel == null) {
            errorMessage = 'no_internet: ${e.toString()}';
          }
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('Request timed out');
      if (mounted) {
        setState(() {
          _loading = false;
          if (insightsModel == null) {
            errorMessage = 'no_internet: timeout ${e.toString()}';
          }
        });
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.response?.statusCode} | ${e.type}');
      if (mounted) {
        setState(() {
          _loading = false;
          if (insightsModel == null) {
            final statusCode = e.response?.statusCode ?? 0;
            if (statusCode >= 500) {
              errorMessage = 'server_error: status $statusCode';
            } else if (e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout) {
              errorMessage = 'no_internet: timeout ${e.message}';
            } else {
              errorMessage = 'unknown: status $statusCode ${e.message}';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching insights: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          if (insightsModel == null) {
            errorMessage = 'unknown: ${e.toString()}';
          }
        });
      }
    }
  }

  List<FlSpot> get _spots => insightsModel == null
      ? []
      : List.generate(
          insightsModel!.recent.length,
          (i) => FlSpot(i.toDouble(), insightsModel!.recent[i].value),
        );

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (errorMessage != null && insightsModel == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: ConnectionErrorScreen(
          type: errorMessage!.startsWith('no_internet')
              ? ConnectionErrorType.noInternet
              : errorMessage!.startsWith('server_error')
              ? ConnectionErrorType.serverError
              : ConnectionErrorType.unknown,
          errorMessage: errorMessage,
          onRetry: () {
            setState(() {
              errorMessage = null;
              _loading = true;
            });
            _fetchData();
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _loading
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.pink),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.totalviews,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.totalViews.toString() ?? '0',
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // ── Chasers (Vibe) ───────────────────────────────────────
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.orange),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.vibe,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.chasers.toString() ?? '0',
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                // ── Polls Created ────────────────────────────────────────
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.pollcreated,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.pollsCreated.toString() ?? '0',
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15.h),

                if (insightsModel != null && insightsModel!.recent.isNotEmpty)
                  CustomCard(
                    widget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.weeklyviews,
                          style: AppTextStyles.subText.copyWith(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 15.h),
                        SizedBox(
                          height: 180.h,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (insightsModel!.recent.length - 1)
                                  .toDouble(),
                              minY: 0,
                              maxY:
                                  insightsModel!.recent
                                      .map((e) => e.value)
                                      .reduce((a, b) => a > b ? a : b) +
                                  2,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground.withOpacity(0.08),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, _) => Text(
                                      v.toInt().toString(),
                                      style: AppTextStyles.subText.copyWith(
                                        fontSize: 9.sp,
                                      ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    interval: 1,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 ||
                                          i >= insightsModel!.recent.length) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: EdgeInsets.only(top: 5.h),
                                        child: Text(
                                          // Shows "W1", "W2" … to save space
                                          insightsModel!.recent[i].label
                                              .replaceAll('Week ', 'W'),
                                          style: AppTextStyles.subText.copyWith(
                                            fontSize: 9.sp,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _spots,
                                  isCurved: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      const Color(0xFF9B3046).withOpacity(0.5),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  barWidth: 2,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: isDarkMode
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF2D2D2D),
                                              Color(0XFF1A1A1A),
                                            ],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFFFCF7F8),
                                              Color(0XFFFFF1F4),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                  ),
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (_, __, ___, ____) =>
                                        FlDotCirclePainter(
                                          radius: 4,
                                          color: Colors.white,
                                          strokeWidth: 2,
                                          strokeColor: const Color(0xFFEC4899),
                                        ),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (spots) => spots.map((s) {
                                    final i = s.x.toInt();
                                    return LineTooltipItem(
                                      '${insightsModel!.recent[i].label}\n${s.y.toInt()} views',
                                      AppTextStyles.subText.copyWith(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 15.h),

                // ── Coming Soon Features Card ─────────────────────────
                CustomCard(
                  widget: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 4.w,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Pill badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF331620)
                                : const Color(0xFFFDE8EC),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF5A2332)
                                  : const Color(0xFFF3C4CE),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14.sp,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF9B3046),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                  AppLocalizations.of(context)!.comingsoon,
                               
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF9B3046),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Title
                        Text(
                          AppLocalizations.of(context)!.newfeaturescomingsoon,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.onBackground
                                : const Color(0xFF6B1D2F),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 10.h),

                        // Subtitle
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Text(
                            AppLocalizations.of(context)!.comingsoondescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: isDarkMode
                                  ? Theme.of(context).colorScheme.onSurface
                                  : const Color(0xFF6B7280),
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Feature item 1: Business Profile Tools
                        _buildFeatureCard(
                          context: context,
                          isDarkMode: isDarkMode,
                          icon: Icons.business_center_rounded,
                          status: AppLocalizations.of(context)!.indevelopment,
                          title: AppLocalizations.of(
                            context,
                          )!.businessprofiletools,
                          description: AppLocalizations.of(
                            context,
                          )!.businessprofiletoolsdescription,
                        ),
                        SizedBox(height: 12.h),

                        // Feature item 2: Advanced Analytics
                        _buildFeatureCard(
                          context: context,
                          isDarkMode: isDarkMode,
                          icon: Icons.bar_chart_rounded,
                          status: AppLocalizations.of(context)!.comingq4,
                          title: AppLocalizations.of(
                            context,
                          )!.advancedanalytics,
                          description: AppLocalizations.of(
                            context,
                          )!.advancedanalyticsdescription,
                        ),
                        SizedBox(height: 12.h),

                        // Feature item 3: Growth & Promotions
                        _buildFeatureCard(
                          context: context,
                          isDarkMode: isDarkMode,
                          icon: Icons.rocket_launch_rounded,
                          status: AppLocalizations.of(context)!.planned,
                          title: AppLocalizations.of(
                            context,
                          )!.growthandpromotions,
                          description: AppLocalizations.of(
                            context,
                          )!.growthandpromotionsdescription,
                        ),
                        SizedBox(height: 12.h),

                        // VIP Early Access Dotted Box
                        _buildEarlyAccessCard(
                          context: context,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required bool isDarkMode,
    required IconData icon,
    required String status,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF222222).withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38.w,
                height: 38.h,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20.sp,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2A2E39)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onBackground
                  : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDarkMode
                  ? Theme.of(context).colorScheme.onSurface
                  : const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyAccessCard({
    required BuildContext context,
    required bool isDarkMode,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF222222).withOpacity(0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: CustomPaint(
        painter: DottedBorderPainter(
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),

          strokeWidth: 1.2,
          gap: 5,
          borderRadius: 16.r,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 16.sp,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          AppLocalizations.of(context)!.getvipearlyaccess,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.onBackground
                                : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      AppLocalizations.of(context)!.vipearlyaccessdescription,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: isDarkMode
                            ? Theme.of(context).colorScheme.onSurface
                            : const Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                    if (_isWaitlistJoined)
                      Container(
                        margin: EdgeInsets.only(top: 10.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF0F392B)
                              : const Color(0xFFD6F5E4),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF1E5E47)
                                : const Color(0xFFA2E8C4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16.sp,
                              color: const Color(0xFF00B86B),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              AppLocalizations.of(context)!.onearlyaccesslist,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: isDarkMode
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF00A86B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          await SharedPrefService.setVipWaitlistJoined(true);
                          if (mounted) {
                            setState(() {
                              _isWaitlistJoined = true;
                            });
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.only(top: 10.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.joinwaitlist,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14.sp,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
