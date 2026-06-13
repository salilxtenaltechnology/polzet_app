// ignore_for_file: deprecated_member_use, must_be_immutable
import 'dart:ui';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../api/api_config.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../models/message/message_model.dart';
import '../../../../../models/posts/single_post_model.dart';
import '../../../home feed/rank/result/image/image_result_screen.dart';
import '../../../home feed/rank/result/things/things_result_screen.dart';
import '../../../search/posts/rank/single_post_image_ranking.dart';
import '../../../search/posts/rank/single_post_things_ranking.dart';
import '../../../profile/public/public_profile_screen.dart';
import '../../../../../provider/group_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/button/back_button.dart';
import '../chat_details.dart';

class GroupChatScreen extends StatefulWidget {
  final String? groupName;
  final int? chatId;

  final Map<String, dynamic>? chat;
  const GroupChatScreen({
    super.key,
    required this.groupName,
    this.chat,
    required this.chatId,
  });

  @override
  State<GroupChatScreen> createState() => GroupChatScreenState();
}

class GroupChatScreenState extends State<GroupChatScreen>
    with UtilityMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<ChatMessage>> _messagesStream;

  int _previousMessageCount = 0;
  ChatMessage? _previousLastMessage;
  bool _isAtBottom = true;
  int _unreadCount = 0;

  String? _floatingDate;
  final Map<String, GlobalKey> _headerKeys = {};

  GroupChatProvider get provider => context.read<GroupChatProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final userProvider = context.read<UserProvider>();
    _messagesStream = provider.messagesStream;

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.init(
        groupName: widget.groupName,
        groupImageUrl: _avatarUrl,
        chatId: widget.chatId,
        currentUsername: userProvider.username,
        currentUserId: userProvider.userId,
        chat: widget.chat,
      );

      _scrollController.addListener(() {
        if (!_scrollController.hasClients) return;
        if (_scrollController.position.maxScrollExtent > 0 &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 80) {
          _loadMoreHistory();
        }
      });
    });
  }

  Future<void> _loadMoreHistory() async {
    if (!provider.hasMoreHistory || provider.isLoadingHistory) return;
    await provider.fetchMoreHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;

    final wasAtBottom = _isAtBottom;
    _isAtBottom = currentScroll < 100;

    if (wasAtBottom != _isAtBottom) {
      if (mounted) setState(() {});
    }

    if (_isAtBottom && _unreadCount > 0) {
      setState(() => _unreadCount = 0);
      context.read<GroupChatProvider>().markAsRead();
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
      bool hasMore = context.read<GroupChatProvider>().hasMoreHistory;
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
    if (state == AppLifecycleState.resumed) {
      context.read<GroupChatProvider>().reconnect();
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

  String? get _avatarUrl {
    final profileUrl = widget.chat?['profile_url']?.toString();
    if (profileUrl != null && profileUrl.trim().isNotEmpty) {
      return profileUrl;
    }
    return null;
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    context.read<GroupChatProvider>().stopTyping();
    context.read<GroupChatProvider>().sendMessage(text);
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

  Color _getUsernameColor(String username) {
    final colors = [
      const Color(0xFFE53935), // red
      const Color(0xFF8E24AA), // purple
      const Color(0xFF1E88E5), // blue
      const Color(0xFF00897B), // teal
      const Color(0xFFF4511E), // deep orange
      const Color(0xFF6D4C41), // brown
      const Color(0xFF3949AB), // indigo
      const Color(0xFF039BE5), // light blue
      const Color(0xFF43A047), // green
      const Color(0xFFFFB300), // amber
    ];
    int hash = 0;
    for (int i = 0; i < username.length; i++) {
      hash = username.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  void _navigateToPublicProfile(String? userId, String? username) {
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: userId, username: username),
      ),
    );
  }

  Widget _buildMessageStatus(ChatMessage message) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    if (message.isFailed) {
      return Icon(Icons.error_outline, size: 11.sp, color: Colors.redAccent);
    }
    if (message.isPending) {
      return Icon(Icons.check, size: 11.sp, color: Colors.white54);
    }
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
      if (avatarUrlRaw.startsWith('http') || avatarUrlRaw.startsWith('data:image')) {
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
          top: 12,
          bottom: 12,
          left: message.isSentByMe ? 50.w : 12.w,
          right: message.isSentByMe ? 0 : 40.w,
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
                    _navigateToPublicProfile(userId.toString(), username);
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
                            children: [imageWidget],
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

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final avatarUrl = resolveProfileImageUrl(message.senderProfileImage);
    final avatarProvider = avatarUrl != null ? NetworkImage(avatarUrl) : null;

    final String initial = (message.senderUsername?.isNotEmpty == true)
        ? message.senderUsername![0].toUpperCase()
        : 'P';

    final bubble = Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: message.isSentByMe
            ? Theme.of(context).colorScheme.primary
            : (isDarkMode ? const Color(0xFF2A2A2E) : const Color(0xFFF3F4F6)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isSentByMe && message.senderUsername != null)
            Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: GestureDetector(
                onTap: () => _navigateToPublicProfile(
                  message.senderId?.toString(),
                  message.senderUsername,
                ),
                child: Text(
                  message.senderUsername!,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: _getUsernameColor(message.senderUsername!),
                  ),
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4.w,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isSentByMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.onBackground,
                  fontSize: 10.8.sp,
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
                    ),
                  ),
                  SizedBox(width: 3.w),
                  _buildMessageStatus(message),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: message.isSentByMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: message.isSentByMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isSentByMe) ...[
            SizedBox(width: 6.w),
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: GestureDetector(
                onTap: () => _navigateToPublicProfile(
                  message.senderId?.toString(),
                  message.senderUsername,
                ),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.8),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(width: 6.w),
          ],
          if (message.sharedPost != null)
            Expanded(
              child: Column(
                crossAxisAlignment: message.isSentByMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSharedPostCard(context, message),
                  if (message.text.isNotEmpty) bubble,
                ],
              ),
            )
          else
            bubble,
          if (message.isSentByMe) SizedBox(width: 12.w),
        ],
      ),
    );
  }

  Widget _buildHistoryLoader(bool isLoading) {
    if (!isLoading) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildHistoryError(GroupChatProvider provider) {
    if (provider.historyError == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
      color: Colors.red.withOpacity(0.1),
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
    );
  }

  Widget _buildScrollToBottomButton() {
    if (_isAtBottom) return const SizedBox.shrink();
    return Positioned(
      bottom: 35.h,
      right: 14.w,
      child: GestureDetector(
        onTap: () {
          _scrollToBottom();
          setState(() => _unreadCount = 0);
          context.read<GroupChatProvider>().markAsRead();
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

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final provider = context.watch<GroupChatProvider>();
    final groupAvatarUrl = resolveProfileImageUrl(_avatarUrl);
    final groupAvatarProvider = groupAvatarUrl != null ? NetworkImage(groupAvatarUrl) : null;
    final title = provider.groupName ?? widget.groupName ?? 'Chat';

    // We count members based on memberPresence since there's no static members list in the provider
    // Or we could read from widget.chat if available.
    final memberCount =
        widget.chat?['members']?.length ?? provider.memberPresence.length;
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '?';

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
              CircleAvatar(
                radius: 18.r,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.1),
                backgroundImage: groupAvatarProvider,
                child: groupAvatarProvider == null
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
              SizedBox(width: 7.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<GroupChatProvider>(),
                        child: ChatDetails(
                          chatName: title,
                          profileUrl: _avatarUrl,
                          isGroupChat: true,
                          chatId: provider.chatId,
                          chat: widget.chat,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyText.copyWith(
                          color: txt.title,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Consumer<GroupChatProvider>(
                        builder: (_, prov, __) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: prov.isSomeoneTyping
                                ? Row(
                                    key: const ValueKey('typing'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        prov.typingIndicatorText,
                                        style: TextStyle(
                                          fontSize: 9.5.sp,
                                          color: Colors.green,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    key: const ValueKey('status'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      (() {
                                        int otherOnlineCount = prov
                                            .memberPresence
                                            .values
                                            .where(
                                              (m) =>
                                                  m.isOnline &&
                                                  m.userId !=
                                                      prov.currentUserId,
                                            )
                                            .length;

                                        int totalOnline = otherOnlineCount;

                                        String memberText =
                                            '$memberCount ${memberCount == 1 ? AppLocalizations.of(context)!.member : AppLocalizations.of(context)!.members}';

                                        if (otherOnlineCount > 0) {
                                          return Text(
                                            '$totalOnline ${AppLocalizations.of(context)!.online}',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 9.5.sp,
                                              fontWeight: FontWeight.w300,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        } else {
                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: 200.w,
                                            ),
                                            child: Text(
                                              memberText,
                                              style: AppTextStyles.subText
                                                  .copyWith(
                                                    color: txt.muted,
                                                    fontSize: 9.5.sp,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              softWrap: false,
                                            ),
                                          );
                                        }
                                      })(),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
        ),
        body: Column(
          children: [
            if (provider.historyError != null) _buildHistoryError(provider),
            Expanded(
              child: Stack(
                children: [
                  StreamBuilder<List<ChatMessage>>(
                    stream: _messagesStream,
                    initialData: context.read<GroupChatProvider>().messages,
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? [];
                      final isLoading = context
                          .read<GroupChatProvider>()
                          .isLoadingHistory;

                      if (messages.length > _previousMessageCount) {
                        if (_previousMessageCount == 0) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_isAtBottom ||
                                (messages.isNotEmpty &&
                                    messages.last.isSentByMe)) {
                              _scrollToBottom();
                              context.read<GroupChatProvider>().markAsRead();
                            }
                          });
                        } else {
                          int newAppendedCount = 0;
                          for (int i = messages.length - 1; i >= 0; i--) {
                            final m = messages[i];
                            if (_previousLastMessage != null &&
                                m.text == _previousLastMessage!.text &&
                                m.created_at ==
                                    _previousLastMessage!.created_at) {
                              break;
                            }
                            newAppendedCount++;
                          }

                          if (newAppendedCount > 0 &&
                              newAppendedCount < messages.length) {
                            final lastIsMe = messages.last.isSentByMe;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_isAtBottom || lastIsMe) {
                                _scrollToBottom();
                                context.read<GroupChatProvider>().markAsRead();
                              } else {
                                setState(
                                  () => _unreadCount += newAppendedCount,
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

                        if (_scrollController.hasClients) {
                          final maxScroll =
                              _scrollController.position.maxScrollExtent;
                          if (maxScroll <= 50 &&
                              !context
                                  .read<GroupChatProvider>()
                                  .isLoadingHistory) {
                            context
                                .read<GroupChatProvider>()
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

                      final reversedMessages = messages.reversed.toList();
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
                            final previousMessage = reversedMessages[index + 1];
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
                                    .read<GroupChatProvider>()
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
                  _buildScrollToBottomButton(),
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
                              color: txt.title,
                              fontWeight: FontWeight.w500,
                              fontSize: 9.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 45,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(5, 5, 12, 15).w,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: (_) =>
                          context.read<GroupChatProvider>().onUserTyping(),
                      cursorColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: AppLocalizations.of(context)?.message,
                        hintStyle: AppTextStyles.bodyText.copyWith(
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.outline
                                : const Color(0xFFDDDDDD),

                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.outline
                                : const Color(0xFFDDDDDD),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
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
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FeatherIcons.send,
                        size: 16.spMax,
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
    );
  }
}
