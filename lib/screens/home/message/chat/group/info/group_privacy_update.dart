// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/button/primary_button.dart';

class GroupPrivacyUpdate extends StatefulWidget {
  final String initialPrivacy;
  const GroupPrivacyUpdate({super.key, this.initialPrivacy = 'Public'});

  @override
  State<GroupPrivacyUpdate> createState() => _GroupPrivacyUpdateState();
}

class _GroupPrivacyUpdateState extends State<GroupPrivacyUpdate> {
  late String _selectedPrivacy;

  final List<Map<String, String>> _privacyOptions = [
    {
      'value': 'Public',
      'title': 'Public',
      'subtitle': 'Anyone can discover and view group',
      'image': Assets.images.icPublic.path,
    },
    {
      'value': 'Private',
      'title': 'Private',
      'subtitle': 'Only members can see and participate in this group',
      'image': Assets.images.icSecurity.path,
    },
    {
      'value': 'Invite Only',
      'title': 'Invite Only',
      'subtitle': 'Only people you invite can join group',
      'image': Assets.images.icEmail.path,
    },
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPrivacy.trim().toLowerCase();
    if (initial == 'private') {
      _selectedPrivacy = 'Private';
    } else if (initial == 'invite_only' ||
        initial == 'invite only' ||
        initial == 'inviteonly') {
      _selectedPrivacy = 'Invite Only';
    } else {
      _selectedPrivacy = 'Public';
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool hasChanged = _selectedPrivacy != widget.initialPrivacy;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Group Privacy'),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: _privacyOptions.map((opt) {
            final isSelected = _selectedPrivacy == opt['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPrivacy = opt['value']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF161821)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isDarkMode
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08)),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 2),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        opt['image']!,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['title']!,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: txt.title,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          Text(
                            opt['subtitle']!,
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: 'Save Changes',
          onPressed: hasChanged
              ? () {
                  Navigator.pop(context, _selectedPrivacy);
                }
              : null,
          isLoading: false,
        ),
      ),
    );
  }
}
