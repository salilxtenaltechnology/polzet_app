// ignore_for_file: deprecated_member_use

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../api/services/api_service.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../models/insights/insights_model.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/dialog/custom_diolog.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _apiService.getInsightsData();
      setState(() {
        insightsModel = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        title: Text(
          AppLocalizations.of(context)!.insights,
          style: CustomTextStyles.appBarTitleText(context),
        ),
      ),
      body: _loading
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Total Views ──────────────────────────────────────────
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.bar_chart, color: Colors.pink),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.totalviews,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.totalViews.toString() ?? '0',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // ── Chasers (Vibe) ───────────────────────────────────────
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.people, color: Colors.orange),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.vibe,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.chasers.toString() ?? '0',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 7.h),

                // ── Polls Created ────────────────────────────────────────
                CustomCard(
                  widget: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.green),
                      SizedBox(width: 7.w),
                      Text(
                        AppLocalizations.of(context)!.pollcreated,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        insightsModel?.pollsCreated.toString() ?? '0',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),

                // ── Line Chart ───────────────────────────────────────────
                if (insightsModel != null && insightsModel!.recent.isNotEmpty)
                  CustomCard(
                    widget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.weeklyviews,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12.h),
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
                                      style: TextStyle(fontSize: 9.sp),
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
                                          style: TextStyle(fontSize: 9.sp),
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
                                    gradient: const LinearGradient(
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
                                      const TextStyle(
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        AppLocalizations.of(context)!.trackpollvotesreactions,
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
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
                              style: TextStyle(
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
              ],
            ),
    );
  }
}
