// ignore_for_file: deprecated_member_use, unused_field, unrelated_type_equality_checks

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../api/app_api.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../api/api_config.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/notifications/notification_model.dart';
import '../../../models/request/incoming_request.dart';
import '../../../models/user/user_model.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import 'notification_details.dart';

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
  bool _isDisposed = false;

  // Cache keys
  static const String _notificationsCacheKey = 'cached_notifications';
  static const String _friendRequestsCacheKey = 'cached_friend_requests';

  // Stream controller for notifications
  final StreamController<List<NotificationItem>> _notificationStreamController =
      StreamController<List<NotificationItem>>.broadcast();

  Timer? _refreshTimer;
  bool _isLoadingFromNetwork = false;

  final Map<String, Uint8List> _imageCache = {};
  List<NotificationItem> _lastNotifications = [];

  // Get auth headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await SharedPrefService.getAccessToken();
    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Load notifications from cache
  // Load notifications from cache
  Future<void> _loadNotificationsFromCache() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_notificationsCacheKey);

      if (_isDisposed) return; // Check after async operation

      if (cachedData != null && cachedData.isNotEmpty) {
        final Map<String, dynamic> jsonData = json.decode(cachedData);

        if (jsonData.containsKey('notifications') &&
            jsonData['notifications'] != null) {
          final notificationsResponse = NotificationsResponse.fromJson(
            jsonData,
          );
          _lastNotifications = notificationsResponse.notifications;

          // Only add if stream is not closed
          if (!_isDisposed && !_notificationStreamController.isClosed) {
            _notificationStreamController.add(_lastNotifications);
          }

          if (kDebugMode) {
            print(
              'Loaded ${notificationsResponse.notifications.length} notifications from cache',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notifications from cache: $e');
      }
      // Clear corrupted cache
      if (!_isDisposed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_notificationsCacheKey);
      }
    }
  }

  // Save notifications to cache
  Future<void> _saveNotificationsToCache(
    Map<String, dynamic> responseData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsCacheKey, json.encode(responseData));

      if (kDebugMode) {
        print('Notifications saved to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notifications to cache: $e');
      }
    }
  }

  // Load friend requests from cache
  Future<List<IncomingData>> _loadFriendRequestsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_friendRequestsCacheKey);

      if (cachedData != null) {
        final List<dynamic> jsonData = json.decode(cachedData);
        incoming = jsonData;
        final requests = jsonData.map((e) => IncomingData.fromJson(e)).toList();

        if (kDebugMode) {
          print('Loaded ${requests.length} friend requests from cache');
        }

        return requests;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading friend requests from cache: $e');
      }
    }
    return [];
  }

  // Save friend requests to cache
  Future<void> _saveFriendRequestsToCache(List<dynamic> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_friendRequestsCacheKey, json.encode(requests));

      if (kDebugMode) {
        print('Friend requests saved to cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving friend requests to cache: $e');
      }
    }
  }

  // Fetch notifications with caching
  Future<void> fetchNotifications({bool showLoader = false}) async {
    if (_isDisposed || !mounted) return;

    if (_isLoadingFromNetwork) return;

    _isLoadingFromNetwork = true;

    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        ApiConstants.notifications,
        options: Options(headers: headers),
      );

     // debugPrint('Notification response: ${response.data}');

      if (_isDisposed || !mounted) return;

      if (response.data['status'] == 'success') {
        // IMPORTANT: Check the response structure
        if (response.data['notifications'] == null) {
          debugPrint('⚠️ Notifications array is null in response');
          return;
        }

        // Save to cache
        await _saveNotificationsToCache(response.data);

        if (_isDisposed || _notificationStreamController.isClosed) return;

        try {
          // Parse with better error handling
          final notificationsResponse = NotificationsResponse.fromJson(
            response.data,
          );

          _lastNotifications = notificationsResponse.notifications;

          if (!_notificationStreamController.isClosed) {
            _notificationStreamController.add(_lastNotifications);
          }

          if (kDebugMode) {
            print(
              '✅ Successfully parsed ${notificationsResponse.notifications.length} notifications',
            );
          }
        } catch (parseError) {
          if (kDebugMode) {
            print('❌ Error parsing notifications: $parseError');
            print('Response structure: ${response.data.keys}');
            if (response.data['notifications'] != null) {
              print('First notification: ${response.data['notifications'][0]}');
            }
          }

          // Try to parse manually to identify the issue
          if (response.data['notifications'] is List) {
            final notificationsList = response.data['notifications'] as List;
            if (notificationsList.isNotEmpty) {
              final firstNotif = notificationsList[0];
              if (kDebugMode) {
                print('🔍 Checking first notification fields:');
                print(
                  '  - id: ${firstNotif['id']} (${firstNotif['id'].runtimeType})',
                );
                print(
                  '  - type: ${firstNotif['type']} (${firstNotif['type']?.runtimeType})',
                );
                print(
                  '  - message: ${firstNotif['message']} (${firstNotif['message']?.runtimeType})',
                );
                print(
                  '  - created_at: ${firstNotif['created_at']} (${firstNotif['created_at']?.runtimeType})',
                );
                print('  - actor keys: ${firstNotif['actor']?.keys}');
                print('  - post keys: ${firstNotif['post']?.keys}');
              }
            }
          }

          rethrow;
        }
      } else {
        throw Exception(
          'Failed to load notifications: ${response.data['message']}',
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error fetching notifications: $e');
        print('Stack trace: $stackTrace');
      }

      if (!_isDisposed &&
          !_notificationStreamController.isClosed &&
          _notificationStreamController.hasListener) {
        _notificationStreamController.addError(e);
      }
    } finally {
      if (!_isDisposed) {
        _isLoadingFromNetwork = false;
      }
    }
  }

  Future<List<IncomingData>> getFriendRequests() async {
    final accessToken = await SharedPrefService.getAccessToken();
    try {
      final response = await _dio.get(
        ApiConstants.friendRequest,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.data['status'] == 'success') {
        incoming = response.data['data']['incoming'];

        // Save to cache
        await _saveFriendRequestsToCache(incoming);

        return incoming.map((e) => IncomingData.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching data: $e');
      }
      // Return cached data on error
      return await _loadFriendRequestsFromCache();
    }
  }

  Future<void> acceptRequest(int requestId) async {
    final accessToken = await SharedPrefService.getAccessToken();

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
        showToast(message: 'Friend request accepted successfully!');

        setState(() {
          incoming.removeWhere(
            (request) => request['id'].toString() == requestId.toString(),
          );
          // Update cache after removing
          _saveFriendRequestsToCache(incoming);
          friendRequestsFuture = getFriendRequests();
        });
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

    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return minutes == 1 ? '1m ago' : '${minutes}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1h ago' : '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return days == 1 ? '1d ago' : '${days}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1w ago' : '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1mo ago' : '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1y ago' : '${years}y ago';
    }
  }

  String getNotificationMessage(NotificationItem notification) {
    String message = notification.message ?? '';

    if (message.isEmpty) {
      // Generate message based on type
      switch (notification.type.toUpperCase()) {
        case 'FOLLOW':
          return 'started following you';
        case 'LIKE':
          return 'liked your post';
        case 'COMMENT':
          return 'commented on your post';
        default:
          return 'sent you a notification';
      }
    }

    // Remove the username from the message (assuming actor has username field)
    // If your UserInfo model has a username field, use it:
    // message = message.replaceFirst(notification.actor.username, '').trim();

    // Otherwise, remove first word (which is the username)
    message = message.replaceFirst(RegExp(r'^\S+\s+'), '').trim();

    return message;
  }

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.index == 0 && !_tabController.indexIsChanging) {
        if (!_isLoadingFromNetwork) {
          fetchNotifications();
        }
      }
    });

    // Load cached data first (synchronously displays old data)
    _loadNotificationsFromCache().then((_) {
      // Then fetch fresh data from network
      fetchNotifications();
    });

    // Load friend requests cache, then fetch fresh data
    friendRequestsFuture = _loadFriendRequestsFromCache().then((
      cachedRequests,
    ) {
      getFriendRequests(); // Fetch in background
      return cachedRequests;
    });

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoadingFromNetwork) {
        fetchNotifications();
      }
    });
  }

  Uint8List? getUserImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;

    // Check cache first
    if (_imageCache.containsKey(imageUrl)) {
      return _imageCache[imageUrl];
    }

    try {
      String base64Data = imageUrl.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      final decoded = base64Decode(base64Data);

      // Store in cache
      _imageCache[imageUrl] = decoded;

      return decoded;
    } catch (e) {
      if (kDebugMode) {
        print('Error decoding image: $e');
      }
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _notificationStreamController.close();
    _refreshTimer?.cancel();
    _imageCache.clear();
    super.dispose();
  }

  String getInitial(String name) {
    if (name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<UserProvider>(context);

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
              labelStyle: const TextStyle(fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              indicator: FadeUnderlineTabIndicator(),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
              tabs: [
                Tab(text: AppLocalizations.of(context)!.all),
                Tab(text: AppLocalizations.of(context)!.poll),
                //  Tab(text: AppLocalizations.of(context)!.request),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // All Notifications Tab
                  RefreshIndicator(
                    onRefresh: fetchNotifications,
                    child: StreamBuilder<List<NotificationItem>>(
                      stream: _notificationStreamController.stream,
                      initialData: _lastNotifications.isNotEmpty
                          ? _lastNotifications
                          : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            (!snapshot.hasData ||
                                snapshot.data == null ||
                                snapshot.data!.isEmpty)) {
                          return Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                        // Show cached data immediately, even while loading
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final notifications = snapshot.data!;
                          return ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final post = notification.post;
                              return GestureDetector(
                                onTap: () {
                                  if (post != null) {
                                    navigationPush(
                                      context,
                                      NotificationDetails(postId: post.postId),
                                    );
                                  } else if (notification.type == 'FOLLOW') {
                                    // Navigate to user profile for follow notifications
                                    // navigationPush(context, UserProfile(userId: notification.actor.userId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Follow notification'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Post not available'),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(0, 5.h, 0, 0),
                                  padding: EdgeInsets.fromLTRB(0, 5.h, 0, 5.h),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      // Avatar
                                      (notification.actor.avatarUrl != null &&
                                              notification
                                                  .actor
                                                  .avatarUrl!
                                                  .isNotEmpty)
                                          ? CircleAvatar(
                                              backgroundImage: MemoryImage(
                                                getUserImage(
                                                  notification.actor.avatarUrl,
                                                )!,
                                              ),
                                              radius: 17.w,
                                              onBackgroundImageError:
                                                  (exception, stackTrace) {
                                                    if (kDebugMode) {
                                                      print(
                                                        'Error loading avatar: $exception',
                                                      );
                                                    }
                                                  },
                                            )
                                          : CircleAvatar(
                                              radius: 17.w,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.15),
                                              child: Text(
                                                getInitial(
                                                  notification.actor.name,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                      SizedBox(width: 8.w),

                                      // Notification text - ONLY NAME, NO USERNAME
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                style:
                                                    CustomTextStyles.lblPrimaryText(
                                                      context,
                                                    ),
                                                children: <TextSpan>[
                                                  // Only show name (first + last name)
                                                  TextSpan(
                                                    text:
                                                        notification.actor.name,
                                                    style: TextStyle(
                                                      color: const Color(
                                                        0XFF1A1F36,
                                                      ),
                                                      fontSize: 12.2.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  // Show the custom notification message
                                                  TextSpan(
                                                    text:
                                                        ' ${getNotificationMessage(notification)}',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: const Color(
                                                        0XFF1A1F36,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              formatDateTime(
                                                notification.createdAt
                                                    .toString(),
                                              ),
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                color: const Color(0XFF999999),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Post image - only show if post exists and has image
                                      if (post != null &&
                                          post.imageUrl.isNotEmpty)
                                        Container(
                                          width: 35.w,
                                          height: 30.h,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                '${ApiConfig.baseUrlImage}${post.imageUrl}',
                                              ),
                                              fit: BoxFit.cover,
                                              onError: (exception, stackTrace) {
                                                if (kDebugMode) {
                                                  print(
                                                    'Error loading post image: $exception',
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        } else if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        } else if (snapshot.hasError &&
                            (!snapshot.hasData ||
                                snapshot.data == null ||
                                snapshot.data!.isEmpty)) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Error loading notifications'),
                                SizedBox(height: 16.h),
                                ElevatedButton(
                                  onPressed: fetchNotifications,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Center(
                            child: Text(
                              'No notifications available',
                              style: CustomTextStyles.lblSecondryText(context),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  // Poll Tab
                  const Center(child: Text('Poll')),
                  // Request Tab
                  // FutureBuilder<List<IncomingData>>(
                  //   future: friendRequestsFuture,
                  //   builder: (context, snapshot) {
                  //     if (snapshot.connectionState == ConnectionState.waiting &&
                  //         (!snapshot.hasData || snapshot.data!.isEmpty)) {
                  //       return Center(
                  //         child: Loader(
                  //           color: Theme.of(context).colorScheme.primary,
                  //         ),
                  //       );
                  //     } else if (snapshot.hasError && !snapshot.hasData) {
                  //       return Text('Error: ${snapshot.error}');
                  //     } else if (snapshot.hasData) {
                  //       final requests = snapshot.data!;
                  //       return incoming.isEmpty
                  //           ? Center(
                  //               child: Text(
                  //                 AppLocalizations.of(
                  //                   context,
                  //                 )!.norequestavailable,
                  //                 style: CustomTextStyles.lblSecondryText(
                  //                   context,
                  //                 ),
                  //               ),
                  //             )
                  //           : ListView.builder(
                  //               itemCount: requests.length,
                  //               itemBuilder: (context, index) {
                  //                 final userData = requests[index];
                  //                 final senderId = incoming[index]['id'];
                  //                 return Column(
                  //                   children: [
                  //                     ListTile(
                  //                       contentPadding: EdgeInsets.symmetric(
                  //                         horizontal: 12.w,
                  //                       ),
                  //                       titleAlignment:
                  //                           ListTileTitleAlignment.top,
                  //                       leading:
                  //                           (userData.profile_picture != null &&
                  //                               userData
                  //                                   .profile_picture!
                  //                                   .isNotEmpty)
                  //                           ? CircleAvatar(
                  //                               backgroundImage: MemoryImage(
                  //                                 userProvider.getProfileImage(
                  //                                   userData.profile_picture,
                  //                                 )!,
                  //                               ),
                  //                               radius: 14.w,
                  //                             )
                  //                           : Image.asset(
                  //                               Assets.assetsImagesIcUser,
                  //                               height: 25.h,
                  //                               width: 25.w,
                  //                             ),
                  //                       title: RichText(
                  //                         text: TextSpan(
                  //                           style:
                  //                               CustomTextStyles.lblPrimaryText(
                  //                                 context,
                  //                               ),
                  //                           children: <TextSpan>[
                  //                             TextSpan(
                  //                               text: userData.senderUsername,
                  //                               style: TextStyle(
                  //                                 color: const Color(
                  //                                   0XFF1A1F36,
                  //                                 ),
                  //                                 fontSize: 12.2.sp,
                  //                                 fontWeight: FontWeight.w600,
                  //                               ),
                  //                             ),
                  //                             const TextSpan(
                  //                               text:
                  //                                   ' has requested to follow you.',
                  //                             ),
                  //                           ],
                  //                         ),
                  //                       ),
                  //                       subtitle: Column(
                  //                         crossAxisAlignment:
                  //                             CrossAxisAlignment.start,
                  //                         children: [
                  //                           Row(
                  //                             mainAxisAlignment:
                  //                                 MainAxisAlignment.start,
                  //                             children: [
                  //                               GestureDetector(
                  //                                 onTap: () {
                  //                                   if (kDebugMode) {
                  //                                     print(senderId);
                  //                                   }
                  //                                   acceptRequest(senderId);
                  //                                 },
                  //                                 child: Container(
                  //                                   height: 23.h,
                  //                                   width: 80.w,
                  //                                   margin: EdgeInsets.only(
                  //                                     right: 12.w,
                  //                                     top: 7.h,
                  //                                   ),
                  //                                   decoration: BoxDecoration(
                  //                                     color: Theme.of(
                  //                                       context,
                  //                                     ).colorScheme.primary,
                  //                                     borderRadius:
                  //                                         BorderRadius.circular(
                  //                                           6.r,
                  //                                         ),
                  //                                   ),
                  //                                   child: Center(
                  //                                     child: Text(
                  //                                       'Confirm',
                  //                                       style: TextStyle(
                  //                                         color: Colors.white,
                  //                                         fontSize: 10.2.sp,
                  //                                         fontWeight:
                  //                                             FontWeight.w600,
                  //                                       ),
                  //                                     ),
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                               Container(
                  //                                 height: 23.h,
                  //                                 width: 80.w,
                  //                                 margin: EdgeInsets.only(
                  //                                   top: 7.h,
                  //                                 ),
                  //                                 decoration: BoxDecoration(
                  //                                   color: Colors.transparent,
                  //                                   borderRadius:
                  //                                       BorderRadius.circular(
                  //                                         6.r,
                  //                                       ),
                  //                                   border: Border.all(
                  //                                     color: const Color(
                  //                                       0xFFDDDEE1,
                  //                                     ),
                  //                                     width: 1.w,
                  //                                   ),
                  //                                 ),
                  //                                 child: Center(
                  //                                   child: Text(
                  //                                     'Delete',
                  //                                     style: TextStyle(
                  //                                       color: const Color(
                  //                                         0XFF3C4257,
                  //                                       ),
                  //                                       fontSize: 10.2.sp,
                  //                                       fontWeight:
                  //                                           FontWeight.w600,
                  //                                     ),
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                             ],
                  //                           ),
                  //                           SizedBox(height: 5.h),
                  //                           Row(
                  //                             mainAxisAlignment:
                  //                                 MainAxisAlignment.end,
                  //                             children: [
                  //                               Text(
                  //                                 formatDateTime(
                  //                                   userData.createdAt,
                  //                                 ),
                  //                                 style: TextStyle(
                  //                                   fontSize: 9.sp,
                  //                                   color: const Color(
                  //                                     0XFF999999,
                  //                                   ),
                  //                                 ),
                  //                               ),
                  //                             ],
                  //                           ),
                  //                         ],
                  //                       ),
                  //                     ),
                  //                     Divider(
                  //                       thickness: 1,
                  //                       color: Theme.of(context)
                  //                           .colorScheme
                  //                           .onBackground
                  //                           .withOpacity(0.1),
                  //                     ),
                  //                   ],
                  //                 );
                  //               },
                  //             );
                  //     } else {
                  //       return const Text('No data');
                  //     }
                  //   },
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
