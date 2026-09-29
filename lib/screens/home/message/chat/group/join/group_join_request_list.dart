// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/api_service.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:polzet_app/widgets/show_toast.dart';

class GroupJoinRequestList extends StatefulWidget {
  final dynamic chatId;
  final List<Map<String, dynamic>>? initialRequests;

  const GroupJoinRequestList({super.key, this.chatId, this.initialRequests});

  @override
  State<GroupJoinRequestList> createState() => _GroupJoinRequestListState();
}

class _GroupJoinRequestListState extends State<GroupJoinRequestList>
    with UtilityMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _approvingIds = {};
  final Set<String> _rejectingIds = {};

  List<Map<String, dynamic>> _sortJoinRequests(
    List<Map<String, dynamic>> list,
  ) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final aDateStr = (a['requested_at'] ?? a['created_at'] ?? a['timestamp'])
          ?.toString();
      final bDateStr = (b['requested_at'] ?? b['created_at'] ?? b['timestamp'])
          ?.toString();
      final aDate = aDateStr != null ? DateTime.tryParse(aDateStr) : null;
      final bDate = bDateStr != null ? DateTime.tryParse(bDateStr) : null;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate); // Recent first
    });
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialRequests != null && widget.initialRequests!.isNotEmpty) {
      _requests = _sortJoinRequests(widget.initialRequests!);
    } else {
      _isLoading = true;
    }
    _fetchJoinRequests();
  }

  Future<void> _fetchJoinRequests() async {
    final chatId = widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await _apiService.getGroupJoinRequestsList(chatId: chatId);
      List<Map<String, dynamic>> list = [];
      if (res['data'] is List) {
        list = List<Map<String, dynamic>>.from(res['data']);
      } else if (res['results'] is List) {
        list = List<Map<String, dynamic>>.from(res['results']);
      } else if (res['join_requests'] is List) {
        list = List<Map<String, dynamic>>.from(res['join_requests']);
      }

      if (mounted) {
        setState(() {
          _requests = _sortJoinRequests(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching join requests: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _user(Map<String, dynamic> req) {
    if (req['user'] is Map) {
      return Map<String, dynamic>.from(req['user'] as Map);
    }
    return req;
  }

  String _extractRequestId(Map<String, dynamic> req) {
    final userMap = _user(req);
    return (req['request_id'] ?? req['id'] ?? req['public_id'] ?? userMap['id'])
            ?.toString() ??
        '';
  }

  Future<void> _approveRequest(Map<String, dynamic> req) async {
    final chatId = widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final requestId = _extractRequestId(req);
    if (requestId.isEmpty) return;

    if (_approvingIds.contains(requestId) ||
        _rejectingIds.contains(requestId)) {
      return;
    }
    setState(() => _approvingIds.add(requestId));

    try {
      final res = await _apiService.approveGroupJoinRequest(
        chatId: chatId,
        requestId: requestId,
      );
      if (mounted) {
        final isSuccess =
            res['status'] != 'error' &&
            res['success'] != false &&
            (res['status'] == 'success' ||
                res['status'] == 200 ||
                res['success'] == true ||
                res['message']?.toString().toLowerCase().contains('success') ==
                    true ||
                res['message']?.toString().toLowerCase().contains('approved') ==
                    true);
        final msg = res['message']?.toString() ?? 'Join request approved.';
        showToast(message: msg);

        if (isSuccess) {
          setState(() {
            _requests.removeWhere((r) {
              final rId = _extractRequestId(r);
              return rId == requestId;
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          message:
              'Failed to approve request: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _approvingIds.remove(requestId));
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> req) async {
    final chatId = widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final requestId = _extractRequestId(req);
    if (requestId.isEmpty) return;

    if (_approvingIds.contains(requestId) ||
        _rejectingIds.contains(requestId)) {
      return;
    }
    setState(() => _rejectingIds.add(requestId));

    try {
      final res = await _apiService.rejectGroupJoinRequest(
        chatId: chatId,
        requestId: requestId,
      );
      if (mounted) {
        final isSuccess =
            res['status'] != 'error' &&
            res['success'] != false &&
            (res['status'] == 'success' ||
                res['status'] == 200 ||
                res['success'] == true ||
                res['message']?.toString().toLowerCase().contains('success') ==
                    true ||
                res['message']?.toString().toLowerCase().contains('rejected') ==
                    true);
        final msg = res['message']?.toString() ?? 'Join request rejected.';
        showToast(message: msg);

        if (isSuccess) {
          setState(() {
            _requests.removeWhere((r) {
              final rId = _extractRequestId(r);
              return rId == requestId;
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          message:
              'Failed to reject request: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _rejectingIds.remove(requestId));
      }
    }
  }

  Widget _buildAvatar(
    String? profileUrl,
    String username,
    bool isDarkMode, {
    double size = 42,
  }) {
    final resolved = resolveProfileImageUrl(profileUrl);
    final bytes = profileUrl != null ? getProfileImage(profileUrl) : null;
    final ImageProvider? provider = bytes != null
        ? MemoryImage(bytes)
        : (resolved != null && resolved.startsWith('http')
              ? NetworkImage(resolved)
              : (resolved != null && resolved.startsWith('assets/')
                    ? AssetImage(resolved)
                    : null));

    final double effectiveSize = size.w;

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? const Color(0xFF252525)
            : Theme.of(context).primaryColor.withOpacity(0.08),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : DecorationImage(
                image: AssetImage(Assets.images.icAvatar.path),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Join Requests'),
      body: _isLoading && _requests.isEmpty
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : RefreshIndicator(
              onRefresh: _fetchJoinRequests,
              color: Theme.of(context).colorScheme.primary,
              child: _requests.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Text(
                          'No join requests',
                          style: AppTextStyles.bodyText.copyWith(
                            color: txt.muted,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        final userMap = _user(req);
                        final requestId = _extractRequestId(req);
                        final isApproving = _approvingIds.contains(requestId);
                        final isRejecting = _rejectingIds.contains(requestId);
                        final isProcessing = isApproving || isRejecting;

                        final username =
                            (userMap['username'] ??
                                    userMap['name'] ??
                                    req['username'] ??
                                    'User Name')
                                .toString();
                        final firstName =
                            userMap['first_name']?.toString().trim() ?? '';
                        final lastName =
                            userMap['last_name']?.toString().trim() ?? '';
                        final combinedName = '$firstName $lastName'.trim();
                        final fullName = combinedName.isNotEmpty
                            ? combinedName
                            : (userMap['name'] ??
                                      userMap['full_name'] ??
                                      req['name'] ??
                                      username)
                                  .toString();
                        final profilePic =
                            (userMap['profile_picture'] ??
                                    userMap['profile_picture_url'] ??
                                    userMap['avatar_url'] ??
                                    userMap['profile_image'] ??
                                    userMap['profile_url'] ??
                                    userMap['avatar'] ??
                                    req['profile_picture'] ??
                                    req['profile_picture_url'])
                                ?.toString();

                        return Padding(
                          padding: EdgeInsets.only(bottom: 14.h),
                          child: Row(
                            children: [
                              // ── User Avatar ──────────────────────────────
                              _buildAvatar(
                                profilePic,
                                username,
                                isDarkMode,
                                size: 37,
                              ),
                              SizedBox(width: 10.w),

                              // ── Username & Full Name ─────────────────────
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      username,
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: txt.body,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      fullName,
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
                              SizedBox(width: 8.w),

                              // ── Actions: Approve button & Close Icon ──────
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: isProcessing
                                        ? null
                                        : () => _approveRequest(req),
                                    child: Container(
                                      height: 28.h,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 13.w,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isProcessing
                                            ? AppColors.primaryColor
                                                  .withOpacity(0.6)
                                            : AppColors.primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          6.r,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: isApproving
                                          ? SizedBox(
                                              width: 12.w,
                                              height: 12.w,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 1.8,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                            )
                                          : Text(
                                              'Approve',
                                              style: AppTextStyles.cardTitle
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 5.w),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: isProcessing
                                        ? null
                                        : () => _rejectRequest(req),
                                    child: Padding(
                                      padding: EdgeInsets.all(4.w),
                                      child: isRejecting
                                          ? SizedBox(
                                              width: 14.w,
                                              height: 14.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(txt.muted),
                                              ),
                                            )
                                          : Icon(
                                              Icons.close_rounded,
                                              color: isProcessing
                                                  ? txt.muted.withOpacity(0.4)
                                                  : txt.muted,
                                              size: 18.sp,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
