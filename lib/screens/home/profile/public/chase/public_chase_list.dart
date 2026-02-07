// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile.dart';

import '../../../../../api/services/api_service.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../mixin/utility_mixins.dart';
import '../../../../../widgets/base64/image_convert.dart';
import '../../../../../widgets/button/back_button.dart';
import '../../../../../widgets/custom_text_styles.dart';
import '../../../../../widgets/tabbar/indicatore_animation.dart';

class PublicChaseList extends StatefulWidget {
  final int userId;
  final String? username;

  const PublicChaseList({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<PublicChaseList> createState() => _PublicChaseListState();
}

class _PublicChaseListState extends State<PublicChaseList>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _chaseList = [];
  List<Map<String, dynamic>> _rechaseList = [];
  List<Map<String, dynamic>> _filteredChaseList = [];
  List<Map<String, dynamic>> _filteredRechaseList = [];

  bool _isLoadingChase = false;
  bool _isLoadingRechase = false;
  int _chaseCount = 0;
  int _rechaseCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadChaseList(), _loadRechaseList()]);
  }

  Future<void> _loadChaseList() async {
    setState(() => _isLoadingChase = true);

    try {
      final response = await apiService.getConnectionsList(
        userId: widget.userId,
        type: 'chase',
      );

      setState(() {
        _chaseCount = response['count'] ?? 0;
        _chaseList = List<Map<String, dynamic>>.from(response['results'] ?? []);
        _filteredChaseList = _chaseList;
      });
    } catch (e) {
      debugPrint('Error loading chase list: $e');
    } finally {
      setState(() => _isLoadingChase = false);
    }
  }

  Future<void> _loadRechaseList() async {
    setState(() => _isLoadingRechase = true);

    try {
      final response = await apiService.getConnectionsList(
        userId: widget.userId,
        type: 'rechase',
      );

      setState(() {
        _rechaseCount = response['count'] ?? 0;
        _rechaseList = List<Map<String, dynamic>>.from(
          response['results'] ?? [],
        );
        _filteredRechaseList = _rechaseList;
      });
    } catch (e) {
      debugPrint('Error loading rechase list: $e');
    } finally {
      setState(() => _isLoadingRechase = false);
    }
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChaseList = _chaseList;
        _filteredRechaseList = _rechaseList;
      } else {
        _filteredChaseList = _chaseList.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        _filteredRechaseList = _rechaseList.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PrimaryBackButton(),
        title: Text(
          widget.username ?? '',
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TabBar(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            controller: _tabController,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: FadeUnderlineTabIndicator(),
            labelColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
            tabs: [
              Tab(text: '$_chaseCount Chase'),
              Tab(text: '$_rechaseCount Re-chase'),
            ],
          ),
          Container(
            height: 36.h,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 15.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C000000),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(
                  right: 12.w,
                  left: 12.w,
                  top: 10.h,
                ),
                hintText: AppLocalizations.of(context)!.searchusers,
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
                suffixIcon: Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.1),
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: AppColors.primaryColor,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(13.r),
                ),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
              onChanged: _filterList,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_filteredChaseList, _isLoadingChase),
                _buildUserList(_filteredRechaseList, _isLoadingRechase),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
            fontSize: 14.sp,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userName = user['name'] ?? 'Unknown User';
    final avatarUrl = user['avatar_url'];

    return GestureDetector(
      onTap: () {
        navigationPush(context, PublicProfile(userId: user['user_id']));
      },
      child: Container(
        height: 38.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: const [
            BoxShadow(color: Color(0x1C000000), blurRadius: 5, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(userName, avatarUrl),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                userName,
                style: CustomTextStyles.lblSecondryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String userName, String? avatarUrl) {
    final imageBytes = getConvertImage(avatarUrl);
    return Container(
      height: 32.h,
      width: 32.w,
      margin: EdgeInsets.only(right: 5.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD1D1D1).withOpacity(0.7)),
        image: avatarUrl != null && avatarUrl.isNotEmpty
            ? DecorationImage(
                image: MemoryImage(imageBytes!),
                fit: BoxFit.cover,
              )
            : null,
        color: avatarUrl == null
            ? Theme.of(context).primaryColor.withOpacity(0.08)
            : null,
      ),

      child: avatarUrl == null || avatarUrl.isEmpty
          ? _buildInitialsAvatar(userName)
          : null,
    );
  }

  Widget _buildInitialsAvatar(String userName) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
