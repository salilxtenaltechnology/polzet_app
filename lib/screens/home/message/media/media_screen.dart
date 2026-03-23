// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/custom_text_styles.dart';
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          widget.memberName!,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Theme.of(context).colorScheme.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              indicator: FadeUnderlineTabIndicator(),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
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
