// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../../../provider/user_provider.dart';

import '../../../../../../api/api_config.dart';
import '../../../../../../api/api_service.dart';
import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../core/utils/bottomsheet_util.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../models/posts/single_post_model.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/connection/no_internet_screen.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../profile/public/public_profile_screen.dart';
import 'image_preview_screen.dart';

class ImageResultScreen extends StatefulWidget {
  final String username;
  final String postId;

  const ImageResultScreen({
    super.key,
    required this.username,
    required this.postId,
  });

  @override
  State<ImageResultScreen> createState() => _ImageResultScreenState();
}

class _ImageResultScreenState extends State<ImageResultScreen>
    with UtilityMixin {
  final ApiService _apiService = ApiService();

  SinglePostModel? _post;
  bool _isLoading = true;
  String? _error;

  Uint8List? _profileImageBytes;

  late List<SinglePostPollOption> _sortedOptions;
  late int _totalVotes;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    try {
      final post = await _apiService.getSinglePost(
        widget.username,
        widget.postId,
      );
      _prepareDisplayData(post);

      Uint8List? imageBytes;
      final imageToDecode = post.user.profileImage.isNotEmpty
          ? post.user.profileImage
          : post.profileImage;
      if (imageToDecode.isNotEmpty) {
        try {
          final raw = imageToDecode.contains(',')
              ? imageToDecode.split(',').last
              : imageToDecode;
          imageBytes = base64Decode(raw);
        } catch (_) {
          imageBytes = null;
        }
      }

      if (mounted) {
        setState(() {
          _post = post;
          _profileImageBytes = imageBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _prepareDisplayData(SinglePostModel post) {
    final poll = post.polls.isNotEmpty ? post.polls.first : null;

    if (poll == null) {
      _sortedOptions = [];
      _totalVotes = 0;
      return;
    }

    _sortedOptions = List<SinglePostPollOption>.from(poll.options)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    _totalVotes = poll.options.fold(
      0,
      (sum, o) => sum + (int.tryParse(o.voteCount) ?? 0),
    );
  }

  String timeAgo(String createdAt) {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} h ago';
      if (diff.inDays < 7) return '${diff.inDays} d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mo ago';
      return '${(diff.inDays / 365).floor()} y ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.pollresult),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Loader(color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    if (_error != null || _post == null) {
      return ConnectionErrorScreen(
        type: ConnectionErrorType.unknown,
        errorMessage: _error,
        onRetry: () {
          setState(() {
            _error = null;
            _isLoading = true;
          });
          _fetchPost();
        },
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12),
      children: [
        _buildHeader(),
        SizedBox(height: 10.h),
        _buildQuestion(),
        SizedBox(height: 16.h),
        ..._sortedOptions.map(
          (option) => _buildResultCard(option, _post!.polls.first.id),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final txt = AppTextColors.of(context);

    // final id = _post!.id;
    final firstName = _post!.firstName;
    final lastName = _post!.lastName;
    final username = _post!.user.username;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'P';
    // final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            navigationPush(
              context,
              PublicProfileScreen(userId: _post!.user.uuid, username: username),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.15),
            backgroundImage: _profileImageBytes != null
                ? MemoryImage(_profileImageBytes!)
                : (_post!.user.profileImage.isNotEmpty
                      ? NetworkImage(_post!.user.profileImage)
                      : null),
            child:
                _profileImageBytes == null && _post!.user.profileImage.isEmpty
                ? Text(
                    initial,
                    style: AppTextStyles.subText.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),

        SizedBox(width: 10.w),

        // Username + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$firstName $lastName',
                style: AppTextStyles.sectionHeading.copyWith(
                  color: txt.title,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Text(
                    '@$username',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: txt.body,
                    ),
                  ),
                  Text(
                    '  • ${timeAgo(_post!.createdAt)}',
                    style: AppTextStyles.subText.copyWith(
                      color: txt.muted,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Total votes
        GestureDetector(
          onTap: () {
            final poll = _post?.polls.isNotEmpty == true
                ? _post!.polls.first
                : null;
            if (poll == null) return;

            if (poll.pollType == 'anonymous') {
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              final isOwner = _post?.user.uuid == userProvider.userId;
              if (!isOwner) return;
            }

            final firstOptionImage = poll.options.isNotEmpty == true
                ? poll.options
                      .firstWhere(
                        (o) => o.image != null,
                        orElse: () => poll.options.first,
                      )
                      .image
                      ?.resolvedUrl(ApiConfig.baseUrlImage)
                : null;

            BottomSheetUtils.showPollVotersBottomSheet(
              context: context,
              postId: _post!.id,
              question: poll.question,
              pollImageUrl: firstOptionImage,
              pollType: poll.pollType,
            );
          },
          child: Text(
            '${AppLocalizations.of(context)!.totalvotes}: $_totalVotes',
            style: AppTextStyles.subText.copyWith(
              fontSize: 12.7,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final question = _post!.polls.isNotEmpty ? _post!.polls.first.question : '';

    return Text(
      question,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onBackground,
      ),
    );
  }

  Widget _buildResultCard(SinglePostPollOption option, dynamic pollId) {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final imageUrl = option.image != null
        ? option.image!.resolvedUrl(ApiConfig.baseUrlImage)
        : '';

    final int votes = int.tryParse(option.voteCount) ?? 0;
    final double pct = option.percentage;
    final int rank = _sortedOptions.indexOf(option) + 1;
    final String rankLabel = rank == 1 ? 'Top pick' : 'Ranked #$rank';

    final poll = _post?.polls.isNotEmpty == true ? _post!.polls.first : null;

    return GestureDetector(
      onTap: () {
        if (poll == null) return;

        if (poll.pollType == 'anonymous') {
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final isOwner = _post?.user.uuid == userProvider.userId;
          if (!isOwner) return;
        }

        final firstOptionImage = poll.options.isNotEmpty == true
            ? poll.options
                  .firstWhere(
                    (o) => o.image != null,
                    orElse: () => poll.options.first,
                  )
                  .image
                  ?.resolvedUrl(ApiConfig.baseUrlImage)
            : null;

        final pollImageUrl = imageUrl.isNotEmpty ? imageUrl : firstOptionImage;

        BottomSheetUtils.showPollVotersBottomSheet(
          context: context,
          postId: _post!.id,
          question: poll.question,
          pollImageUrl: pollImageUrl,
          pollType: poll.pollType,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0XFF9B3046).withOpacity(0.09),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Tappable image ───────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                if (imageUrl.isEmpty) return;

                final urls = _sortedOptions
                    .where((o) => o.image != null)
                    .map((o) => o.image!.resolvedUrl(ApiConfig.baseUrlImage))
                    .toList();

                final tappedIndex = urls.indexOf(imageUrl);

                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ImagePreviewScreen(
                      imageUrls: urls,
                      initialIndex: tappedIndex >= 0 ? tappedIndex : 0,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),

            SizedBox(width: 12.w),

            // ── Text + bar ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.text?.isNotEmpty == true
                        ? option.text!
                        : 'Option $rank',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: txt.title,
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Rank label derived from sorted position
                  Text(
                    rankLabel,
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 12.5,
                      color: txt.muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Progress bar + vote count
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(
                              begin: 0,
                              end: (pct / 100).clamp(0.0, 1.0),
                            ),
                            builder: (_, value, __) => LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: isDarkMode
                                  ? const Color(0xFF2D2D2D)
                                  : const Color(0xFFF6F3F2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        '$votes ${AppLocalizations.of(context)!.votes}',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: txt.muted,
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
    );
  }

  // ── Placeholder ───────────────────────────────────────────────────────────

  Widget _imagePlaceholder() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xA22E2E2E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          size: 28,
        ),
      ),
    );
  }
}
