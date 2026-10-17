// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../api/api_config.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../data/cache/poll_topics_cache.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/poll/poll_topic_model.dart';
import '../../../widgets/image/app_cached_network_image.dart';
import '../../../widgets/shimmer/topic_card_shimmer.dart';
import '../new poll/type/new_anonymous_poll.dart';
import '../new poll/type/new_battel_poll.dart';
import '../new poll/type/new_hot_take_poll.dart';
import '../new poll/type/new_image_poll.dart';
import '../new poll/type/new_text_poll.dart';
import '../new poll/type/new_this_or_that.dart';
import 'poll_ideas.dart';

class PollTopics extends StatefulWidget {
  final List<PollTopicModel>? topics;
  final void Function(PollTopicModel topic)? onTopicSelected;

  const PollTopics({super.key, this.topics, this.onTopicSelected});

  @override
  State<PollTopics> createState() => _PollTopicsState();
}

class _PollTopicsState extends State<PollTopics>
    with UtilityMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PollTopicModel> _topicsList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.topics != null && widget.topics!.isNotEmpty) {
      _topicsList = widget.topics!.take(5).toList();
      _isLoading = false;
    } else if (PollTopicsCache.hasCache) {
      _topicsList = PollTopicsCache.topics.take(5).toList();
      _isLoading = false;
      if (PollTopicsCache.isExpired) {
        _loadDynamicTopics(silent: true);
      }
    } else {
      _isLoading = true;
      _loadDynamicTopics(silent: false);
    }
  }

  @override
  void didUpdateWidget(covariant PollTopics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topics != null && widget.topics != oldWidget.topics) {
      setState(() {
        _topicsList = widget.topics!.take(5).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDynamicTopics({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final feedTopics = await PollTopicsCache.loadTopics(
        forceRefresh: !silent && !PollTopicsCache.hasCache,
      );
      if (feedTopics.isNotEmpty && mounted) {
        setState(() {
          _topicsList = feedTopics.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching poll topics feed in PollTopics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onTopicTap(BuildContext context, PollTopicModel topic) {
    if (widget.onTopicSelected != null) {
      widget.onTopicSelected!(topic);
      return;
    }

    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      navigationPush(
        context,
        NewImagePoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('battle') || lower.contains('battel')) {
      navigationPush(
        context,
        NewBattelPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('this') || lower.contains('that')) {
      navigationPush(
        context,
        NewThisOrThat(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('hot') || lower.contains('take')) {
      navigationPush(
        context,
        NewHotTakePoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else if (lower.contains('anon')) {
      navigationPush(
        context,
        NewAnonymousPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    } else {
      navigationPush(
        context,
        NewTextPoll(
          initialQuestion: topic.pollQuestion,
          initialOptions: topic.defaultOptions,
          initialVotingType: topic.votingType,
        ),
      );
    }
  }

  String _getPollTypeIcon(PollTopicModel topic) {
    if (topic.pollTypeIcon != null && topic.pollTypeIcon!.isNotEmpty) {
      return topic.pollTypeIcon!;
    }
    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      return Assets.images.icImagePoll.path;
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return Assets.images.icBattel.path;
    } else if (lower.contains('this') || lower.contains('that')) {
      return Assets.images.icThisThat.path;
    }  else if (lower.contains('hot')) {
      return Assets.images.icHot.path;
    }
    else if (lower.contains('anon')) {
      return Assets.images.icAnonymous.path;
    }
    return Assets.images.icTextPoll.path;
  }

  Color _getPollTypeBadgeColor(BuildContext context, PollTopicModel topic) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (topic.pollTypeColor != null) {
      return topic.pollTypeColor!;
    }
    final lower = topic.pollType.toLowerCase();
    if (lower.contains('image')) {
      return isDarkMode ? const Color(0x33DE42AA) : const Color(0x1ADE42AA);
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return isDarkMode ? const Color(0x33DC2626) : const Color(0x1ADC2626);
    } else if (lower.contains('this') || lower.contains('that')) {
      return isDarkMode ? const Color(0x3316A34A) : const Color(0x1E16A34A);
    } else if (lower.contains('hot')) {
      return isDarkMode ? const Color(0x33EA580C) : const Color(0x1AEA580C);
    } else if (lower.contains('anon')) {
      return isDarkMode ? const Color(0x337C3AED) : const Color(0x1A7C3AED);
    }
    return isDarkMode ? const  Color(0x33C026D3) : const Color(0x1AC026D3);
  }

  String _getPollTypeLabel(BuildContext context, PollTopicModel topic) {
    final lower = topic.pollType.toLowerCase();
    final l10n = AppLocalizations.of(context)!;
    if (lower.contains('image')) {
      return l10n.imagepoll;
    } else if (lower.contains('battle') || lower.contains('battel')) {
      return l10n.battlepoll;
    } else if (lower.contains('this') || lower.contains('that')) {
      return l10n.thisorthat;
    } else if (lower.contains('hot')) {
      return l10n.hottakespoll;
    } else if (lower.contains('anon')) {
      return l10n.anonymouspoll;
    }
    return l10n.textpoll;
  }

  String _resolveBannerUrl(String rawUrl) {
    final value = rawUrl.trim();

    if (value.isEmpty) return '';

    final baseUrl = ApiConfig.baseUrlImage.replaceAll(RegExp(r'/$'), '');

    String url = value.replaceAll('BASE_URL', baseUrl);

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '$baseUrl/${url.replaceFirst(RegExp(r'^/'), '')}';
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '';
    }

    return uri.toString();
  }

  Widget _buildTopicImage(String bannerImageUrl) {
    final imageUrl = _resolveBannerUrl(bannerImageUrl);

    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    return AppCachedNetworkImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildImagePlaceholder(),
      errorWidget: (context, url, error) => _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: Colors.grey),
      ),
    );
  }

  Widget _buildTopicCard(
    BuildContext context,
    PollTopicModel topic,
    double cardWidth,
  ) {
    final txt = AppTextColors.of(context);
    final iconPath = _getPollTypeIcon(topic);
    final badgeBgColor = _getPollTypeBadgeColor(context, topic);

    return GestureDetector(
      onTap: () => _onTopicTap(context, topic),
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll Type Badge
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(iconPath, height: 16, width: 16),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _getPollTypeLabel(context, topic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: txt.title,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Topic Image
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 98,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _buildTopicImage(topic.bannerImageUrl),
              ),
            ),
            const SizedBox(height: 10),

            // Poll Question
            SizedBox(
              height: 38,
              child: Text(
                topic.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Create Poll Button
            GestureDetector(
              onTap: () => _onTopicTap(context, topic),
              child: Container(
                height: 34,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                alignment: Alignment.center,
                child: Text(
                  AppLocalizations.of(context)!.createpoll,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
    super.build(context);
    final txt = AppTextColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
             AppLocalizations.of(context)!.ideasroryou,
              style: AppTextStyles.subText.copyWith(
                color: txt.title,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {
                navigationPush(context, const PollIdeas());
              },
              child: Text(
                AppLocalizations.of(context)!.seeall,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 252,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 10.0;
              // By default exactly 2 cards fit with auto-adjust width in mobile screen
              final double availableWidth =
                  constraints.maxWidth.isFinite && constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width - 20;
              final double cardWidth = (availableWidth - spacing) / 2;

              if (_isLoading && _topicsList.isEmpty) {
                return Row(
                  children: [
                    Expanded(child: ShimmerTopicCard(width: cardWidth)),
                    const SizedBox(width: spacing),
                    Expanded(child: ShimmerTopicCard(width: cardWidth)),
                  ],
                );
              }

              if (_topicsList.isEmpty) {
                return const SizedBox.shrink();
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _topicsList.length,
                separatorBuilder: (_, __) => const SizedBox(width: spacing),
                itemBuilder: (context, index) {
                  return _buildTopicCard(
                    context,
                    _topicsList[index],
                    cardWidth,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
