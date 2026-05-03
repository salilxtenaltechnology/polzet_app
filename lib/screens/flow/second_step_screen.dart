import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/services/api_service.dart';
import '../../../models/user/suggestionsb users/suggestions_users_model.dart';
import '../../../widgets/loader.dart';
import '../../../widgets/error/api_error_widget.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import 'flow_scaffold.dart';

// Dummy popular users — replace with real API call when available
const _dummyPopularUsers = [
  (username: 'john_doe', name: 'John Doe'),
  (username: 'alex_lee', name: 'Alex Lee'),
  (username: 'maria_g', name: 'Maria Garcia'),

];

class SecondStepScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const SecondStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<SecondStepScreen> createState() => _SecondStepScreenState();
}

class _SecondStepScreenState extends State<SecondStepScreen> {
  final ApiService _apiService = ApiService();

  final Set<int> _chasedUserIds = {};
  final Set<String> _chasedPopularUsernames = {};
  int _selectedTab = 0;
  late Future<UserSuggestionsModel> _suggestionsFuture;

  // ── Validation: at least one chase in either tab
  bool get _canContinue =>
      _chasedUserIds.isNotEmpty || _chasedPopularUsernames.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = _apiService.fetchUserSuggestions();
  }

  Future<void> _onChaseToggle({
    required int userId,
    required String username,
    required bool isChased,
    required StateSetter setLocalState,
  }) async {
    if (isChased) {
      setLocalState(() => _chasedUserIds.remove(userId));
      setState(() {}); // ← sync outer button state
      try {
        await _apiService.unfriend(userId);
      } catch (_) {
        setLocalState(() => _chasedUserIds.add(userId));
        setState(() {});
      }
    } else {
      setLocalState(() => _chasedUserIds.add(userId));
      setState(() {}); // ← sync outer button state
      try {
        await _apiService.sendFriendRequest(username);
      } catch (_) {
        setLocalState(() => _chasedUserIds.remove(userId));
        setState(() {});
      }
    }
  }

  ImageProvider _buildAvatar(String avatar) {
    if (avatar.startsWith('data:image')) {
      final base64Str = avatar.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    }
    return NetworkImage(avatar);
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      currentStep: 2,
      totalSteps: 3,
      onBack: widget.onBack,
      title: 'Follow people you like',
      subtitle: 'Choose a few to personalize your feed',
      primaryLabel: 'Continue',
      onPrimary: _canContinue ? widget.onContinue : null, // ← disabled until one chased
      onSkip: widget.onSkip,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TabItem(
                label: 'Suggested',
                isSelected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              const SizedBox(width: 24),
              _TabItem(
                label: 'Popular',
                isSelected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedTab == 0) _buildSuggestedList() else _buildPopularList(),
        ],
      ),
    );
  }

  Widget _buildSuggestedList() {
    return FutureBuilder<UserSuggestionsModel>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Loader(color: Theme.of(context).colorScheme.primary));
        }
        if (snapshot.hasError) {
          return ApiErrorWidget(
            onRetry: () => setState(
              () => _suggestionsFuture = _apiService.fetchUserSuggestions(),
            ),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final users = snapshot.data?.data.peopleYouMayKnow ?? [];
        if (users.isEmpty) return const SizedBox.shrink();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];
            return StatefulBuilder(
              builder: (context, setLocalState) {
                final isChased = _chasedUserIds.contains(user.id);
                return _UserTile(
                  avatarProvider: _buildAvatar(user.avatar),
                  username: user.username,
                  subLabel: user.name,
                  isChased: isChased,
                  onChaseTap: () => _onChaseToggle(
                    userId: user.id,
                    username: user.username,
                    isChased: isChased,
                    setLocalState: setLocalState,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPopularList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _dummyPopularUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _dummyPopularUsers[index];
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final isChased = _chasedPopularUsernames.contains(user.username);
            return _UserTile(
              avatarProvider: null,
              username: user.username,
              subLabel: user.name,
              isChased: isChased,
              onChaseTap: () {
                setLocalState(() {
                  if (isChased) {
                    _chasedPopularUsernames.remove(user.username);
                  } else {
                    _chasedPopularUsernames.add(user.username);
                  }
                });
                setState(() {}); // ← sync outer button state
              },
            );
          },
        );
      },
    );
  }
}

// ── Shared user tile ─────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final ImageProvider? avatarProvider;
  final String username;
  final String subLabel;
  final bool isChased;
  final VoidCallback onChaseTap;

  const _UserTile({
    required this.avatarProvider,
    required this.username,
    required this.subLabel,
    required this.isChased,
    required this.onChaseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundImage: avatarProvider,
            backgroundColor: Colors.grey.shade200,
            child: avatarProvider == null
                ? const Icon(Icons.person, size: 24, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),

          // Name + sub
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppTextStyles.bodyText.copyWith(
                    color: const Color(0xFF595959),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: AppTextStyles.subText.copyWith(
                    color: const Color(0xFF8E8E8E),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Chase button
          GestureDetector(
            onTap: onChaseTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: isChased
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    Assets.images.icAddUser.path,
                    height: 17,
                    width: 17,
                    color: isChased
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isChased ? 'Chasing' : 'Chase',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isChased
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab item ─────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14.5,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF8E8E8E),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? label.length * 8.5 : 0,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}