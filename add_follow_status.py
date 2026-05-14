import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# 1. Add Enum
if "enum FollowStatus" not in content:
    content = content.replace("class NewPublicProfileScreen extends StatefulWidget {", "enum FollowStatus { none, rechase, chase, both, pending }\n\nclass NewPublicProfileScreen extends StatefulWidget {")

# 2. Add state variables & methods to _NewPublicProfileScreenState
state_vars_methods = """
  FollowStatus? _localFollowStatus;
  bool _isProcessingRequest = false;

  FollowStatus _getEffectiveFollowStatus(String? profileFollowStatus) {
    if (_localFollowStatus != null) {
      return _localFollowStatus!;
    }
    return _parseFollowStatus(profileFollowStatus);
  }

  FollowStatus _parseFollowStatus(String? status) {
    if (status == null || status.isEmpty) return FollowStatus.none;
    switch (status.toLowerCase()) {
      case 'rechase':
        return FollowStatus.rechase;
      case 'chase':
        return FollowStatus.chase;
      case 'both':
        return FollowStatus.both;
      case 'pending':
        return FollowStatus.pending;
      default:
        return FollowStatus.none;
    }
  }

  Map<String, dynamic> _getButtonState(FollowStatus status) {
    switch (status) {
      case FollowStatus.none:
        return {
          'icon': FeatherIcons.userPlus,
          'text': 'Chase',
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.chase:
        return {
          'icon': Icons.sync,
          'text': 'Chase Back',
          'canTap': !_isProcessingRequest,
          'isFollowing': false,
        };
      case FollowStatus.rechase:
      case FollowStatus.both:
        return {
          'icon': Icons.verified,
          'text': 'Chased',
          'canTap': !_isProcessingRequest,
          'isFollowing': true,
        };
      case FollowStatus.pending:
        return {
          'icon': Icons.schedule,
          'text': 'Chasing',
          'canTap': false,
          'isFollowing': false,
        };
    }
  }

"""

if "_localFollowStatus" not in content:
    content = content.replace("  late TabController _tabController;", state_vars_methods + "  late TabController _tabController;")


# 3. Update _buildHeader & the button
build_header_start = """  Widget _buildHeader(double topPadding, PublicProfileProvider userProvider) {
    final profile = userProvider.userProfile;"""
build_header_new = """  Widget _buildHeader(double topPadding, PublicProfileProvider userProvider) {
    final profile = userProvider.userProfile;
    final effectiveStatus = _getEffectiveFollowStatus(profile?.followStatus);
    final buttonState = _getButtonState(effectiveStatus);"""

content = content.replace(build_header_start, build_header_new)

# 4. Replace the button UI
old_button = """                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.verified_user,
                        // Icons.edit_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Chase',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),"""

new_button = """                    child: ElevatedButton.icon(
                      onPressed: buttonState['canTap'] ? () {} : null,
                      icon: Icon(
                        buttonState['icon'],
                        size: 16,
                        color: buttonState['isFollowing'] ? Theme.of(context).colorScheme.primary : Colors.white,
                      ),
                      label: Text(
                        buttonState['text'],
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14.5,
                          color: buttonState['isFollowing'] ? Theme.of(context).colorScheme.primary : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonState['isFollowing'] ? Colors.white : Theme.of(context).colorScheme.primary.withOpacity(buttonState['canTap'] ? 1.0 : 0.5),
                        elevation: 0,
                        side: buttonState['isFollowing'] ? BorderSide(color: Theme.of(context).colorScheme.primary) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                    ),"""

content = content.replace(old_button, new_button)

with open(file_path, "w") as f:
    f.write(content)

