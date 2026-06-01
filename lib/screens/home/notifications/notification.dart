// ignore_for_file: deprecated_member_use, unused_field, unrelated_type_equality_checks

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../api/app_api.dart';
import '../../../../api/services/api_service.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../provider/user_provider.dart';
import '../../../../provider/private_chat_provider.dart';
import '../../../../provider/group_chat_provider.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/notifications/notification_model.dart';
import '../../../models/request/incoming_request.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/button/request/friend_request_button.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/tabbar/indicatore_animation.dart';
import '../message/chat/group/group_chat_screen.dart';
import '../message/chat/private/private_chat_screen.dart';
import '../profile/public/public_profile_screen.dart';
import '../search/posts/single_post_details.dart';
import 'poll_vote_notification_tile.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<StatefulWidget> createState() {
    return NotificationState();
  }
}

class NotificationState extends State<Notifications>
    with TickerProviderStateMixin, UtilityMixin {
  late TabController _tabController;
  bool? _lastIsPrivate;
  late Future<List<IncomingData>> friendRequestsFuture;

  final _dio = Dio();

  List<dynamic> incoming = [];
  bool _isDisposed = false;
  int _currentPage = 1;

  static const String _notificationsCacheKey = 'cached_notifications';
  static const String _friendRequestsCacheKey = 'cached_friend_requests';

  static final ValueNotifier<int> unreadNotificationCount = ValueNotifier<int>(
    0,
  );
  static Timer? _globalPollingTimer;
  static List<NotificationItem> globalCachedNotifications = [];

  static void startGlobalPolling() {
    if (_globalPollingTimer != null) return;
    _fetchUnreadCountGlobally();
    _globalPollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchUnreadCountGlobally(),
    );
  }

  static void stopGlobalPolling() {
    _globalPollingTimer?.cancel();
    _globalPollingTimer = null;
  }

  static Future<void> _fetchUnreadCountGlobally() async {
    try {
      final dio = Dio();
      final accessToken = await SharedPrefService.getToken();
      final headers = {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final response = await dio.get(
        ApiConstants.notifications,
        options: Options(headers: headers),
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (responseData is Map && responseData['results'] != null) {
        final notificationsResponse = NotificationsResponse.fromJson(
          Map<String, dynamic>.from(responseData),
        );
        globalCachedNotifications = List<NotificationItem>.from(
          notificationsResponse.results,
        );
        int unreadCount = globalCachedNotifications
            .where((n) => !n.isRead)
            .length;
        unreadNotificationCount.value = unreadCount;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching global notification count: $e');
      }
    }
  }

  final StreamController<List<NotificationItem>> _notificationStreamController =
      StreamController<List<NotificationItem>>.broadcast();

  late List<NotificationItem> _lastNotifications = List.from(
    globalCachedNotifications,
  );

  final Map<String, Uint8List> _imageCache = {};
  final ScrollController _allNotificationsScrollController = ScrollController();
  final ScrollController _pollNotificationsScrollController =
      ScrollController();

  bool _isLoadingFromNetwork = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _nextPageUrl;

  Timer? _refreshTimer;

  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await SharedPrefService.getToken();
    return {
      'Authorization': 'Bearer ${accessToken ?? ''}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<void> _loadNotificationsFromCache() async {
    if (_isDisposed) return;
    try {
      if (_lastNotifications.isNotEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_notificationsCacheKey);
      if (_isDisposed) return;

      if (cachedData != null && cachedData.isNotEmpty) {
        final decoded = json.decode(cachedData);

        if (decoded is Map && decoded['results'] != null) {
          final notificationsResponse = NotificationsResponse.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          _lastNotifications = notificationsResponse.results;

          if (!_isDisposed && !_notificationStreamController.isClosed) {
            _notificationStreamController.add(_lastNotifications);
          }
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

  Future<void> _saveNotificationsToCache(
    List<NotificationItem> notifications,
    Map<dynamic, dynamic> rawResponse,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reconstruct a cache-friendly map that mirrors the API shape so
      // _loadNotificationsFromCache can call NotificationsResponse.fromJson().
      final Map<String, dynamic> cacheMap = {
        'count': rawResponse['count'] ?? notifications.length,
        'unread_count': rawResponse['unread_count'] ?? 0,
        'page': rawResponse['page'] ?? 1,
        'has_more': rawResponse['has_more'] ?? false,
        // Use toJson() on every item so poll_details are included.
        'results': notifications.map((n) => n.toJson()).toList(),
      };
      await prefs.setString(_notificationsCacheKey, json.encode(cacheMap));
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
    } catch (e) {
      if (kDebugMode) print('Error saving friend requests to cache: $e');
    }
  }

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

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (responseData is Map && responseData['results'] != null) {
        final notificationsResponse = NotificationsResponse.fromJson(
          Map<String, dynamic>.from(responseData),
        );

        // Build a NEW list — never mutate the existing one so StreamBuilder
        // always receives a different reference and triggers a rebuild.
        final List<NotificationItem> freshList = List<NotificationItem>.from(
          notificationsResponse.results,
        );

        // Persist using model toJson() so poll_details are cached.
        await _saveNotificationsToCache(freshList, responseData);

        if (_isDisposed || _notificationStreamController.isClosed) return;

        _lastNotifications = freshList;
        globalCachedNotifications = List.from(freshList);
        _hasMoreData = notificationsResponse.hasMore;
        _currentPage = notificationsResponse.page;

        unreadNotificationCount.value = _lastNotifications
            .where((n) => !n.isRead)
            .length;

        if (!_notificationStreamController.isClosed) {
          _notificationStreamController.add(
            List<NotificationItem>.from(_lastNotifications),
          );
        }
      } else {
        debugPrint('⚠️ Results array is null in response');
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
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      final headers = await _getAuthHeaders();
      final nextPage = _currentPage + 1;

      final response = await _dio.get(
        '${ApiConstants.notifications}?page=$nextPage',
        options: Options(headers: headers),
      );

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (responseData is Map && responseData['results'] != null) {
        final notificationsResponse = NotificationsResponse.fromJson(
          Map<String, dynamic>.from(responseData),
        );

        // Create a NEW list so StreamBuilder detects the change.
        final List<NotificationItem> merged = [
          ..._lastNotifications,
          ...notificationsResponse.results,
        ];

        _lastNotifications = merged;
        globalCachedNotifications = List.from(merged);
        _hasMoreData = notificationsResponse.hasMore;
        _currentPage = notificationsResponse.page;

        // Persist merged list.
        await _saveNotificationsToCache(merged, {
          'count': merged.length,
          'unread_count': merged.where((n) => !n.isRead).length,
          'page': _currentPage,
          'has_more': _hasMoreData,
        });

        unreadNotificationCount.value = _lastNotifications
            .where((n) => !n.isRead)
            .length;

        if (!_notificationStreamController.isClosed) {
          _notificationStreamController.add(
            List<NotificationItem>.from(_lastNotifications),
          );
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

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (responseData is Map && responseData['status'] == 'success') {
        final List<dynamic> rawIncoming = responseData['data']?['incoming'] ?? [];
        incoming = rawIncoming;
        await _saveFriendRequestsToCache(incoming);
        return incoming.map((e) => IncomingData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
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
      final response = await _dio.put(
        '${ApiConstants.acceptRequest}/$requestId',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          validateStatus: (status) => status! < 500,
        ),
        data: body,
      );

      if (kDebugMode) print(response);

      final dynamic responseData;
      if (response.data is String) {
        responseData = json.decode(response.data as String);
      } else {
        responseData = response.data;
      }

      if (response.statusCode == 200 && responseData is Map && responseData['status'] == 'success') {
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

  String _getTimeCategory(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today || itemDate.isAfter(today)) {
      return AppLocalizations.of(context)!.today;
    } else if (itemDate == yesterday) {
      return AppLocalizations.of(context)!.yesterday;
    } else if (today.difference(itemDate).inDays <= 7) {
      return AppLocalizations.of(context)!.lastsavendays;
    } else if (today.difference(itemDate).inDays <= 30) {
      return AppLocalizations.of(context)!.lastthirtydays;
    } else {
      return AppLocalizations.of(context)!.older;
    }
  }

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
      case 'SHARE':
        return 'shared your post';
      case 'FRIEND_REQUEST':
        return 'sent you a chase request';
      case 'NEW_GROUP_ADDED':
        final groupName = notification.meta?.groupName ?? 'the group';
        return 'added you to the group $groupName.';
      case 'NEW_MESSAGE':
        return 'send you new message.';
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

  Color _getNotificationLineColor(String type) {
    switch (type.toUpperCase()) {
      case 'LIKE':
        return const Color(0xFFFEA65B);
      case 'COMMENT':
        return const Color(0xFF30AB98);
      case 'FOLLOW':
        return const Color(0xFFF59E0B);
      case 'FRIEND_REQUEST':
        return const Color(0xFF7569D6);
      case 'NEW_GROUP_ADDED':
        return const Color(0xFF25282D);
      case 'SHARE':
        return const Color(0xFF4A90E2);
      case 'NEW_MESSAGE':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF9B3046);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isDisposed = false;

    _allNotificationsScrollController.addListener(_onAllNotificationsScroll);
    _pollNotificationsScrollController.addListener(_onPollNotificationsScroll);

    _loadNotificationsFromCache().then((_) => fetchNotifications());

    friendRequestsFuture = _loadFriendRequestsFromCache().then((
      cachedRequests,
    ) {
      getFriendRequests();
      return cachedRequests;
    });

    // Periodic silent refresh every 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoadingFromNetwork) fetchNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    final isPrivate = userProvider.is_private ?? false;

    if (_lastIsPrivate == null) {
      _lastIsPrivate = isPrivate;
      final tabCount = isPrivate ? 3 : 2;
      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(_handleTabSelection);
    } else if (_lastIsPrivate != isPrivate) {
      _lastIsPrivate = isPrivate;
      final tabCount = isPrivate ? 3 : 2;

      _tabController.removeListener(_handleTabSelection);
      _tabController.dispose();

      _tabController = TabController(length: tabCount, vsync: this);
      _tabController.addListener(_handleTabSelection);
    }
  }

  void _handleTabSelection() {
    if (_tabController.index == 0 && !_tabController.indexIsChanging) {
      if (!_isLoadingFromNetwork) fetchNotifications();
    }
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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isPrivate = userProvider.is_private ?? false;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.notifications),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: TabBar(
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
                Tab(text: AppLocalizations.of(context)!.all),
                Tab(text: AppLocalizations.of(context)!.poll),
                if (isPrivate) Tab(text: AppLocalizations.of(context)!.request),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    _hasMoreData = true;
                    _currentPage = 1;
                    _lastNotifications = [];
                    await fetchNotifications();
                  },
                  child: StreamBuilder<List<NotificationItem>>(
                    stream: _notificationStreamController.stream,
                    initialData:
                        _isLoadingFromNetwork && _lastNotifications.isEmpty
                        ? null
                        : _lastNotifications,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Center(
                          child: Loader(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }

                      if (snapshot.hasError && _lastNotifications.isEmpty) {
                        return _buildErrorWidget();
                      }

                      if (snapshot.hasData) {
                        final notifications = snapshot.data!;
                        if (notifications.isEmpty) {
                          return SizedBox(
                            width: double.infinity,
                            height: 0.75.sh,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    isDarkMode
                                        ? const SizedBox()
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 15,
                                            ),
                                            child: Image.asset(
                                              Assets.images.noComments.path,
                                              height: 0.22.sh,
                                              width: 0.22.sh,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.nonotificationsyet,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.sectionHeading
                                          .copyWith(
                                            fontSize: 18.5,
                                            color: txt.title,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.likescommentsandupdateswillappearhere,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 13,
                                        color: txt.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
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

                            final DateTime date = DateTime.parse(
                              notification.createdAt.toString(),
                            ).toLocal();
                            final String category = _getTimeCategory(date);

                            bool showHeader = false;
                            if (index == 0) {
                              showHeader = true;
                            } else {
                              final prevNotification = notifications[index - 1];
                              final DateTime prevDate = DateTime.parse(
                                prevNotification.createdAt.toString(),
                              ).toLocal();
                              final String prevCategory = _getTimeCategory(
                                prevDate,
                              );
                              if (category != prevCategory) {
                                showHeader = true;
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12.w,
                                      5.h,
                                      12.w,
                                      5.h,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onBackground,
                                          ),
                                        ),
                                        if (index == 0)
                                          GestureDetector(
                                            onTap: () =>
                                                showClearAllNotificationsDiolog(
                                                  context,
                                                  () {
                                                    Navigator.pop(context);
                                                    _clearAllNotifications();
                                                  },
                                                ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.clearall,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                _buildNotificationTile(
                                  username: userProvider.username,
                                  notification: notification,
                                  post: post,
                                ),
                              ],
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
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
                    initialData:
                        _isLoadingFromNetwork && _lastNotifications.isEmpty
                        ? null
                        : _lastNotifications,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return Center(
                          child: Loader(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }

                      if (snapshot.hasError && _lastNotifications.where((n) => n.type == 'VOTE').isEmpty) {
                        return _buildErrorWidget();
                      }

                      if (snapshot.hasData) {
                        final voteNotifications = snapshot.data!
                            .where((n) => n.type == 'VOTE')
                            .toList();

                        if (voteNotifications.isEmpty) {
                          return SizedBox(
                            width: double.infinity,
                            height: 0.75.sh,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    isDarkMode
                                        ? const SizedBox()
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 15,
                                            ),
                                            child: Image.asset(
                                              Assets.images.noComments.path,
                                              height: 0.22.sh,
                                              width: 0.22.sh,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.nonotificationsyet,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.sectionHeading
                                          .copyWith(
                                            fontSize: 18.5,
                                            color: txt.title,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.votesupdateswillappearhere,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyText.copyWith(
                                        fontSize: 13,
                                        color: txt.muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _pollNotificationsScrollController,
                          itemCount:
                              voteNotifications.length + (_hasMoreData ? 1 : 0),
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

                            final DateTime date = DateTime.parse(
                              notification.createdAt.toString(),
                            ).toLocal();
                            final String category = _getTimeCategory(date);

                            bool showHeader = false;
                            if (index == 0) {
                              showHeader = true;
                            } else {
                              final prevNotification =
                                  voteNotifications[index - 1];
                              final DateTime prevDate = DateTime.parse(
                                prevNotification.createdAt.toString(),
                              ).toLocal();
                              if (_getTimeCategory(prevDate) != category) {
                                showHeader = true;
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12.w,
                                      5.h,
                                      12.w,
                                      5.h,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onBackground,
                                          ),
                                        ),
                                        if (index == 0)
                                          GestureDetector(
                                            onTap: () =>
                                                showClearAllNotificationsDiolog(
                                                  context,
                                                  () {
                                                    Navigator.pop(context);
                                                    _clearAllNotifications();
                                                  },
                                                ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.clearall,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                // Use the rich PollVoteNotificationTile for VOTE
                                if (notification.type.toUpperCase() == 'VOTE')
                                  Dismissible(
                                    key: Key(notification.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: const Color(0xFFCA382D),
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      final bool? result =
                                          await showDeleteNotificationsDiolog(
                                            context,
                                          );
                                      return result ?? false;
                                    },
                                    onDismissed: (direction) {
                                      _deleteNotification(notification);
                                    },
                                    child: PollVoteNotificationTile(
                                      key: ValueKey(notification.id),
                                      notification: notification,
                                      getUserImage: getUserImage,
                                      timeAgo: notification.timeAgo.isNotEmpty
                                          ? notification.timeAgo
                                          : formatDateTime(
                                              notification.createdAt.toString(),
                                            ),
                                      onTap: () {
                                        if (!notification.isRead) {
                                          _markAsRead(notification);
                                        }
                                        final post = notification.post;
                                        if (post != null) {
                                          navigationPush(
                                            context,
                                            SinglePostDetails(
                                              username: userProvider.username!,
                                              postId: post.postId,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  )
                                else
                                  _buildNotificationTile(
                                    username: userProvider.username,
                                    notification: notification,
                                    post: notification.post,
                                    showVoteIcon: false,
                                  ),
                              ],
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

                if (isPrivate) _buildRequestTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        _hasMoreData = true;
        _currentPage = 1;
        _lastNotifications = [];
        await fetchNotifications();
      },
      child: StreamBuilder<List<NotificationItem>>(
        stream: _notificationStreamController.stream,
        initialData: _isLoadingFromNetwork && _lastNotifications.isEmpty
            ? null
            : _lastNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Center(
              child: Loader(color: Theme.of(context).colorScheme.primary),
            );
          }

          if (snapshot.hasError && _lastNotifications.where((n) => n.type.toUpperCase() == 'FRIEND_REQUEST').isEmpty) {
            return _buildErrorWidget();
          }

          if (snapshot.hasData) {
            final requestNotifications = snapshot.data!
                .where((n) => n.type.toUpperCase() == 'FRIEND_REQUEST')
                .toList();

            if (requestNotifications.isEmpty) {
              return SizedBox(
                width: double.infinity,
                height: 0.75.sh,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        isDarkMode
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 15),
                                child: Image.asset(
                                  Assets.images.noComments.path,
                                  height: 0.22.sh,
                                  width: 0.22.sh,
                                  fit: BoxFit.contain,
                                ),
                              ),
                        Text(
                          AppLocalizations.of(context)!.nonotificationsyet,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sectionHeading.copyWith(
                            fontSize: 18.5,
                            color: txt.title,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.chaserequestsupdateswillappearhere,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13,
                            color: txt.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: requestNotifications.length,
              itemBuilder: (context, index) {
                final notification = requestNotifications[index];
                return _buildTileWithHeader(
                  username: Provider.of<UserProvider>(
                    context,
                    listen: false,
                  ).username,
                  notification: notification,
                  list: requestNotifications,
                  index: index,
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTileWithHeader({
    required dynamic username,
    required NotificationItem notification,
    required List<NotificationItem> list,
    required int index,
  }) {
    final DateTime date = DateTime.parse(
      notification.createdAt.toString(),
    ).toLocal();
    final String category = _getTimeCategory(date);

    bool showHeader = false;
    if (index == 0) {
      showHeader = true;
    } else {
      final prevDate = DateTime.parse(
        list[index - 1].createdAt.toString(),
      ).toLocal();
      if (_getTimeCategory(prevDate) != category) showHeader = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 5.h, 12.w, 5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                if (index == 0)
                  GestureDetector(
                    onTap: () => showClearAllNotificationsDiolog(context, () {
                      Navigator.pop(context);
                      _clearAllNotifications();
                    }),
                    child: Text(
                      AppLocalizations.of(context)!.clearall,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        _buildNotificationTile(
          username: username,
          notification: notification,
          post: notification.post,
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
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
  }

  Widget _buildNotificationTile({
    required NotificationItem notification,
    required dynamic post,
    required username,
    bool showVoteIcon = true,
  }) {
    final txt = AppTextColors.of(context);
    final isFriendRequest = notification.type.toUpperCase() == 'FRIEND_REQUEST';

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFCA382D),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        final bool? result = await showDeleteNotificationsDiolog(context);
        return result ?? false;
      },
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
      child: GestureDetector(
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification);
          }

          if (isFriendRequest ||
              notification.type.toUpperCase() == 'NEW_GROUP_ADDED') {
            return;
          }
          if (post != null) {
            navigationPush(
              context,
              SinglePostDetails(username: username, postId: post.postId),
            );
          } else if (notification.type.toUpperCase() == 'FOLLOW') {
            navigationPush(
              context,
              PublicProfileScreen(userId: notification.actor.userId),
            );
          } else {
            // ScaffoldMessenger.of(
            //   context,
            // ).showSnackBar(const SnackBar(content: Text('Post not available')));
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
          decoration: BoxDecoration(
            color: !notification.isRead
                ? const Color(0xFFB3B2B2).withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!notification.isRead)
                Container(
                  width: 2.w,
                  height: 34.w,
                  margin: EdgeInsets.only(right: 5.w),
                  decoration: BoxDecoration(
                    color: _getNotificationLineColor(notification.type),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                )
              else
                SizedBox(width: 7.w),
              GestureDetector(
                onTap: () {
                  navigationPush(
                    context,
                    PublicProfileScreen(userId: notification.actor.userId),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    (notification.actor.avatarUrl != null &&
                            notification.actor.avatarUrl!.isNotEmpty)
                        ? CircleAvatar(
                            backgroundImage: MemoryImage(
                              getUserImage(notification.actor.avatarUrl)!,
                            ),
                            radius: 17.w,
                            onBackgroundImageError: (exception, stackTrace) {
                              if (kDebugMode) {
                                debugPrint('Error loading avatar: $exception');
                              }
                            },
                          )
                        : CircleAvatar(
                            radius: 16.5.w,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            child: Text(
                              getInitial(notification.actor.name),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                    if (notification.type.toUpperCase() == 'LIKE')
                      Positioned(
                        bottom: -3.h,
                        right: -4.w,
                        child: AppIcons.like(),
                      ),
                    if (notification.type.toUpperCase() == 'COMMENT')
                      Positioned(
                        bottom: -3.h,
                        right: -4.w,
                        child: AppIcons.icCommnet(),
                      ),
                    if (showVoteIcon &&
                        notification.type.toUpperCase() == 'VOTE')
                      Positioned(
                        bottom: -1.h,
                        right: -2.w,
                        child: AppIcons.icVote(),
                      ),
                    if (notification.type.toUpperCase() == 'SHARE')
                      Positioned(
                        bottom: -3.h,
                        right: -4.w,
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.share,
                            size: 10.sp,
                            color: txt.heading,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),

              // ── Message + time ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.cardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: notification.actor.name,
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.title,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          TextSpan(
                            text: ' ${getNotificationMessage(notification)}',
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.title,
                              fontWeight: FontWeight.w500,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      formatDateTime(notification.createdAt.toString()),
                      style: AppTextStyles.subText.copyWith(color: txt.muted),
                    ),

                    if (isFriendRequest) ...[
                      SizedBox(height: 8.h),
                      FriendRequestButtons(
                        notification: notification,
                        onApprove: () => _handleFriendRequest(
                          notification: notification,
                          action: 'accept',
                        ),
                        onReject: () => _handleFriendRequest(
                          notification: notification,
                          action: 'reject',
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (!isFriendRequest &&
                  notification.post != null &&
                  notification.post!.imageUrl != null &&
                  notification.post!.imageUrl!.isNotEmpty)
                Container(
                  width: 35.w,
                  height: 38.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    image: DecorationImage(
                      image: NetworkImage(notification.post!.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              if (notification.type.toUpperCase() == 'FOLLOW' ||
                  notification.type.toUpperCase() == 'NEW_GROUP_ADDED')
                GestureDetector(
                  onTap: () {
                    if (!notification.isRead) {
                      _markAsRead(notification);
                    }
                    if (notification.type.toUpperCase() == 'FOLLOW') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => PrivateChatProvider(),
                            child: PrivateChatScreen(
                              memberName: notification.actor.name,
                              profileUrl: notification.actor.avatarUrl,
                              userId: int.tryParse(notification.actor.userId),
                              chatId: notification.meta?.chatId,
                            ),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => GroupChatProvider(),
                            child: GroupChatScreen(
                              groupName:
                                  notification.meta?.groupName ??
                                  notification.title,
                              chatId: notification.meta?.chatId,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 30.h,
                    width: 80.w,
                    margin: EdgeInsets.only(left: 5.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Message',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFriendRequest({
    required NotificationItem notification,
    required String action,
  }) async {
    if (!notification.isRead) {
      _markAsRead(notification);
    }
    final requestId = notification.meta?.requestId;
    if (requestId == null) return;

    try {
      final headers = await _getAuthHeaders();
      await _dio.put(
        '${ApiConstants.acceptRequest}/$requestId',
        data: {'action': action},
        options: Options(headers: headers),
      );

      setState(() {
        _lastNotifications.removeWhere((n) => n.id == notification.id);
      });
      _notificationStreamController.add(_lastNotifications);
    } catch (e) {
      if (kDebugMode) print('Error handling friend request: $e');
      showToast(message: 'Failed. Please try again.');
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    // Optimistic UI Update
    setState(() {
      final index = _lastNotifications.indexWhere(
        (n) => n.id == notification.id,
      );
      if (index != -1) {
        _lastNotifications[index] = notification.copyWith(isRead: true);
        _notificationStreamController.add(_lastNotifications);

        if (unreadNotificationCount.value > 0) {
          unreadNotificationCount.value -= 1;
        }
      }
    });

    try {
      await ApiService().markNotificationRead(notification.id);
    } catch (e) {
      if (kDebugMode) print('Error marking notification as read: $e');
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          final index = _lastNotifications.indexWhere(
            (n) => n.id == notification.id,
          );
          if (index != -1) {
            _lastNotifications[index] = notification.copyWith(isRead: false);
            _notificationStreamController.add(_lastNotifications);
            unreadNotificationCount.value += 1;
          }
        });
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    // Optimistic UI update
    setState(() {
      _lastNotifications.clear();
      _notificationStreamController.add(_lastNotifications);
      unreadNotificationCount.value = 0;
    });

    try {
      final success = await ApiService().clearAllNotifications();
      if (!success) {
        fetchNotifications();
        showToast(message: 'Failed to clear notifications');
      }
    } catch (e) {
      if (kDebugMode) print('Error clearing notifications: $e');
      fetchNotifications();
      showToast(message: 'Error clearing notifications');
    }
  }

  Future<void> _deleteNotification(NotificationItem notification) async {
    // Optimistic UI update
    setState(() {
      _lastNotifications.removeWhere((n) => n.id == notification.id);
      _notificationStreamController.add(_lastNotifications);
      if (!notification.isRead && unreadNotificationCount.value > 0) {
        unreadNotificationCount.value -= 1;
      }
    });

    try {
      final success = await ApiService().deleteNotification(notification.id);
      if (!success) {
        fetchNotifications();
        showToast(message: 'Failed to delete notification');
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting notification: $e');
      fetchNotifications();
      showToast(message: 'Error deleting notification');
    }
  }
}
