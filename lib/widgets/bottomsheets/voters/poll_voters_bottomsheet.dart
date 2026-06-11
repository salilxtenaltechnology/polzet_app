// ignore_for_file: deprecated_member_use
import 'dart:typed_data';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile_screen.dart';

import '../../../api/api_config.dart';
import '../../../api/services/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../models/poll/poll_results_model.dart';
import '../../base64/image_convert.dart';
import '../../loader.dart';

class PollVotersBottomsheet extends StatefulWidget {
  final dynamic postId;
  final String question;
  final String? pollImageUrl;

  const PollVotersBottomsheet({
    super.key,
    required this.postId,
    required this.question,
    this.pollImageUrl,
  });

  @override
  State<PollVotersBottomsheet> createState() => _PollVotersBottomsheetState();
}

class _PollVotersBottomsheetState extends State<PollVotersBottomsheet>
    with UtilityMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<IndividualResult> _individualResults = [];
  List<IndividualResult> _filteredResults = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVoterResults();
    debugPrint('POST_ID: ${widget.postId}');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVoterResults() async {
    try {
      final response = await _apiService.getPollResults(widget.postId);
      if (mounted) {
        setState(() {
          _individualResults = response.data.individualResults;
          _filteredResults = response.data.individualResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _filterVoters(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredResults = _individualResults;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredResults = _individualResults
            .where(
              (res) =>
                  res.user.username.toLowerCase().contains(lowerQuery) ||
                  res.user.fullName.toLowerCase().contains(lowerQuery),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.voters,
                style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
              ),
            ),
          ),

          // Question Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.pollImageUrl != null &&
                    widget.pollImageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(
                      widget.pollImageUrl!,
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 45,
                        height: 45,
                        color: isDarkMode
                            ? const Color(0xFF27272A)
                            : const Color(0xFFF4F4F5),
                        child: Icon(Icons.poll, color: txt.muted, size: 20.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            height: 43,
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
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
              onChanged: _filterVoters,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(
                  right: 12.w,
                  left: 12.w,
                  top: 10.h,
                ),
                hintText: AppLocalizations.of(context)!.searchvoters,
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
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.7,
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
            ),
          ),

          SizedBox(height: 10.h),

          // Voter List View / Shimmer
          Expanded(
            child: _isLoading
                ? Center(
                    child: Loader(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.subText.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _filteredResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isDarkMode
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Image.asset(
                                  Assets.images.noVotes.path,
                                  height: 0.18.sh,
                                  width: 0.18.sh,
                                  fit: BoxFit.contain,
                                ),
                              ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocalizations.of(context)!.novotersfound,
                          style: AppTextStyles.sectionHeading.copyWith(
                            fontSize: 18.5,
                            color: Theme.of(context).colorScheme.onBackground,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: 24.h),
                    itemCount: _filteredResults.length,
                    itemBuilder: (context, index) {
                      final result = _filteredResults[index];
                      final voter = result.user;

                      // Process avatar bytes if base64 encoded
                      Uint8List? avatarBytes;
                      if (voter.profilePictureUrl != null &&
                          voter.profilePictureUrl!.isNotEmpty) {
                        try {
                          avatarBytes = getProfileImage(
                            voter.profilePictureUrl,
                          );
                        } catch (_) {
                          avatarBytes = null;
                        }
                      }

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF212121).withOpacity(0.4)
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x06000000), blurRadius: 2),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Voter Info Row
                            GestureDetector(
                              onTap: () {
                                navigationPush(
                                  context,
                                  PublicProfileScreen(userId: voter.id),
                                );
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: avatarBytes != null
                                        ? MemoryImage(avatarBytes)
                                        : null,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.1),
                                    child: avatarBytes == null
                                        ? Text(
                                            voter.fullName.isNotEmpty
                                                ? voter.fullName[0]
                                                      .toUpperCase()
                                                : voter.username.isNotEmpty
                                                ? voter.username[0]
                                                      .toUpperCase()
                                                : 'P',
                                            style: AppTextStyles.bodyText
                                                .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                      .withOpacity(0.7),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          voter.fullName.isNotEmpty
                                              ? voter.fullName
                                              : voter.username,
                                          style: AppTextStyles.sectionHeading
                                              .copyWith(
                                                color: txt.title,
                                                fontSize: 13.5,
                                              ),
                                        ),
                                        Text(
                                          '@${voter.username}',
                                          style: AppTextStyles.bodyText
                                              .copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: txt.body,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Horizontally Scrollable / Row of Ranked Choices
                            (() {
                              final sortedRanks = List<UserRank>.from(
                                result.ranks,
                              )..sort((a, b) => a.rank.compareTo(b.rank));

                              final hasAnyImage = sortedRanks.any(
                                (r) =>
                                    r.imageUrl != null &&
                                    r.imageUrl!.isNotEmpty,
                              );

                              if (hasAnyImage) {
                                // Image posts: original start-aligned simple row
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: sortedRanks.map((rankItem) {
                                      final hasImage =
                                          rankItem.imageUrl != null &&
                                          rankItem.imageUrl!.isNotEmpty;
                                      final optImgUrl = hasImage
                                          ? (rankItem.imageUrl!.startsWith(
                                                  'http',
                                                )
                                                ? rankItem.imageUrl!
                                                : ApiConfig.baseUrlImage +
                                                      rankItem.imageUrl!)
                                          : null;

                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: 12.w,
                                          top: 4.h,
                                        ),
                                        child: SizedBox(
                                          width: 58,
                                          height: 58,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                left: 0,
                                                bottom: 0,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.button,
                                                      ),
                                                  child: SizedBox(
                                                    width: 50,
                                                    height: 50,
                                                    child: optImgUrl != null
                                                        ? Image.network(
                                                            optImgUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) => Container(
                                                                  color:
                                                                      isDarkMode
                                                                      ? const Color(
                                                                          0xFF38383C,
                                                                        )
                                                                      : Colors
                                                                            .grey
                                                                            .shade100,
                                                                  child: Icon(
                                                                    Icons
                                                                        .image_not_supported,
                                                                    color: txt
                                                                        .muted,
                                                                    size: 16.sp,
                                                                  ),
                                                                ),
                                                          )
                                                        : Container(
                                                            color: isDarkMode
                                                                ? const Color(
                                                                    0xFF38383C,
                                                                  )
                                                                : Colors
                                                                      .grey
                                                                      .shade100,
                                                            child: Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              color: txt.muted,
                                                              size: 16.sp,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF9E2C43,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .tertiaryContainer,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${rankItem.rank}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              } else {
                                // Text polls: full-width space-between row
                                return Row(
                                  children: List.generate(sortedRanks.length, (
                                    idx,
                                  ) {
                                    final rankItem = sortedRanks[idx];
                                    final isLast =
                                        idx == sortedRanks.length - 1;

                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: isLast ? 0.0 : 8.w,
                                          top: 6.h,
                                          bottom: 6.h,
                                        ),
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              margin: EdgeInsets.only(
                                                top: 4.h,
                                                right: 6.w,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? const Color(
                                                        0xFF38383C,
                                                      ).withOpacity(0.4)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.card,
                                                    ),
                                                border: Border.all(
                                                  color: isDarkMode
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.outline
                                                      : const Color(0xFFE5E5E5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                rankItem.text ?? '',
                                                style: AppTextStyles.bodyText
                                                    .copyWith(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: txt.title,
                                                    ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: 0,
                                              child: Container(
                                                alignment: Alignment.center,
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF9E2C43,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${rankItem.rank}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              }
                            })(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
