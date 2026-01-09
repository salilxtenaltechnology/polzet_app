// ignore_for_file: deprecated_member_use, unused_field, unrelated_type_equality_checks

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../api/app_api.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/request/incoming_request.dart';
import '../../../models/user/user_model.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<StatefulWidget> createState() {
    return NotificationState();
  }
}

class NotificationState extends State<Notifications>
    with SingleTickerProviderStateMixin, UtilityMixin {
  late TabController _tabController;
  late Future<List<IncomingData>> friendRequestsFuture;

  final _dio = Dio();
  UserModel? userModel;
  List<dynamic> incoming = [];

  Future<List<IncomingData>> getFriendRequests() async {
    final accessToken = await SharedPrefService.getAccessToken(); // ac_token
    try {
      final response = await _dio.get(
        ApiConstants.friendRequest,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.data['status'] == 'success') {
        incoming = response.data['data']['incoming'];
        return incoming.map((e) => IncomingData.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      return [];
    }
  }

  Future<void> acceptRequest(int requestId) async {
    final accessToken = await SharedPrefService.getAccessToken(); // ac_token

    var body = {'action': 'accept'};
    try {
      if (kDebugMode) {
        print('Accepting request: ${ApiConstants.acceptRequest}/$requestId');
      }
      final response = await _dio.put(
        '${ApiConstants.acceptRequest}/$requestId',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          validateStatus: (status) => status! < 500,
        ),
        data: body,
      );

      if (kDebugMode) {
        print(response);
      }

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        // Show success message
        showToast(message: 'Friend request accepted successfully!');

        // Remove the request from the list
        setState(() {
          incoming.removeWhere(
            (request) => request['sender']['id'].toString() == requestId,
          );
          //Refresh the future to update the UI
          friendRequestsFuture = getFriendRequests();
        });

        // Navigate to user profile screen
        //navigationPush(context, UserProfile());
      } else {
        throw Exception('Failed to accept request');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error accepting request: $e');
      }
      showToast(message: 'Failed to accept request try again!');
    }
  }

  String formatDateTime(String utcTime) {
    final date = DateTime.parse(utcTime).toLocal();
    final now = DateTime.now();

    final dayDifference = now.difference(date).inDays;

    String dayText;
    if (dayDifference == 0) {
      dayText = 'Today';
    } else if (dayDifference == 1) {
      dayText = 'Yesterday';
    } else if (dayDifference < 7) {
      dayText =
          'Last ${DateFormat.EEEE().format(date)}'; // EEEE = Full weekday name
    } else {
      dayText = DateFormat(
        'MMM dd, yyyy',
      ).format(date); // fallback for older dates
    }

    final timeText = DateFormat('h:mm a').format(date); // time like 9:42 AM

    return '$dayText at $timeText';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    friendRequestsFuture = getFriendRequests(); // initialize once
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              indicator: FadeUnderlineTabIndicator(),
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
              tabs: [
                Tab(text: AppLocalizations.of(context)!.all),
                Tab(text: AppLocalizations.of(context)!.poll),
                Tab(text: AppLocalizations.of(context)!.request),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Center(child: Text('All')),
                  Center(child: Text('Poll')),
                  FutureBuilder<List<IncomingData>>(
                    future: getFriendRequests(), // future method here
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Loader(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData) {
                        final requests = snapshot.data!;
                        return incoming.isEmpty
                            ? Center(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.norequestavailable,
                                  style: CustomTextStyles.lblSecondryText(
                                    context,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: requests.length,
                                itemBuilder: (context, index) {
                                  final userData = requests[index];
                                  final senderId = incoming[index]['id'];
                                  final userProvider =
                                      Provider.of<UserProvider>(context);
                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                        ),
                                        titleAlignment:
                                            ListTileTitleAlignment.top,
                                        leading:
                                            (userData.profile_picture != null &&
                                                userData
                                                    .profile_picture!
                                                    .isNotEmpty)
                                            ? CircleAvatar(
                                                backgroundImage: MemoryImage(
                                                  userProvider.getProfileImage(
                                                    userData.profile_picture,
                                                  )!,
                                                ),
                                                radius: 14.w,
                                              )
                                            : Image.asset(
                                                Assets.assetsImagesIcUser,
                                                height: 25.h,
                                                width: 25.w,
                                              ),
                                        title: RichText(
                                          text: TextSpan(
                                            style:
                                                CustomTextStyles.lblPrimaryText(
                                                  context,
                                                ),
                                            children: <TextSpan>[
                                              TextSpan(
                                                text: userData.senderUsername,
                                                style: TextStyle(
                                                  color: Color(0XFF1A1F36),
                                                  fontSize: 12.2.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    ' has requested to follow you.',
                                              ),
                                            ],
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    if (kDebugMode) {
                                                      print(senderId);
                                                    }
                                                    acceptRequest(senderId);
                                                  },
                                                  child: Container(
                                                    height: 23.h,
                                                    width: 80.w,
                                                    margin: EdgeInsets.only(
                                                      right: 12.w,
                                                      top: 7.h,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6.r,
                                                          ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Confirm',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10.2.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  height: 23.h,
                                                  width: 80.w,
                                                  margin: EdgeInsets.only(
                                                    top: 7.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6.r,
                                                        ),
                                                    border: Border.all(
                                                      color: Color(0xFFDDDEE1),
                                                      width: 1.w,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0XFF3C4257,
                                                        ),
                                                        fontSize: 10.2.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 5.h),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  formatDateTime(
                                                    userData.createdAt,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    color: Color(0XFF999999),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        thickness: 1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground
                                            .withOpacity(0.1),
                                      ),
                                    ],
                                  );
                                },
                              );
                      } else {
                        return Text('No data');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
