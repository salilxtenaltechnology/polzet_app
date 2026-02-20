// ignore_for_file: must_be_immutable, deprecated_member_use

import 'dart:convert';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/widgets/custom_card.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../../provider/group_chat_provider.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/custom_text_styles.dart';

class GroupMembers extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final int chatId;
  const GroupMembers({super.key, required this.members, required this.chatId});

  @override
  State<GroupMembers> createState() => _GroupMembersState();
}

class _GroupMembersState extends State<GroupMembers> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.members);
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() => _applyFilter(
      context.read<GroupChatProvider>().members); // always filter from provider

  void _applyFilter(List<Map<String, dynamic>> source) {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(source)
          : source.where((m) {
              final name =
                  (_user(m)['username'] ?? '').toString().toLowerCase();
              return name.contains(q);
            }).toList();
    });
  }

  Map<String, dynamic> _user(Map<String, dynamic> m) =>
      Map<String, dynamic>.from(m['user'] as Map? ?? {});

  bool _isCurrentUserAdmin(List<Map<String, dynamic>> members) {
    final id = context.read<UserProvider>().userId;
    for (final m in members) {
      if (_user(m)['id'] == id) return m['is_admin'] == true;
    }
    return false;
  }

  Future<void> _removeMember(int userId) async {
    final provider = context.read<GroupChatProvider>();
    final success = await provider.removeMember(userId); // ← updates provider
    _applyFilter(provider.members);                      // ← sync filter list
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove member')),
      );
    }
  }

  Future<void> _makeAdmin(int userId, String username) async {
    final provider = context.read<GroupChatProvider>();
    final success = await provider.makeAdmin(userId);   // ← updates provider
    _applyFilter(provider.members);
    if (mounted) {
      showToast(
        message: success
            ? '$username is now admin'
            : 'Failed to make $username admin',
      );
    }
  }

  void _showOptions(int userId, String username) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.background,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4.h,
                width: 40.w,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
            SizedBox(height: 10.h),
            Text(username,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 5.h),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _makeAdmin(userId, username);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Row(children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 20.spMax, color: AppColors.primaryColor),
                  SizedBox(width: 12.w),
                  Text('Make Admin',
                      style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            Divider(color: Colors.grey.withOpacity(0.2)),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _removeMember(userId);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Row(children: [
                  Icon(Icons.person_remove_outlined,
                      size: 20.spMax, color: const Color(0XFFF44336)),
                  SizedBox(width: 12.w),
                  Text('Remove from Group',
                      style: TextStyle(
                          color: const Color(0XFFF44336),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ← Watch provider so list rebuilds when a member is removed/made admin
    final providerMembers = context.watch<GroupChatProvider>().members;
    final isCurrentUserAdmin = _isCurrentUserAdmin(providerMembers);

    // Keep _filtered in sync with live provider data
    final q = _searchController.text.trim().toLowerCase();
    final displayList = q.isEmpty
        ? providerMembers
        : providerMembers.where((m) {
            final name = (_user(m)['username'] ?? '').toString().toLowerCase();
            return name.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios)),
        title: Text('Members',
            style: CustomTextStyles.appBarTitleText(context)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        toolbarHeight: 25.h,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: const Icon(Icons.add, size: 28),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          children: [
            // Search bar
            Container(
              margin: EdgeInsets.only(top: 10.h),
              height: 34.h,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(15.r),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 3)
                  ]),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  contentPadding:
                      EdgeInsets.only(right: 12.w, left: 12.w, top: 10.h),
                  hintText: 'Search',
                  hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                  border: InputBorder.none,
                  suffixIcon: Icon(FeatherIcons.search,
                      size: 17.spMax,
                      color: Theme.of(context).colorScheme.onBackground),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(15.r)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: AppColors.primaryColor, width: 0.7),
                      borderRadius: BorderRadius.circular(15.r)),
                ),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: displayList.isEmpty
                  ? Center(
                      child: Text('No members found',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground
                                  .withOpacity(0.4),
                              fontSize: 11.sp)))
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, i) {
                        final member = displayList[i];
                        final user = _user(member);
                        final bool isAdmin = member['is_admin'] == true;
                        final String username = user['username'] ?? '';
                        final String? profileImage = user['profile_image'];
                        final int? memberId = user['id'];
                        final int? currentUserId =
                            context.read<UserProvider>().userId;
                        final bool isSelf = memberId == currentUserId;

                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: GestureDetector(
                            onTap: isCurrentUserAdmin && !isSelf && !isAdmin
                                ? () => _showOptions(memberId!, username)
                                : null,
                            child: CustomCard(
                              widget: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: profileImage != null
                                        ? MemoryImage(base64Decode(
                                            profileImage.split(',').last))
                                        : null,
                                    backgroundColor:
                                        const Color.fromARGB(255, 249, 187, 187)
                                            .withOpacity(0.3),
                                    child: profileImage == null
                                        ? Text(
                                            username.isNotEmpty
                                                ? username[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontSize: 14.5.sp,
                                                fontWeight: FontWeight.w500))
                                        : null,
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(username,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground,
                                          fontSize: 11.2.sp,
                                          fontWeight: FontWeight.w400)),
                                  const Spacer(),
                                  if (isAdmin)
                                    Text('Admin',
                                        style: TextStyle(
                                            color: AppColors.primaryColor,
                                            fontSize: 10.2.sp,
                                            fontWeight: FontWeight.w500))
                                  else if (isCurrentUserAdmin && !isSelf)
                                    GestureDetector(
                                      onTap: () =>
                                          _showOptions(memberId!, username),
                                      child: Icon(Icons.more_vert,
                                          size: 18.spMax,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.4)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}