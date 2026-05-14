import re

file_path = "lib/screens/home/profile/public/new_public_profile_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# 1. Update _parseFollowStatus and _getButtonState
old_methods = """  FollowStatus _parseFollowStatus(String? status) {
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
  }"""

new_methods = """  FollowStatus _parseFollowStatus(String? status) {
    if (status == null || status.isEmpty) return FollowStatus.none;
    switch (status.toLowerCase()) {
      case 'following':
      case 'rechase':
        return FollowStatus.rechase;
      case 'follower':
      case 'followers':
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
          'text': 'Chasing',
          'canTap': !_isProcessingRequest,
          'isFollowing': true,
        };
      case FollowStatus.pending:
        return {
          'icon': Icons.schedule,
          'text': 'Requested',
          'canTap': false,
          'isFollowing': false,
        };
    }
  }

  Future<void> _handleFollowAction(
    String username,
    bool isFollowing,
    bool isPrivate,
  ) async {
    if (_isProcessingRequest) return;

    setState(() {
      _isProcessingRequest = true;
    });

    try {
      if (isFollowing) {
        setState(() {
          _localFollowStatus = FollowStatus.none;
          _isProcessingRequest = false;
        });

        final response = await apiService.unfriend(widget.userId);

        if (response['status'] == 'success') {
          // Success
        } else {
          setState(() {
            _localFollowStatus = FollowStatus.rechase;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to unfollow. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        setState(() {
          _localFollowStatus = isPrivate
              ? FollowStatus.pending
              : FollowStatus.rechase;
          _isProcessingRequest = false;
        });

        final bool requestResult = await apiService.sendFriendRequest(username);

        if (requestResult) {
          // Success
        } else {
          setState(() {
            _localFollowStatus = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send request. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _localFollowStatus = null;
        _isProcessingRequest = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }"""

content = content.replace(old_methods, new_methods)

# 2. Update the button onPressed
old_button_click = """                      onPressed: buttonState['canTap'] ? () {} : null,"""
new_button_click = """                      onPressed: buttonState['canTap'] ? () {
                        _handleFollowAction(
                          profile!.username,
                          buttonState['isFollowing'],
                          profile.isPrivate,
                        );
                      } : null,"""

content = content.replace(old_button_click, new_button_click)

with open(file_path, "w") as f:
    f.write(content)

