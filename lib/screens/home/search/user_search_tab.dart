//  TabBar(
// overlayColor: WidgetStatePropertyAll(Colors.transparent),
// tabAlignment: TabAlignment.fill,
// indicator: FadeUnderlineTabIndicator(),
// controller: _tabController,
// labelPadding: EdgeInsets.symmetric(horizontal: 5.w),
// indicatorSize: TabBarIndicatorSize.tab,
// labelColor: Theme.of(context).colorScheme.primary,
// labelStyle: TextStyle(
//     color: Theme.of(context).colorScheme.onBackground,
//     fontSize: 11.sp,
//     fontWeight: FontWeight.w400),
// dividerColor: Colors.transparent,
// unselectedLabelColor:
//     Theme.of(context).colorScheme.onBackground,
//                 tabs: [
//                   Tab(text: 'Top'),
//                   Tab(text: 'Accounts'),
//                   Tab(text: 'Photos'),
//                   Tab(text: 'Tags'),
//                   Tab(text: 'Places'),
//                 ],
//               ),
//             ),
//             Visibility(
//               visible: _isShowTab,
//               child: Expanded(
//                 child: TabBarView(
//                   controller: _tabController,
//                   children: [
//                     // top
//                     Column(
//                       children: [
//                         Padding(
//                           padding: EdgeInsets.all(5).w,
//                           child: CustomCard(
//                               widget: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   SizedBox(
//                                       height: 25.h,
//                                       width: 25.w,
//                                       child: Image.asset(
//                                           Assets.assetsImagesIcUser)),
//                                   SizedBox(width: 10.w),
//                                   Text('Top'),
//                                   Spacer(),
//                                   Icon(Icons.more_vert, size: 20.spMax)
//                                 ],
//                               ),
//                               SizedBox(height: 7.h),
//                               Text('You have a new polls from jack!',
//                                   style: TextStyle(
//                                       color: Theme.of(context)
//                                           .colorScheme
//                                           .onBackground,
//                                       fontSize: 13.sp,
//                                       fontWeight: FontWeight.w600)),
//                               Text('5 minutes ago',
//                                   style: TextStyle(
//                                       fontSize: 10.5.sp,
//                                       color: Color(0XFF999999)))
//                             ],
//                           )),
//                         ),
//                       ],
//                     ),
//                     // accounts
//                     Column(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.all(5).w,
//                           child:
//             CustomCard(
//                               widget: Row(
//                             children: [
//                               Icon(Icons.account_box_rounded,
//                                   color: AppColors.primaryColor,
//                                   size: 30.spMax),
//                               SizedBox(width: 12.w),
//                               GestureDetector(
//                                 onTap: () {
//                                   // navigationPush(context, UserProfile());
//                                 },
//                                 child: Text(
//                                   'User Name',
//                                   style:
//                                       CustomTextStyles.lblSecondryText(context),
//                                 ),
//                               ),
//                               Spacer(),
//                               _buttonEvent(Color(0XFFC8FEC5),
//                                   Assets.assetsImagesIcFollow,
//                                   onTap: () {}),
//                               SizedBox(width: 5.w),
//                               _buttonEvent(
//                                   Color(0XFFD1E0FF), Assets.assetsImagesIcGroup,
//                                   onTap: () {
//                                 navigationPush(context, AddMember());
//                               }),
//                               SizedBox(width: 5.w),
//                               _buttonEvent(
//                                   Color(0XFFFFEAEA), Assets.assetsImagesIcBlock,
//                                   onTap: () {
//                                 _showBlockSheet(context);
//                               }),
//                             ],
//                           )),
//                         ),
//                       ],
//                     ),
//                     // photos
//                     Column(
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Image.asset(Assets.assetsImagesPost1,
//                                 height: 80.h, width: 80.w),
//                             Image.asset(Assets.assetsImagesPost1,
//                                 height: 80.h, width: 80.w),
//                             Image.asset(Assets.assetsImagesPost1,
//                                 height: 80.h, width: 80.w),
//                             Image.asset(Assets.assetsImagesPost1,
//                                 height: 80.h, width: 80.w),
//                           ],
//                         ),
//                       ],
//                     ),
//                     // tags
//                     Column(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.all(5).w,
//                           child: CustomCard(
//                               widget: Row(
//                             children: [
//                               Container(
//                                 height: 30.h,
//                                 width: 30.w,
//                                 decoration: BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     border: Border.all(
//                                         color: Color(0XFFF0ECEC), width: 1.5)),
//                                 child: Center(
//                                     child: Icon(Icons.tag,
//                                         size: 20,
//                                         color: Theme.of(context)
//                                             .colorScheme
//                                             .onBackground)),
//                               ),
//                               SizedBox(width: 7.w),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     '#Food',
//                                     style: CustomTextStyles.lblPrimaryText(
//                                         context),
//                                   ),
//                                   Text('5.1M Polls',
//                                       style: TextStyle(
//                                           fontSize: 11.sp,
//                                           color: Color(0XFF999999))),
//                                 ],
//                               )
//                             ],
//                           )),
//                         ),
//                       ],
//                     ),
//                     // places
//                     Column(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.all(5).w,
//                           child: CustomCard(
//                               widget: Row(
//                             children: [
//                               Container(
//                                 height: 30.h,
//                                 width: 30.w,
//                                 decoration: BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     border: Border.all(
//                                         color: Color(0XFFF0ECEC), width: 1.5)),
//                                 child: Center(
//                                     child: Icon(Icons.location_on_outlined,
//                                         size: 20,
//                                         color: Theme.of(context)
//                                             .colorScheme
//                                             .onBackground)),
//                               ),
//                               SizedBox(width: 7.w),
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Places',
//                                     style: CustomTextStyles.lblPrimaryText(
//                                         context),
//                                   ),
//                                   // SizedBox(height: 5.h),
//                                   Text('Places',
//                                       style: TextStyle(
//                                           fontSize: 11.sp,
//                                           color: Color(0XFF999999))),
//                                 ],
//                               )
//                             ],
//                           )),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
