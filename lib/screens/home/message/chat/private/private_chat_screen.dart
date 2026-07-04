// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../api/api_config.dart';
import '../../../../../api/api_service.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../models/posts/single_post_model.dart';
import '../../../../../provider/private_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/button/back_button.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../search/posts/rank/single_post_image_ranking.dart';
import '../../../search/posts/rank/single_post_things_ranking.dart';
import '../../../profile/public/public_profile_screen.dart';
import '../chat_details.dart';

class PrivateChatScreen extends StatefulWidget {
  final String? memberName;
  final String? username;
  final String? profileUrl;
  final dynamic userId;
  final int? chatId;
  final bool isUserBlock;

  const PrivateChatScreen({
    super.key,
    required this.memberName,
    this.username,
    required this.profileUrl,
    required this.userId,
    this.chatId,
    this.isUserBlock = false,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;
  late bool _isUserBlock;

  int _previousMessageCount = 0;
  ChatMessage? _previousLastMessage;
  bool _isAtBottom = true;
  int _unreadCount = 0;

  String? _floatingDate;
  final Map<String, GlobalKey> _headerKeys = {};

  int? _resolvedChatId;
  bool _isLoadingChatId = false;
  final ApiService _apiService = ApiService();

  PrivateChatProvider get provider => context.read<PrivateChatProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isUserBlock = widget.isUserBlock;
    _resolvedChatId = widget.chatId == 0 ? null : widget.chatId;

    _messagesStream = provider.messagesStream;

    debugPrint('User id : ${widget.userId}');
    debugPrint('Chat id : ${widget.chatId}');

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  Future<void> _initChat() async {
    final userProvider = context.read<UserProvider>();

    if (_resolvedChatId == null && widget.userId != null) {
      if (mounted) {
        setState(() {
          _isLoadingChatId = true;
        });
      }
      try {
        final chatResponse = await _apiService.createPrivateChatId(
          withUserId: widget.userId.toString(),
        );
        final parsedChatId = int.tryParse(chatResponse['id']?.toString() ?? '');
        if (mounted) {
          setState(() {
            _resolvedChatId = parsedChatId;
          });
        }
      } catch (e) {
        debugPrint('Error creating/fetching private chat ID: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingChatId = false;
          });
        }
      }
    }

    if (widget.userId != null) {
      provider.setMemberUserId(widget.userId!);
    }
    provider.init(
      memberName: widget.memberName,
      profileUrl: widget.profileUrl,
      chatId: _resolvedChatId,
      currentUsername: userProvider.username,
    );

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent > 0 &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 80) {
        _loadMoreHistory();
      }
    });

    if (widget.userId != null) {
      provider.setMemberUserId(widget.userId!);
    }
  }

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;
    // With reverse: true, the bottom is at pixels == 0
    final wasAtBottom = _isAtBottom;
    _isAtBottom = currentScroll < 100;

    if (wasAtBottom != _isAtBottom) {
      if (mounted) setState(() {});
    }

    if (_isAtBottom && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
      context.read<PrivateChatProvider>().markAsRead();
    }

    _updateFloatingDate();
  }

  void _updateFloatingDate() {
    String? bestDate;
    double maxDy = double.negativeInfinity;

    String? topMostDate;
    double topMostHeaderDy = double.infinity;

    final threshold = MediaQuery.of(context).padding.top + 40.h + 30;

    _headerKeys.forEach((dateStr, key) {
      final currentCtx = key.currentContext;
      if (currentCtx == null) return;
      final box = currentCtx.findRenderObject() as RenderBox?;
      if (box == null) return;

      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy < topMostHeaderDy) {
        topMostHeaderDy = dy;
        topMostDate = dateStr;
      }

      if (dy <= threshold) {
        if (dy > maxDy) {
          maxDy = dy;
          bestDate = dateStr;
        }
      }
    });

    if (bestDate != null) {
      if (_floatingDate != bestDate) {
        setState(() {
          _floatingDate = bestDate;
        });
      }
    } else {
      bool hasMore = context.read<PrivateChatProvider>().hasMoreHistory;
      bool isScreenCovered = hasMore;
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        if (_scrollController.position.maxScrollExtent > 0) {
          isScreenCovered = true;
        }
      }

      if (!isScreenCovered) {
        if (_floatingDate != null) {
          setState(() {
            _floatingDate = null;
          });
        }
      } else if (topMostDate != null) {
        if (_floatingDate != topMostDate) {
          setState(() {
            _floatingDate = topMostDate;
          });
        }
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reconnect WS when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      context.read<PrivateChatProvider>().reconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<PrivateChatProvider>().stopTyping();
    context.read<PrivateChatProvider>().sendMessage(text);
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatTime(DateTime dt) =>
      DateFormat('h:mm a').format(dt).toLowerCase();

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _getDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(msgDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // ── Message status icon (pending / failed / sent / read) ──────────────────────────
  Widget _buildMessageStatus(ChatMessage message) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    if (message.isFailed) {
      return Icon(Icons.error_outline, size: 11.sp, color: Colors.redAccent);
    }
    if (message.isPending) {
      return Icon(Icons.check, size: 11.sp, color: Colors.white54);
    }
    if (message.isRead) {
      return Icon(Icons.done_all, size: 11.sp, color: Colors.blue);
    }
    // Sent (delivered)
    return Icon(Icons.done_all, size: 11.sp, color: Colors.white70);
  }

  // ── Shared Post Card ───────────────────────────────────────────────────────
  Widget _buildSharedPostCard(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final post = message.sharedPost!;
    final user = post['user'] ?? {};
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final username = user['username']?.toString() ?? '';
    final String? avatarUrlRaw = user['profile_image']?.toString();
    String? avatarUrl;
    if (avatarUrlRaw != null && avatarUrlRaw.isNotEmpty) {
      if (avatarUrlRaw.startsWith('http') ||
          avatarUrlRaw.startsWith('data:image')) {
        avatarUrl = avatarUrlRaw;
      } else {
        if (avatarUrlRaw.startsWith('/')) {
          avatarUrl = '${ApiConfig.baseUrlImage}$avatarUrlRaw';
        } else {
          avatarUrl = '${ApiConfig.baseUrlImage}/$avatarUrlRaw';
        }
      }
    }
    final description = post['description']?.toString() ?? '';
    final isPolledByCurrentUser = post['is_polled_by_current_user'] == true;

    // Get time ago
    final dtStr = post['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(dtStr) ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    String timeAgo = '';
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours} hr ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    // Extract images & poll text
    List<String> imageUrls = [];
    String pollQuestion = '';
    List<String> pollTextOptions = [];

    if (post['images'] != null && (post['images'] as List).isNotEmpty) {
      for (var img in post['images']) {
        final url = img['image'] ?? img['url'];
        if (url != null) imageUrls.add(url.toString());
      }
    } else if (post['polls'] != null && (post['polls'] as List).isNotEmpty) {
      final poll = post['polls'][0];
      pollQuestion = poll['question']?.toString() ?? '';
      final options = poll['options'] as List? ?? [];
      for (var opt in options) {
        if (opt['image'] != null) {
          final url = opt['image']['url'] ?? opt['image']['thumbnail_url'];
          if (url != null) imageUrls.add(url.toString());
        } else if (opt['text'] != null && opt['text'].toString().isNotEmpty) {
          pollTextOptions.add(opt['text'].toString());
        }
      }
    }
    imageUrls = imageUrls.where((e) => e.isNotEmpty).toList();

    // Removed base64 decode logic for avatar

    return GestureDetector(
      onTap: () {
        final isImagePoll = imageUrls.isNotEmpty;
        final isThingsPoll = pollTextOptions.isNotEmpty;

        if (!isImagePoll && !isThingsPoll) return;

        if (isPolledByCurrentUser) {
          if (isImagePoll) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageResultScreen(
                  username: username,
                  postId: post['id'].toString(),
                ),
              ),
            );
          } else if (isThingsPoll) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ThingsResultScreen(
                  username: username,
                  postId: post['id'].toString(),
                ),
              ),
            );
          }
        } else {
          try {
            final userMap = post['user'] as Map<String, dynamic>? ?? {};
            final mappedJson = {
              'id': post['id'],
              'first_name': userMap['first_name'],
              'last_name': userMap['last_name'],
              'user': userMap['username'],
              'profile_image': userMap['profile_image'],
              'description': post['description'],
              'created_at': post['created_at'],
              'polls': post['polls'],
              'is_liked': post['is_liked_by_current_user'],
              'is_polled_by_current_user': post['is_polled_by_current_user'],
              'location_name': post['location_name'],
              'comments_count': post['comments_count'],
              'likes_count': post['likes_count'],
              'following_status': post['following_status'],
              'shares_count': post['shares_count'],
            };

            final singlePost = SinglePostModel.fromJson(mappedJson);
            if (singlePost.polls.isNotEmpty) {
              if (isImagePoll) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SinglePostImageRanking(
                      post: singlePost,
                      poll: singlePost.polls.first,
                    ),
                  ),
                );
              } else if (isThingsPoll) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SinglePostThingsRanking(
                      post: singlePost,
                      poll: singlePost.polls.first,
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('Error parsing shared post for navigation: $e');
          }
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 4.h,
          bottom: 12,
          left: message.isSentByMe ? 40.w : 12.w,
          right: message.isSentByMe ? 12.w : 40.w,
        ),

        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
              child: GestureDetector(
                onTap: () {
                  final userId =
                      user['userid'] ?? user['id'] ?? user['user_id'];
                  if (userId != null) {
                    navigationPush(
                      context,
                      PublicProfileScreen(userId: userId.toString(), username: username),
                    );
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.1),
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : (username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : 'P'),
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : username,
                            style: AppTextStyles.sectionHeading.copyWith(
                              color: txt.title,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '@$username',
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: txt.body,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                ' • $timeAgo',
                                style: AppTextStyles.subText.copyWith(
                                  color: txt.muted,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),

            if (description.isNotEmpty && pollTextOptions.isEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 0),
                child: Text(
                  description,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.heading,
                    fontWeight: FontWeight.w400,
                    fontSize: 13.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            if (imageUrls.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _buildStackedImages(imageUrls),
            ] else if (pollTextOptions.isNotEmpty) ...[
              _buildTextPoll(context, pollQuestion, pollTextOptions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharedProfileCard(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final profile = message.sharedProfile!;
    final userId = profile['user_id']?.toString() ?? '';
    final firstName = profile['first_name']?.toString() ?? '';
    final lastName = profile['last_name']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final username = profile['username']?.toString() ?? '';
    final profileUrlRaw = profile['profile_url']?.toString();
    final avatarUrl = resolveProfileImageUrl(profileUrlRaw);

    final displayName = name.isNotEmpty ? name : username;

    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty) {
          navigationPush(
            context,
            PublicProfileScreen(userId: userId, username: username),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(
          top: 4.h,
          bottom: 12.h,
          left: message.isSentByMe ? 120.w : 12.w,
          right: message.isSentByMe ? 12.w : 120.w,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 2)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.1),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: AppTextStyles.sectionHeading.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '@$username',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: txt.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPoll(
    BuildContext context,
    String question,
    List<String> options,
  ) {
    final txt = AppTextColors.of(context);
    final displayOptions = options.take(2).toList();
    final remainingCount = options.length - displayOptions.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.isNotEmpty) ...[
            Text(
              question,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.heading,
                fontWeight: FontWeight.w400,
                fontSize: 13.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
          ],
          Row(
            children: [
              ...displayOptions.map((opt) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        color: txt.heading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
              if (remainingCount > 0)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$remainingCount more',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: txt.heading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStackedImages(List<String> urls) {
    final displayUrls = urls.take(4).toList();
    final n = displayUrls.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = 140.h;

          final cardWidth = n == 1 ? w : w * 0.55;
          final spacing = n > 1 ? (w - cardWidth) / (n - 1) : 0.0;

          return SizedBox(
            height: h,
            width: w,
            child: Stack(
              children: displayUrls
                  .asMap()
                  .entries
                  .map<Widget>((entry) {
                    final i = entry.key;
                    final url = entry.value;

                    Widget imageWidget = _buildNetworkImage(url);

                    if (i > 0) {
                      imageWidget = ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                        child: imageWidget,
                      );
                    }

                    return Positioned(
                      left: i * spacing,
                      top: 0,
                      bottom: 0,
                      width: cardWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageWidget,
                              // Positioned(
                              //   top: 8,
                              //   right: 8,
                              //   child: Container(
                              //     height: 28,
                              //     width: 28,
                              //     decoration: BoxDecoration(
                              //       shape: BoxShape.circle,
                              //       color: Theme.of(context).colorScheme.primary,
                              //       border: Border.all(
                              //         color: Colors.white,
                              //         width: 1,
                              //       ),
                              //     ),
                              //     child: Center(
                              //       child: Text(
                              //         '${i + 1}',
                              //         style: AppTextStyles.subText.copyWith(
                              //           fontSize: 12,
                              //           fontWeight: FontWeight.w600,
                              //           color: Colors.white,
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList()
                  .reversed
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    final fullUrl = url.startsWith('http')
        ? url
        : '${ApiConfig.baseUrlImage}$url';
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }

  // ── Message bubble ─────────────────────────────────────────────────────────
  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bubble = Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.2.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.isSentByMe
              ? Theme.of(context).colorScheme.primary
              : (isDarkMode
                    ? const Color(0xFF2A2A2E)
                    : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.only(
            topLeft: message.isSentByMe
                ? const Radius.circular(AppRadius.card)
                : const Radius.circular(0),
            topRight: const Radius.circular(AppRadius.card),
            bottomLeft: const Radius.circular(AppRadius.card),
            bottomRight: message.isSentByMe
                ? const Radius.circular(0)
                : const Radius.circular(AppRadius.card),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 4.w,
          children: [
            Text(
              message.text,
              style: AppTextStyles.bodyText.copyWith(
                color: message.isSentByMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.created_at),
                  style: TextStyle(
                    fontSize: 8.2.sp,
                    color: message.isSentByMe
                        ? const Color(0xBDFFFFFF)
                        : txt.muted,
                    // color: txt.muted,
                  ),
                ),
                SizedBox(width: 3.w),
                _buildMessageStatus(message),
              ],
            ),
          ],
        ),
      ),
    );

    if (message.sharedPost != null) {
      return Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSharedPostCard(context, message),
          if (message.text.isNotEmpty) bubble,
        ],
      );
    }

    if (message.sharedProfile != null) {
      return Column(
        crossAxisAlignment: message.isSentByMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSharedProfileCard(context, message),
          if (message.text.isNotEmpty) bubble,
        ],
      );
    }

    return bubble;
  }

  // ── Top loader for pagination ──────────────────────────────────────────────
  Widget _buildHistoryLoader(bool isLoading) {
    if (!isLoading) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // ── Scroll-to-bottom FAB with unread badge ─────────────────────────────────
  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    return Positioned(
      bottom: 35.h,
      right: 14.w,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          setState(() => _unreadCount = 0);
          context.read<PrivateChatProvider>().markAsRead();
        },
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.keyboard_arrow_down, size: 20.sp, color: Colors.white),
              if (_unreadCount > 0)
                Positioned(
                  top: -13,
                  right: -9,
                  child: Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 2, 148, 77),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.background,
                        fontSize: 7.2.sp,
                        fontWeight: FontWeight.bold,
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

  // ── Typing dots animation ──────────────────────────────────────────────────
  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return _AnimatedDot(delay: Duration(milliseconds: i * 150));
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<PrivateChatProvider>();

    final avatarUrl = resolveProfileImageUrl(widget.profileUrl);
    final avatarProvider = avatarUrl != null ? NetworkImage(avatarUrl) : null;
    final initial = (widget.memberName?.trim().isNotEmpty ?? false)
        ? widget.memberName![0].toUpperCase()
        : '?';

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          toolbarHeight: 40.h,
          automaticallyImplyLeading: false,
          leadingWidth: double.infinity,
          leading: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 12.w),
              const PrimaryBackButton(),
              Stack(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(
                            initial,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          )
                        : null,
                  ),
                  // Green dot when member is online
                  Consumer<PrivateChatProvider>(
                    builder: (_, p, __) {
                      if (!p.isMemberOnline) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 9.w,
                          height: 9.w,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.background,
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(width: 7.w),
              // ── Name + typing / online status ──────────────────────────────
              GestureDetector(
                onTap: () async {
                  final updatedBlock = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<PrivateChatProvider>(),
                        child: ChatDetails(
                          userId: widget.userId,
                          chatName: widget.memberName,
                          username: widget.username,
                          profileUrl: widget.profileUrl,
                          isGroupChat: false,
                          isUserBlock: _isUserBlock,
                        ),
                      ),
                    ),
                  );
                  if (mounted && updatedBlock != null) {
                    setState(() => _isUserBlock = updatedBlock);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.memberName ?? 'Polzet User',
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.title,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Consumer<PrivateChatProvider>(
                      builder: (_, p, __) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: p.isMemberTyping
                              ? Row(
                                  key: const ValueKey('typing'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'typing',
                                      style: TextStyle(
                                        fontSize: 9.5.sp,
                                        color: Colors.green,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    SizedBox(width: 3.w),
                                    _buildTypingDots(),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('status'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      p.isMemberOnline
                                          ? AppLocalizations.of(context)!.online
                                          : AppLocalizations.of(
                                              context,
                                            )!.offline,
                                      style: AppTextStyles.subText.copyWith(
                                        color: p.isMemberOnline
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 9.5.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: isDarkMode
                  ? AssetImage(Assets.images.bgChatDark.path)
                  : AssetImage(Assets.images.bgChatLight.path),
              fit: BoxFit.cover,
            ),
          ),
          child: _isLoadingChatId
              ? Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : Column(
                  children: [
                    // ── Connection banner ──────────────────────────────────────────────
                    // _buildConnectionBanner(provider),

                    // ── History error banner ───────────────────────────────────────────
                    if (provider.historyError != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: 6.h,
                          horizontal: 12.w,
                        ),
                        color: Theme.of(context).colorScheme.error,
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 14.sp,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                'Failed to load messages. Tap to retry.',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => provider.fetchMessageHistory(),
                              child: Icon(
                                Icons.refresh,
                                size: 16.sp,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Message list ───────────────────────────────────────────────────
                    Expanded(
                      child: Stack(
                        children: [
                          StreamBuilder<List<ChatMessage>>(
                            stream: _messagesStream,
                            initialData: context
                                .read<PrivateChatProvider>()
                                .messages,
                            builder: (context, snapshot) {
                              final messages = snapshot.data ?? [];
                              final isLoading = context
                                  .read<PrivateChatProvider>()
                                  .isLoadingHistory;

                              // Auto-scroll logic
                              if (messages.length > _previousMessageCount) {
                                if (_previousMessageCount == 0) {
                                  // First load!
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_isAtBottom ||
                                        (messages.isNotEmpty &&
                                            messages.last.isSentByMe)) {
                                      _scrollToBottom();
                                      context
                                          .read<PrivateChatProvider>()
                                          .markAsRead();
                                    }
                                  });
                                } else {
                                  // Find how many new messages were newly added to the end (new incoming messages)
                                  int newAppendedCount = 0;
                                  for (
                                    int i = messages.length - 1;
                                    i >= 0;
                                    i--
                                  ) {
                                    final m = messages[i];
                                    if (_previousLastMessage != null &&
                                        m.text == _previousLastMessage!.text &&
                                        m.created_at ==
                                            _previousLastMessage!.created_at) {
                                      break; // found the old boundary
                                    }
                                    newAppendedCount++;
                                  }

                                  // If messages were added at the end, trigger badge / scroll
                                  // Note: If newAppendedCount == 0, it means it was an older history fetch at the top, so we ignore it completely!
                                  if (newAppendedCount > 0 &&
                                      newAppendedCount < messages.length) {
                                    final lastIsMe = messages.last.isSentByMe;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (_isAtBottom || lastIsMe) {
                                            _scrollToBottom();
                                            context
                                                .read<PrivateChatProvider>()
                                                .markAsRead();
                                          } else {
                                            setState(
                                              () => _unreadCount +=
                                                  newAppendedCount,
                                            );
                                          }
                                        });
                                  }
                                }
                              }

                              _previousMessageCount = messages.length;
                              _previousLastMessage = messages.isNotEmpty
                                  ? messages.last
                                  : null;

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _updateFloatingDate();

                                // Auto-fetch more history if the layout is underfilled (e.g., large screen or few messages)
                                if (_scrollController.hasClients) {
                                  final maxScroll = _scrollController
                                      .position
                                      .maxScrollExtent;
                                  if (maxScroll <= 50 &&
                                      !context
                                          .read<PrivateChatProvider>()
                                          .isLoadingHistory) {
                                    context
                                        .read<PrivateChatProvider>()
                                        .fetchMoreHistory();
                                  }
                                }
                              });

                              if (messages.isEmpty && !isLoading) {
                                return Center(
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.nomessagesyetstarttheconversation ??
                                        'No messages yet...',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 12.5,
                                      color: txt.muted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }

                              final reversedMessages = messages.reversed
                                  .toList();
                              return ListView.builder(
                                reverse: true,
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                itemCount: reversedMessages.length + 1,
                                itemBuilder: (ctx, index) {
                                  if (index == reversedMessages.length) {
                                    return _buildHistoryLoader(isLoading);
                                  }

                                  final message = reversedMessages[index];
                                  bool showHeader = false;
                                  bool isAbsoluteOldestMessage = false;

                                  if (index == reversedMessages.length - 1) {
                                    showHeader = true;
                                    isAbsoluteOldestMessage = true;
                                  } else {
                                    final previousMessage =
                                        reversedMessages[index + 1];
                                    showHeader = !_isSameDay(
                                      message.created_at,
                                      previousMessage.created_at,
                                    );
                                  }

                                  if (showHeader) {
                                    final dateStr = _getDateSeparator(
                                      message.created_at,
                                    );
                                    if (!_headerKeys.containsKey(dateStr)) {
                                      _headerKeys[dateStr] = GlobalKey(
                                        debugLabel: dateStr,
                                      );
                                    }

                                    bool hideInlineDate =
                                        isAbsoluteOldestMessage &&
                                        context
                                            .read<PrivateChatProvider>()
                                            .hasMoreHistory;

                                    if (hideInlineDate) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            key: _headerKeys[dateStr],
                                            height: 0,
                                            width: 0,
                                          ),
                                          _buildMessageBubble(ctx, message),
                                        ],
                                      );
                                    }

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          key: _headerKeys[dateStr],
                                          margin: EdgeInsets.symmetric(
                                            vertical: 10.h,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 3.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                : const Color(0xFFF2F2F2),
                                            borderRadius: BorderRadius.circular(
                                              5.r,
                                            ),
                                          ),
                                          child: Text(
                                            dateStr,
                                            style: TextStyle(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w500,
                                              color: txt.body,
                                            ),
                                          ),
                                        ),
                                        _buildMessageBubble(ctx, message),
                                      ],
                                    );
                                  }

                                  return _buildMessageBubble(ctx, message);
                                },
                              );
                            },
                          ),

                          // ── Scroll-to-bottom FAB ─────────────────────────────────
                          _buildScrollToBottomButton(),

                          // ── Sticky Floating Date Header ─────────────────────────
                          if (_floatingDate != null)
                            Positioned(
                              top: -10.h,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  margin: EdgeInsets.symmetric(vertical: 10.h),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer
                                        : const Color(0xFFF2F2F2),
                                    borderRadius: BorderRadius.circular(5.r),
                                  ),
                                  child: Text(
                                    _floatingDate ?? '',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w500,
                                      color: txt.body,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Input bar ─────────────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(5, 5, 12, 15).w,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onChanged: (_) => context
                                  .read<PrivateChatProvider>()
                                  .onUserTyping(),
                              cursorColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.8),
                              cursorWidth: 1.5,
                              maxLines: 5,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                filled: true, 
                                fillColor: Theme.of(context).colorScheme.background,
                                border: InputBorder.none,
                                hintText:
                                    '${AppLocalizations.of(context)?.message}...',
                                hintStyle: AppTextStyles.bodyText.copyWith(
                                  color: const Color(0XFF898989),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 10.h,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Theme.of(context).colorScheme.outline
                                        : const Color(0xFFDDDDDD),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Theme.of(context).colorScheme.outline
                                        : const Color(0xFFDDDDDD),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                              ),
                              style: AppTextStyles.bodyText.copyWith(
                                color: txt.title,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              margin: const EdgeInsets.only(left: 12),
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                FeatherIcons.send,
                                size: 17.spMax,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Animated typing dot ────────────────────────────────────────────────────────
class _AnimatedDot extends StatefulWidget {
  final Duration delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 3.5,
          height: 3.5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
