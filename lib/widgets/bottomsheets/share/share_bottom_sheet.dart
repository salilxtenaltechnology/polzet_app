// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/constants/app_radius.dart';
import '../../../widgets/show_toast.dart';
import '../../../api/services/api_service.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../loader.dart';

class ShareBottomSheet extends StatefulWidget {
  final String shareLink;
  final String username;

  const ShareBottomSheet({
    super.key,
    required this.shareLink,
    required this.username,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  final ApiService _apiServices = ApiService();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  Future<void> _fetchUsers() async {
    try {
      final results = await Future.wait([
        _apiServices.getFollowersList(),
        _apiServices.getFollowingList(),
      ]);

      final seen = <int>{};
      final merged = <Map<String, dynamic>>[];

      for (final user in [...results[0], ...results[1]]) {
        final id = user['id'];
        if (id is int && seen.add(id)) merged.add(user);
      }

      if (mounted) {
        setState(() {
          _allUsers = merged;
          _filteredUsers = merged;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = query.isEmpty
          ? _allUsers
          : _allUsers
                .where((u) => _userName(u).toLowerCase().contains(query))
                .toList();
    });
  }

  String _userName(Map<String, dynamic> user) =>
      (user['name'] ?? user['username'] ?? user['full_name'] ?? 'Unknown')
          .toString();

  String? _userAvatar(Map<String, dynamic> user) =>
      (user['avatar'] ?? user['profile_picture_url'] ?? user['image'])
          ?.toString();

  Future<void> _shareToWhatsApp() async {
    final text = Uri.encodeComponent(
      'Check out this post from @${widget.username}: ${widget.shareLink}',
    );

    // Try deep link first (opens WhatsApp directly)
    final whatsappUri = Uri.parse('whatsapp://send?text=$text');
    // Fallback universal link
    final fallbackUri = Uri.parse('https://wa.me/?text=$text');

    try {
      bool launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );

      if (!launched) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Deep link failed, try universal link
      try {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        showToast(message: 'Could not open WhatsApp');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareToInstagram() async {
    final url = Uri.parse('instagram://');
    final fallbackUrl = Uri.parse('https://www.instagram.com/');

    try {
      await Clipboard.setData(ClipboardData(text: widget.shareLink));

      bool launched = false;
      try {
        launched = await launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {
        // Ignored, will try fallback below
      }

      if (!launched) {
        try {
          launched = await launchUrl(
            fallbackUrl,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          launched = false;
        }
      }

      if (!launched) {
        showToast(message: 'Instagram is not installed');
      } else {
        showToast(message: 'Link copied! Paste it in Instagram.');
      }
    } catch (_) {
      showToast(message: 'Instagram is not installed');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareToGmail() async {
    final url = Uri.parse(
      'mailto:?subject=Post from @${widget.username}&body=${Uri.encodeComponent(widget.shareLink)}',
    );
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        showToast(message: 'Could not open email app');
      }
    } catch (_) {
      showToast(message: 'Could not open email app');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.shareLink));
    showToast(message: 'Link copied to clipboard');
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.8.sh,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppTextStyles.bodyText.copyWith(
                    color: const Color(0XFF898989),
                    fontSize: 14.5,
                  ),
                  prefixIcon: const Icon(
                    FeatherIcons.search,
                    size: 18,
                    color: Color(0XFF898989),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 10, bottom: 10),
                ),
                style: AppTextStyles.bodyText.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Users Grid
          Expanded(
            child: _isLoadingUsers
                ? Center(
                    child: Loader(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: AppTextStyles.bodyText.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 15,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final avatarUrl = _userAvatar(user);
                      final name = _userName(user);

                      return GestureDetector(
                        onTap: () {
                          // Handle sharing directly to a specific user via app chat if implemented
                        },
                        child: Column(
                          children: [
                            Builder(
                              builder: (_) {
                                final imageBytes = avatarUrl != null
                                    ? getProfileImage(avatarUrl)
                                    : null;
                                final initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?';

                                return Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: imageBytes == null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                        : null,
                                    image: imageBytes != null
                                        ? DecorationImage(
                                            image: MemoryImage(imageBytes),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.05),
                                    ),
                                  ),
                                  child: imageBytes == null
                                      ? Center(
                                          child: Text(
                                            initial,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 24,
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF2C2C2C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Divider
          Divider(color: Colors.grey.shade200, height: 1),

          // Share Options
          Padding(
            padding: EdgeInsets.only(
              top: 5.h,
              bottom: 15.h,
              left: 20,
              right: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShareOption(
                  iconWidget: const Icon(
                    FontAwesome.whatsapp_brand,
                    color: Color(0xFF25D366),
                    size: 32,
                  ),
                  label: 'Whatsapp',
                  onTap: _shareToWhatsApp,
                ),
                _buildShareOption(
                  iconWidget: const Icon(
                    FontAwesome.instagram_brand,
                    color: Color(0xFFE1306C),
                    size: 32,
                  ),
                  label: 'Instagram',
                  onTap: _shareToInstagram,
                ),
                _buildShareOption(
                  iconWidget: Image.asset(
                    'assets/images/ic_google.png',
                    height: 30,
                    width: 30,
                  ),
                  label: 'Gmail',
                  onTap: _shareToGmail,
                ),
                _buildShareOption(
                  iconWidget: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x1A9B3046),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      FeatherIcons.link,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  label: 'Copy link',
                  onTap: _copyLink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: iconWidget),
          ),
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF2C2C2C),
            ),
          ),
        ],
      ),
    );
  }
}
