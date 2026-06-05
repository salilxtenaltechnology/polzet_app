// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/tabbar/indicatore_animation.dart';

class MediaScreen extends StatefulWidget {
  String? memberName;
  MediaScreen({super.key, required this.memberName});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: widget.memberName!),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
               labelColor: Theme.of(context).colorScheme.onBackground,
              labelStyle: AppTextStyles.bodyText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
              dividerColor: Colors.transparent,
              indicator: FadeUnderlineTabIndicator(),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              unselectedLabelColor: const Color(0XFF8E8E8E),
              tabs: [
                Tab(text: AppLocalizations.of(context)!.media),
                Tab(text: AppLocalizations.of(context)!.link),
                Tab(text: AppLocalizations.of(context)!.document),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.nomedia),
                      Text(AppLocalizations.of(context)!.mediasharedinthischatwillappearhere),
                    ],
                  )),
                  Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.nolinks),
                        Text(AppLocalizations.of(context)!.linkssharedinthischatwillappearhere),
                    ],
                  )),
                  Center(child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.nodocuments),
                      Text(AppLocalizations.of(context)!.docssharedinthischatwillappearhere), 
                    ],
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
