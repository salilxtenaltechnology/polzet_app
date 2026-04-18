// ignore_for_file: deprecated_member_use, unused_field, unrelated_type_equality_checks

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../api/app_api.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../provider/user_provider.dart';
import '../../../api/api_config.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
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

  // Pagination variables
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _nextPageUrl;
  final ScrollController _allNotificationsScrollController = ScrollController();
  final ScrollController _pollNotificationsScrollController = ScrollController();

  // ── Auth headers ──────────────────────────────────────────────────────────

  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await SharedPrefService.getToken();
    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<void> _loadNotificationsFromCache() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_notificationsCacheKey);

      if (_isDisposed) return;

      if (cachedData != null && cachedData.isNotEmpty) {
        final Map<String, dynamic> jsonData = json.decode(cachedData);

        if (jsonData.containsKey('notifications') &&
            jsonData['notifications'] != null) {
          final notificationsResponse = NotificationsResponse.fromJson(jsonData);
          _lastNotifications = notificationsResponse.notifications;

          if (!_isDisposed && !_notificationStreamController.isClosed) {
            _notificationStreamController.add(_lastNotifications);
          }

          // if (kDebugMode) {
          //   print('Loaded ${notificationsResponse.notifications.length} notifications from cache');
          // }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading notifications from cache: $e');
      if (!_isDisposed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_notificationsCacheKey);
      }
    }
  }

  Future<void> _saveNotificationsToCache(Map<String, dynamic> responseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsCacheKey, json.encode(responseData));
    } catch (e) {
      if (kDebugMode) print('Error saving notifications to cache: $e');
    }
  }

  Future<List<IncomingData>> _loadFriendRequestsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_friendRequestsCacheKey);

      if (cachedData != null) {
        final List<dynamic> jsonData = json.decode(cachedData);
        incoming = jsonData;
        final requests = jsonData.map((e) => IncomingData.fromJson(e)).toList();
        // if (kDebugMode) print('Loaded ${requests.length} friend requests from cache');
        return requests;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading friend requests from cache: $e');
    }
    return [];
  }

  Future<void> _saveFriendRequestsToCache(List<dynamic> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_friendRequestsCacheKey, json.encode(requests));
      // if (kDebugMode) print('Friend requests saved to cache');
    } catch (e) {
      if (kDebugMode) print('Error saving friend requests to cache: $e');
    }
  }

  // ── Network fetches ───────────────────────────────────────────────────────

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

      if (_isDisposed || !mounted) return;

      if (response.data['status'] == 'success') {
        if (response.data['notifications'] == null) {
          debugPrint('⚠️ Notifications array is null in response');
          return;
        }

        await _saveNotificationsToCache(response.data);

        if (_isDisposed || _notificationStreamController.isClosed) return;

        try {
          final notificationsResponse = NotificationsResponse.fromJson(response.data);
          _lastNotifications = notificationsResponse.notifications;
          _nextPageUrl = response.data['next'];
          _hasMoreData = _nextPageUrl != null;

          if (!_notificationStreamController.isClosed) {
            _notificationStreamController.add(_lastNotifications);
          }
        } catch (parseError) {
          if (kDebugMode) {
            print('❌ Error parsing notifications: $parseError');
            print('Response structure: ${response.data.keys}');
            if (response.data['notifications'] != null) {
              print('First notification: ${response.data['notifications'][0]}');
            }
          }
          rethrow;
        }
      } else {
        throw Exception('Failed to load notifications: ${response.data['message']}');
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
      if (!_isDisposed) _isLoadingFromNetwork = false;
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMoreData || _nextPageUrl == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get(
        _nextPageUrl!,
        options: Options(headers: headers),
      );

      if (response.data['status'] == 'success') {
        final notificationsResponse = NotificationsResponse.fromJson(response.data);
        _lastNotifications.addAll(notificationsResponse.notifications);
        _nextPageUrl = response.data['next'];
        _hasMoreData = _nextPageUrl != null;

        if (!_notificationStreamController.isClosed) {
          _notificationStreamController.add(_lastNotifications);
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading more notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Scroll listeners ──────────────────────────────────────────────────────

  void _onAllNotificationsScroll() {
    if (_allNotificationsScrollController.position.pixels >=
            _allNotificationsScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreNotifications();
    }
  }

  void _onPollNotificationsScroll() {
    if (_pollNotificationsScrollController.position.pixels >=
            _pollNotificationsScrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreNotifications();
    }
  }

  // ── Friend requests ───────────────────────────────────────────────────────

  Future<List<IncomingData>> getFriendRequests() async {
    final accessToken = await SharedPrefService.getToken();
    try {
      final response = await _dio.get(
        ApiConstants.friendRequest,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.data['status'] == 'success') {
        incoming = response.data['data']['incoming'];
        await _saveFriendRequestsToCache(incoming);
        return incoming.map((e) => IncomingData.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching data: $e');
      return await _loadFriendRequestsFromCache();
    }
  }

  Future<void> acceptRequest(int requestId) async {
    final accessToken = await SharedPrefService.getToken();
    var body = {'action': 'accept'};
    try {
      if (kDebugMode) print('Accepting request: ${ApiConstants.acceptRequest}/$requestId');
      final response = await _dio.put(
        '${ApiConstants.acceptRequest}/$requestId',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          validateStatus: (status) => status! < 500,
        ),
        data: body,
      );

      if (kDebugMode) print(response);

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        showToast(message: 'Friend request accepted successfully!');
        setState(() {
          incoming.removeWhere(
            (request) => request['id'].toString() == requestId.toString(),
          );
          _saveFriendRequestsToCache(incoming);
          friendRequestsFuture = getFriendRequests();
        });
      } else {
        throw Exception('Failed to accept request');
      }
    } catch (e) {
      if (kDebugMode) print('Error accepting request: $e');
      showToast(message: 'Failed to accept request try again!');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String formatDateTime(String utcTime) {
    final date = DateTime.parse(utcTime).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return '${difference.inSeconds}s';
    if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return m == 1 ? '1m ago' : '${m}m ago';
    }
    if (difference.inHours < 24) {
      final h = difference.inHours;
      return h == 1 ? '1h ago' : '${h}h ago';
    }
    if (difference.inDays < 7) {
      final d = difference.inDays;
      return d == 1 ? '1d ago' : '${d}d ago';
    }
    if (difference.inDays < 30) {
      final w = (difference.inDays / 7).floor();
      return w == 1 ? '1w ago' : '${w}w ago';
    }
    if (difference.inDays < 365) {
      final mo = (difference.inDays / 30).floor();
      return mo == 1 ? '1mo ago' : '${mo}mo ago';
    }
    final y = (difference.inDays / 365).floor();
    return y == 1 ? '1y ago' : '${y}y ago';
  }

  String getNotificationMessage(NotificationItem notification) {
    switch (notification.type.toUpperCase()) {
      case 'FOLLOW':
        return 'started chasing you';
      case 'LIKE':
        return 'liked your post';
      case 'COMMENT':
        final message = notification.message ?? '';
        if (message.contains('commented on your post: ')) {
          final commentText = message.split('commented on your post: ').last;
          return 'commented on your post: $commentText';
        }
        return 'commented on your post';
      case 'VOTE':
        return 'voted on your poll';
      default:
        return 'sent you a notification';
    }
  }

  Uint8List? getUserImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (_imageCache.containsKey(imageUrl)) return _imageCache[imageUrl];

    try {
      final base64Data = imageUrl.replaceFirst(
        RegExp(r'data:image/[^;]+;base64,'),
        '',
      );
      final decoded = base64Decode(base64Data);
      _imageCache[imageUrl] = decoded;
      return decoded;
    } catch (e) {
      if (kDebugMode) print('Error decoding image: $e');
      return null;
    }
  }

  String getInitial(String name) {
    if (name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.index == 0 && !_tabController.indexIsChanging) {
        if (!_isLoadingFromNetwork) fetchNotifications();
      }
    });

    _allNotificationsScrollController.addListener(_onAllNotificationsScroll);
    _pollNotificationsScrollController.addListener(_onPollNotificationsScroll);

    _loadNotificationsFromCache().then((_) => fetchNotifications());

    friendRequestsFuture = _loadFriendRequestsFromCache().then((cachedRequests) {
      getFriendRequests();
      return cachedRequests;
    });

    // Periodic silent refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoadingFromNetwork) fetchNotifications();
    });
    // ✅ No connectivity listener — ConnectivityOverlay handles UI globally
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _notificationStreamController.close();
    _refreshTimer?.cancel();
    _imageCache.clear();
    _allNotificationsScrollController.dispose();
    _pollNotificationsScrollController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              ],
            ),
            Expanded(
              child: TabBarView(
                
                controller: _tabController,
                children: [
                  // ── All Notifications Tab ────────────────────────────
                  RefreshIndicator(
                    onRefresh: () async {
                      _hasMoreData = true;
                      _nextPageUrl = null;
                      await fetchNotifications();
                    },
                    child: StreamBuilder<List<NotificationItem>>(
                      stream: _notificationStreamController.stream,
                      initialData: _lastNotifications.isNotEmpty
                          ? _lastNotifications
                          : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            (!snapshot.hasData ||
                                snapshot.data == null ||
                                snapshot.data!.isEmpty)) {
                          return Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }

                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final notifications = snapshot.data!;
                          return ListView.builder(
                            controller: _allNotificationsScrollController,
                            itemCount:
                                notifications.length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == notifications.length) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.h),
                                    child: _isLoadingMore
                                        ? Loader(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }

                              final notification = notifications[index];
                              final post = notification.post;
                              return _buildNotificationTile(
                                notification: notification,
                                post: post,
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

                  // ── Poll Notifications Tab ───────────────────────────
                  RefreshIndicator(
                    onRefresh: () async {
                      _hasMoreData = true;
                      _nextPageUrl = null;
                      await fetchNotifications();
                    },
                    child: StreamBuilder<List<NotificationItem>>(
                      stream: _notificationStreamController.stream,
                      initialData: _lastNotifications.isNotEmpty
                          ? _lastNotifications
                          : null,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            (!snapshot.hasData ||
                                snapshot.data == null ||
                                snapshot.data!.isEmpty)) {
                          return Center(
                            child: Loader(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }

                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final voteNotifications = snapshot.data!
                              .where((n) => n.type == 'VOTE')
                              .toList();

                          if (voteNotifications.isEmpty) {
                            return Center(
                              child: Text(
                                'No vote notifications available',
                                style: CustomTextStyles.lblSecondryText(context),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _pollNotificationsScrollController,
                            itemCount:
                                voteNotifications.length +
                                (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == voteNotifications.length) {
                                return Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.h),
                                    child: _isLoadingMore
                                        ? Loader(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                );
                              }

                              final notification = voteNotifications[index];
                              final post = notification.post;
                              return _buildNotificationTile(
                                notification: notification,
                                post: post,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared notification tile ──────────────────────────────────────────────

  Widget _buildNotificationTile({
    required NotificationItem notification,
    required dynamic post,
  }) {
    return GestureDetector(
      onTap: () {
        if (post != null) {
          navigationPush(context, NotificationDetails(postId: post.postId));
        } else if (notification.type == 'FOLLOW') {
          navigationPush(
            context,
            PublicProfile(userId: notification.actor.userId),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post not available')),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(0, 5.h, 0, 0),
        padding: EdgeInsets.fromLTRB(0, 5.h, 0, 5.h),
        color: Colors.transparent,
        child: Row(
          children: [
            (notification.actor.avatarUrl != null &&
                    notification.actor.avatarUrl!.isNotEmpty)
                ? CircleAvatar(
                    backgroundImage: MemoryImage(
                      getUserImage(notification.actor.avatarUrl)!,
                    ),
                    radius: 17.w,
                    onBackgroundImageError: (exception, stackTrace) {
                      if (kDebugMode) print('Error loading avatar: $exception');
                    },
                  )
                : CircleAvatar(
                    radius: 17.w,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.15),
                    child: Text(
                      getInitial(notification.actor.name),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: CustomTextStyles.lblPrimaryText(context),
                      children: <TextSpan>[
                        TextSpan(
                          text: notification.actor.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 12.2.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' ${getNotificationMessage(notification)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    formatDateTime(notification.createdAt.toString()),
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (post != null && post.imageUrl.isNotEmpty)
              Container(
                width: 35.w,
                height: 30.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  image: DecorationImage(
                    image: NetworkImage(
                      '${ApiConfig.baseUrlImage}${post.imageUrl}',
                    ),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      if (kDebugMode) {
                        print('Error loading post image: $exception');
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}