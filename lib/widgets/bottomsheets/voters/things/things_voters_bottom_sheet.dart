// common/voters/things_voters_bottom_sheet.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/poll/poll_results_model.dart';
import '../../../../models/voters/top_voters_model.dart';
import '../../../../models/voters/things_voter_tile.dart';
import '../../../../models/voters/things_voters_models.dart';
import '../../../shimmer/things_voter_tile_shimmer.dart';

class ThingsVotersBottomSheet extends StatefulWidget {
  final int pollId;
  final String pollQuestion;
  final int postId;
  final List<ThingsVoterPollOption> options;

  const ThingsVotersBottomSheet({
    super.key,
    required this.pollId,
    required this.pollQuestion,
    required this.postId,
    required this.options,
  });

  @override
  State<ThingsVotersBottomSheet> createState() =>
      _ThingsVotersBottomSheetState();
}

class _ThingsVotersBottomSheetState extends State<ThingsVotersBottomSheet>
    with UtilityMixin {
  final Map<int, ThingsOptionVoterState> _optionStates = {};
  final Map<int, int> _rank1Counts = {};

  @override
  void initState() {
    super.initState();
    _fetchPollResults();
    _fetchAll();
  }

  Future<void> _fetchPollResults() async {
    try {
      final Map<String, dynamic> response = await ApiService().getPollResults(
        widget.postId,
      );

      if (!mounted) return;
      if (response['status'] != 'success') return;

      final model = PollResultsModel.fromJson(response);
      setState(() {
        for (final r in model.results) {
          _rank1Counts[r.optionId] = r.rank1Count;
        }
      });
    } catch (e) {
      debugPrint('Error fetching poll results: $e');
    }
  }

  Future<void> _fetchAll() async {
    final futures = widget.options.map((option) async {
      await _loadOption(option);
    });
    await Future.wait(futures);
  }

  Future<void> _loadOption(ThingsVoterPollOption option) async {
    try {
      final result = await ApiService.getTopVoters(
        pollId: widget.pollId,
        optionId: option.id,
      );
      if (!mounted) return;
      setState(() {
        _optionStates[option.id] = ThingsOptionVoterState(
          isLoading: false,
          voters: _parseVoters(result),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optionStates[option.id] = ThingsOptionVoterState(
          isLoading: false,
          error: e.toString(),
        );
      });
    }
  }

  List<ThingsVoter> _parseVoters(TopVotersModel result) {
    return result.users.map((u) => ThingsVoter.fromTopVoterUser(u)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.voters,
                style: AppTextStyles.sectionHeading.copyWith(color: Theme.of(context).colorScheme.onBackground),
              ),
            ),
          ),

          /*──── Poll question ────*/
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 7.h, 12.w, 12.h),
            child: Text(
              'Q. ${widget.pollQuestion}',
              style: AppTextStyles.bodyText.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ),

          /*──── Scrollable grouped list ────*/
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 10.h),
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final state = _optionStates[option.id];
                final int rank1Count = _rank1Counts[option.id] ?? 0;
                final bool hasRank = rank1Count > 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /*──── Option header ────*/
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.text,
                              style: AppTextStyles.bodyText.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color.fromARGB(255, 89, 89, 89),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasRank)
                            Row(
                              children: [
                                Text(
                                  '$rank1Count',
                                  style: AppTextStyles.subText.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground.withOpacity(0.5),
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                Icon(
                                  Icons.star,
                                  size: 14.sp,
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    /*──── Divider ────*/
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Divider(
                        height: 2,
                        thickness: 0.6,
                        indent: 10.w,
                        endIndent: 10.w,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.2),
                      ),
                    ),

                    /*──── Voter rows or states ────*/
                    if (state == null || state.isLoading)
                      Column(
                        children: List.generate(
                          3,
                          (_) => const ThingsVoterTileShimmer(),
                        ),
                      )
                    else if (state.error != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 14.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.7),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Failed to load',
                              style: AppTextStyles.subText.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _optionStates[option.id] =
                                      ThingsOptionVoterState();
                                });
                                _loadOption(option);
                              },
                              child: Text(
                                'Retry',
                                style: AppTextStyles.subText.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (state.voters.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        child: Text(
                          'No votes yet',
                          style: AppTextStyles.subText.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      )
                    else
                      ...state.voters.map((v) => ThingsVoterTile(voter: v)),

                    SizedBox(height: 8.h),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
