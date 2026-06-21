// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../provider/user_provider.dart';

import '../../../api/services/validator/api_service.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../models/insights/insights_model.dart';
import '../../../widgets/custom_card.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/connection/no_internet_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.cachedInsightsData != null) {
      insightsModel = userProvider.cachedInsightsData;
      _loading = false;
    }
    _fetchData();
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

                // ── Bottom Card (unchanged) ──────────────────────────────
                CustomCard(
                  widget: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 70.h,
                        width: 70.w,
                        child: Lottie.asset(
                          Assets.images.insights,
                          repeat: true,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.insightsareavailable,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        AppLocalizations.of(context)!.trackpollvotesreactions,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showSwitchToBusinessDiolog(context, () {
                            Navigator.pop(context);
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          margin: EdgeInsets.only(top: 12.h, bottom: 10.h),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            // gradient: const LinearGradient(
                            //   colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
                            //   begin: Alignment.centerLeft,
                            //   end: Alignment.centerRight,
                            // ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.switchtobusinessaccount,
                              style: AppTextStyles.subText.copyWith(
                                fontSize: 11.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(height: 100),
              ],
            ),
    );
  }
}
