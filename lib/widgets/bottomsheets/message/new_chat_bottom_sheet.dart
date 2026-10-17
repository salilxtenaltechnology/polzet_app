// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import '../../../api/api_config.dart';
import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/global search/global_search_model.dart';
import '../../../provider/user_provider.dart';
import '../../../screens/home/message/chat/private/private_chat_screen.dart';
import '../../../screens/home/profile/public/public_profile_screen.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/loader.dart';
import '../../../gen/assets.gen.dart';

class NewChatBottomSheet extends StatefulWidget {
  const NewChatBottomSheet({super.key});

  @override
  State<NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<NewChatBottomSheet>
    with UtilityMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _searchUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<String> _seenUserIds = {};

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isSearchingMore = false;

  int _chasePage = 1;
  int _rechasePage = 1;
  int _defaultAccountsPage = 1;
  bool _chaseHasMore = true;
  bool _rechaseHasMore = true;
  bool _defaultAccountsHasMore = true;

  int _searchPage = 1;
  bool _searchHasMore = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchUsers(isRefresh: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_searchQuery.isEmpty) {
        if (!_isLoading &&
            (_chaseHasMore || _rechaseHasMore || _defaultAccountsHasMore)) {
          _fetchUsers();
        }
      } else {
        if (!_isSearching && !_isSearchingMore && _searchHasMore) {
          _fetchMoreSearchResults();
        }
      }
    }
  }

  Future<void> _fetchUsers({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (isRefresh) {
      _chasePage = 1;
      _rechasePage = 1;
      _defaultAccountsPage = 1;
      _chaseHasMore = true;
      _rechaseHasMore = true;
      _defaultAccountsHasMore = true;
    } else {
      if (!_chaseHasMore && !_rechaseHasMore && !_defaultAccountsHasMore) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';

      final futures = <Future<dynamic>>[];

      if (_chaseHasMore) {
        futures.add(
          _apiService.fetchChaseList(targetUserId: myUserId, page: _chasePage),
        );
      } else {
        futures.add(Future.value(null));
      }

      if (_rechaseHasMore) {
        futures.add(
          _apiService.fetchRechaseList(
            targetUserId: myUserId,
            page: _rechasePage,
          ),
        );
      } else {
        futures.add(Future.value(null));
      }

      if (_defaultAccountsHasMore) {
        futures.add(
          _apiService.globalSearch(
            '',
            tab: 'accounts',
            page: _defaultAccountsPage,
            limit: 20,
            publicId: myUserId,
          ),
        );
      } else {
        futures.add(Future.value(null));
      }

      final results = await Future.wait(futures);
      final chaseResponse = results[0] as Map<String, dynamic>?;
      final rechaseResponse = results[1] as Map<String, dynamic>?;
      final accountsResponse = results[2] as GlobalSearchModel?;

      if (!mounted) return;

      final newUsers = <Map<String, dynamic>>[];

      void processItems(Map<String, dynamic>? response) {
        if (response != null) {
          final List<dynamic> rawList = response['results'] ?? [];
          for (final e in rawList) {
            final userId =
                e['id']?.toString() ?? e['user_id']?.toString() ?? '';
            if (userId.isNotEmpty &&
                userId != myUserId &&
                !_seenUserIds.contains(userId)) {
              _seenUserIds.add(userId);
              final rawStatus = e['follow_status'] ?? e['followStatus'];
              final followStatus = rawStatus != null
                  ? rawStatus.toString().toLowerCase()
                  : 'none';

              newUsers.add({
                'user_id': userId,
                'username': e['username'] ?? '',
                'first_name': e['first_name'] ?? '',
                'last_name': e['last_name'] ?? '',
                'full_name':
                    '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim(),
                'avatar_url': e['profile_picture_url'] ?? e['avatar_url'],
                'is_online': false,
                'follow_status': followStatus,
                'is_private': e['is_private'] == true,
              });
            }
          }
        }
      }

      void processAccounts(List<SearchAccount>? accounts) {
        if (accounts != null) {
          for (final acc in accounts) {
            final userId = acc.uuid;
            if (userId.isNotEmpty &&
                userId != myUserId &&
                !_seenUserIds.contains(userId)) {
              _seenUserIds.add(userId);
              newUsers.add({
                'user_id': userId,
                'username': acc.username,
                'first_name': '',
                'last_name': '',
                'full_name': acc.fullName,
                'avatar_url': acc.profileImage,
                'is_online': false,
                'follow_status': acc.followStatus,
                'is_private': acc.isPrivate,
              });
            }
          }
        }
      }

      if (isRefresh) {
        _allUsers.clear();
        _seenUserIds.clear();
      }

      processItems(chaseResponse);
      processItems(rechaseResponse);
      if (accountsResponse != null) {
        processAccounts(accountsResponse.data.accounts);
      }

      setState(() {
        _allUsers.addAll(newUsers);

        if (chaseResponse != null) {
          _chaseHasMore = chaseResponse['next'] != null;
          if (_chaseHasMore) _chasePage++;
        }
        if (rechaseResponse != null) {
          _rechaseHasMore = rechaseResponse['next'] != null;
          if (_rechaseHasMore) _rechasePage++;
        }
        if (accountsResponse != null) {
          _defaultAccountsHasMore = accountsResponse.pagination.hasNext;
          if (_defaultAccountsHasMore) _defaultAccountsPage++;
        }

        if (_searchQuery.isEmpty) {
          _filteredUsers = List.from(_allUsers);
        }
      });
    } catch (e) {
      debugPrint('Error fetching users in NewChatBottomSheet: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false;
        _searchUsers.clear();
        _filteredUsers = List.from(_allUsers);
      });
      return;
    }

    setState(() {
      _searchQuery = trimmed;
      _isSearching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';

      final result = await _apiService.globalSearch(
        query,
        tab: 'accounts',
        page: 1,
        limit: 25,
        publicId: myUserId,
      );

      if (!mounted || _searchQuery != query) return;

      final List<Map<String, dynamic>> searchList = [];
      final Set<String> seenIds = {};

      if (result != null && result.data.accounts.isNotEmpty) {
        for (final acc in result.data.accounts) {
          final userId = acc.uuid;
          if (userId.isNotEmpty &&
              userId != myUserId &&
              !seenIds.contains(userId)) {
            seenIds.add(userId);
            searchList.add({
              'user_id': userId,
              'username': acc.username,
              'first_name': '',
              'last_name': '',
              'full_name': acc.fullName,
              'avatar_url': acc.profileImage,
              'is_online': false,
              'follow_status': acc.followStatus,
              'is_private': acc.isPrivate,
            });
          }
        }
      }

      setState(() {
        _searchUsers = searchList;
        _filteredUsers = searchList;
        _searchPage = 1;
        _searchHasMore = result?.pagination.hasNext ?? false;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching accounts in NewChatBottomSheet: $e');
      if (mounted && _searchQuery == query) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _fetchMoreSearchResults() async {
    if (_isSearchingMore || !_searchHasMore || _searchQuery.isEmpty) return;
    setState(() {
      _isSearchingMore = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';
      final nextPage = _searchPage + 1;

      final result = await _apiService.globalSearch(
        _searchQuery,
        tab: 'accounts',
        page: nextPage,
        limit: 25,
        publicId: myUserId,
      );

      if (!mounted) return;

      if (result != null && result.data.accounts.isNotEmpty) {
        final existingIds =
            _searchUsers.map((u) => u['user_id']?.toString()).toSet();
        final List<Map<String, dynamic>> moreList = [];

        for (final acc in result.data.accounts) {
          final userId = acc.uuid;
          if (userId.isNotEmpty &&
              userId != myUserId &&
              !existingIds.contains(userId)) {
            existingIds.add(userId);
            moreList.add({
              'user_id': userId,
              'username': acc.username,
              'first_name': '',
              'last_name': '',
              'full_name': acc.fullName,
              'avatar_url': acc.profileImage,
              'is_online': false,
              'follow_status': acc.followStatus,
              'is_private': acc.isPrivate,
            });
          }
        }

        setState(() {
          _searchUsers.addAll(moreList);
          _filteredUsers = List.from(_searchUsers);
          _searchPage = nextPage;
          _searchHasMore = result.pagination.hasNext;
        });
      } else {
        setState(() {
          _searchHasMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more search accounts in NewChatBottomSheet: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingMore = false;
        });
      }
    }
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    final profilePic = user['avatar_url'] as String?;
    final firstName = (user['first_name'] ?? '').toString().trim();
    final lastName = (user['last_name'] ?? '').toString().trim();
    final username = (user['username'] ?? '').toString().trim();
    final cleanUsername = username.toLowerCase();
    final bool isPolzetAi =
        cleanUsername == 'polzet_ai' || cleanUsername == 'polet_ai';
    final rawFullName = (user['full_name'] ?? '').toString().trim();
    final fullName = rawFullName.isNotEmpty
        ? rawFullName
        : '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty
        ? fullName
        : (username.isNotEmpty ? username : 'Polzet User');
    final userId =
        (user['user_id'] ?? user['uuid'] ?? user['id'])?.toString() ?? '';

    void openChat() {
      if (userId.isEmpty) return;
      Navigator.pop(context);
      navigationPush(
        context,
        PrivateChatScreen(
          userId: userId,
          memberName: displayName,
          username: username.isNotEmpty ? username : displayName,
          profileUrl: profilePic,
        ),
      );
    }

    void openProfile() {
      if (userId.isEmpty && username.isEmpty) return;
      navigationPush(
        context,
        PublicProfileScreen(
          userId: userId.isNotEmpty ? userId : null,
          username: username.isNotEmpty ? username : null,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openChat,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            if (isPolzetAi)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openProfile,
                child: Container(
                  height: 40.h,
                  width: 40.w,
                  margin: EdgeInsets.only(right: 10.w),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 7,
                              bottom: 0,
                              left: 9,
                              right: 8,
                            ),
                            child: Image.asset(
                              Assets.images.icSplash.path,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(
                          Assets.images.aiFrame.path,
                          height: 50,
                          width: 50,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openProfile,
                child: Container(
                  height: 40.h,
                  width: 40.w,
                  margin: EdgeInsets.only(right: 10.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 0.7,
                    ),
                    color: isDarkMode
                        ? const Color(0xFF252525)
                        : Theme.of(context).primaryColor.withOpacity(0.08),
                  ),
                  child: ClipOval(
                    child: (() {
                      if (profilePic != null &&
                          profilePic.isNotEmpty &&
                          profilePic != 'null') {
                        if (profilePic == Assets.images.icAvatar.path ||
                            profilePic.endsWith('ic_avatar.png')) {
                          return Image.asset(
                            Assets.images.icAvatar.path,
                            fit: BoxFit.cover,
                          );
                        }
                        if (profilePic.startsWith('assets/')) {
                          return Image.asset(
                            profilePic,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              Assets.images.icAvatar.path,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        final bytes = getProfileImage(profilePic);
                        if (bytes != null) {
                          return Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              Assets.images.icAvatar.path,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        final imageUrl = profilePic.startsWith('http')
                            ? profilePic
                            : (profilePic.startsWith('/')
                                  ? '${ApiConfig.baseUrlImage}$profilePic'
                                  : '${ApiConfig.baseUrlImage}/$profilePic');
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Image.asset(
                            Assets.images.icAvatar.path,
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return Image.asset(
                        Assets.images.icAvatar.path,
                        fit: BoxFit.cover,
                      );
                    })(),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username.isNotEmpty ? username : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyText.copyWith(
                            color: txt.body,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isPolzetAi || cleanUsername == 'polzet') ...[
                        SizedBox(width: 4.w),
                        Image.asset(
                          Assets.images.icVerify.path,
                          height: 13,
                          width: 13,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    fullName.isNotEmpty
                        ? fullName
                        : (username.isNotEmpty ? username : displayName),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.5,
                      color: txt.muted,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openChat,
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
                    AppLocalizations.of(context)!.message,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 0.8.sh,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.newchat,
                style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
              ),
              const SizedBox(height: 8),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
                indent: 12,
                endIndent: 12,
                height: 1,
              ),
              // Search input
              Container(
                height: 43.h,
                width: double.infinity,
                margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: TextField(
                  controller: _searchController,
                  cursorColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.8),
                  cursorWidth: 1.5,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(
                      right: 12.w,
                      left: 12.w,
                      top: 10.h,
                    ),
                    hintText: l10n?.searchusers ?? 'Search users',
                    hintStyle: AppTextStyles.bodyText.copyWith(
                      color: const Color(0XFF898989),
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      FeatherIcons.search,
                      size: 17.spMax,
                      color: const Color(0XFF898989),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 16.spMax,
                              color: const Color(0XFF898989),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                        width: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.title,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              // User List
              Expanded(
                child: ((_isLoading && _allUsers.isEmpty) ||
                        (_isSearching && _filteredUsers.isEmpty))
                    ? Center(
                        child: Loader(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? (l10n?.nousersfound ?? 'No users found')
                              : (l10n?.nousersfound ?? 'No users found'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: txt.muted,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (_searchQuery.isEmpty) {
                            await _fetchUsers(isRefresh: true);
                          } else {
                            await _performSearch(_searchQuery);
                          }
                        },
                        color: Theme.of(context).colorScheme.primary,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredUsers.length +
                              ((_isLoading || _isSearchingMore) ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredUsers.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: Center(
                                  child: Loader(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            }
                            return _buildUserListItem(_filteredUsers[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
