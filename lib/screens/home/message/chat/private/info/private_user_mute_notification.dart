// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../../api/api_service.dart';
import '../../../../../../../core/constants/app_colors.dart';
import '../../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../../widgets/show_toast.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../message_list.dart';

class PrivateUserMuteNotification extends StatefulWidget {
  final dynamic chatId;
  final dynamic isMute;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? chatData;

  const PrivateUserMuteNotification({
    super.key,
    this.chatId,
    this.isMute = false,
    this.userData,
    this.chatData,
  });

  @override
  State<PrivateUserMuteNotification> createState() =>
      _PrivateUserMuteNotificationState();
}

class _PrivateUserMuteNotificationState
    extends State<PrivateUserMuteNotification> {
  late bool _isMuteChat;
  final ApiService _apiService = ApiService();

  bool _toBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val != 0;
    final str = val.toString().toLowerCase().trim();
    return str == 'true' || str == '1';
  }

  bool _parseIsMuted(
    dynamic val,
    Map<String, dynamic>? data1,
    Map<String, dynamic>? data2,
  ) {
    final data = data1 ?? data2;
    if (data != null) {
      final muted = data['is_muted'] ?? data['is_mute'] ?? data['isMuted'];
      if (muted != null) return _toBool(muted);
    }
    return _toBool(val);
  }

  @override
  void initState() {
    super.initState();
    _isMuteChat = _parseIsMuted(
      widget.isMute,
      widget.userData,
      widget.chatData,
    );
  }

  @override
  void didUpdateWidget(covariant PrivateUserMuteNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMute != widget.isMute ||
        oldWidget.userData != widget.userData ||
        oldWidget.chatData != widget.chatData) {
      _isMuteChat = _parseIsMuted(
        widget.isMute,
        widget.userData,
        widget.chatData,
      );
    }
  }

  Future<void> _toggleMute(bool value) async {
    setState(() {
      _isMuteChat = value;
    });

    final chatId = widget.chatId?.toString();
    if (chatId != null && chatId.isNotEmpty) {
      try {
        final res = await _apiService.muteUnmuteChat(
          chatId: chatId,
          isMuted: value,
          muteUntil: value
              ? DateTime.now().add(
                  const Duration(days: 365 * 10),
                )
              : null,
        );
        debugPrint('muteUnmuteChat result: $res');

        final apiMutedVal = res['is_muted'] ?? res['data']?['is_muted'];
        final success =
            res['success'] ?? (apiMutedVal != null ? true : null) ?? true;

        if (!success) {
          if (mounted) {
            setState(() {
              _isMuteChat = !value;
            });
          }
          MessageListState.toggleMuteChatLocally(chatId, !value);
          showToast(message: 'Failed to update mute setting');
        } else {
          final apiMuted = apiMutedVal != null
              ? (apiMutedVal == true ||
                    apiMutedVal == 1 ||
                    apiMutedVal.toString() == 'true')
              : value;
          if (mounted) {
            setState(() {
              _isMuteChat = apiMuted;
            });
          }
          MessageListState.toggleMuteChatLocally(chatId, apiMuted);
          showToast(
            message:
                apiMuted ? 'Notifications muted' : 'Notifications unmuted',
          );
        }
      } catch (e) {
        debugPrint('Error muting chat: $e');
        if (mounted) {
          setState(() {
            _isMuteChat = !value;
          });
        }
        MessageListState.toggleMuteChatLocally(chatId, !value);
        showToast(message: 'Failed to update mute setting');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context, _isMuteChat);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title:  AppLocalizations.of(context)!.notificationsettings,
          onBack: () => Navigator.pop(context, _isMuteChat),
        ),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.mutechat,
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.title,
                      fontSize: 13.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 18.h,
                    child: Transform.scale(
                      scale: 0.85,
                      child: CupertinoSwitch(
                        activeTrackColor: AppColors.primaryColor,
                        value: _isMuteChat,
                        onChanged: _toggleMute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
