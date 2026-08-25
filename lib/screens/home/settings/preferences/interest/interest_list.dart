// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../api/api_service.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../gen/assets.gen.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../widgets/loader.dart';
import '../../../../../widgets/show_toast.dart';

class InterestList extends StatefulWidget {
  const InterestList({super.key});

  @override
  State<InterestList> createState() => _InterestListState();
}

class _InterestListState extends State<InterestList> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedInterests = {};
  final Set<String> _initialInterests = {};
  List<({String id, String name, String icon})> _filteredInterests = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _hasChanged {
    if (_selectedInterests.length != _initialInterests.length) return true;
    for (final item in _selectedInterests) {
      if (!_initialInterests.contains(item)) return true;
    }
    return false;
  }

  static final Map<String, String> _staticIcons = {
    'Movies': Assets.images.icMovie.path,
    'Sports': Assets.images.icSports.path,
    'Technology': Assets.images.icTechnology.path,
    'AI & Tech': Assets.images.icTech.path,
    'Gaming': Assets.images.icGame.path,
    'Travel': Assets.images.icTravel.path,
    'Music': Assets.images.icMusic.path,
    'Memes': Assets.images.icMeme.path,
    'Fitness': Assets.images.icFiteness.path,
    'Fashion': Assets.images.icFashion.path,
    'Food': Assets.images.icFood.path,
    'Education': Assets.images.icBook.path,
    'Finance': Assets.images.icFinance.path,
    'Relationships': Assets.images.icRelationships.path,
    'Current Affairs': Assets.images.icCurrentAffairs.path,
  };

  List<({String id, String name, String icon})> _interests = [];

  @override
  void initState() {
    super.initState();
    _filterInterests('');
    _fetchInterestList();
  }

  Future<void> _fetchInterestList() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final rawUserInterests = userProvider.interests;
      final Set<String> userInterestSet = {};
      if (rawUserInterests != null) {
        for (final e in rawUserInterests) {
          if (e is Map) {
            if (e['id'] != null) userInterestSet.add(e['id'].toString());
            if (e['name'] != null) userInterestSet.add(e['name'].toString());
          } else if (e != null) {
            userInterestSet.add(e.toString());
          }
        }
      }

      final response = await ApiService().getInterestList();
      if (response['status'] == 'success' && response['data'] != null) {
        final List dataList = response['data'] as List;
        final List<({String id, String name, String icon})> loadedList = [];
        final Set<String> matchedSelectedInterests = {};

        for (final item in dataList) {
          if (item is Map) {
            final String id = item['id']?.toString() ?? '';
            final String name = item['name']?.toString() ?? '';
            final String staticIcon =
                _staticIcons[name] ?? Assets.images.icMovie.path;
            loadedList.add((id: id, name: name, icon: staticIcon));

            if (userInterestSet.contains(id) ||
                userInterestSet.contains(name)) {
              matchedSelectedInterests.add(name);
            }
          }
        }

        if (mounted) {
          setState(() {
            _interests = loadedList;
            _selectedInterests.addAll(matchedSelectedInterests);
            _initialInterests.clear();
            _initialInterests.addAll(matchedSelectedInterests);
            _filterInterests(_searchController.text);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching interest list: $e');
      final errorMsg = e.toString().startsWith('Exception: ')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to load interests';
      showToast(message: errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterInterests(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredInterests = List.from(_interests);
      } else {
        final q = query.toLowerCase().trim();
        _filteredInterests = _interests.where((interest) {
          return interest.name.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFDCDCDC),
            width: 0.8,
          ),
        ),
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          cursorColor: Theme.of(context).colorScheme.onPrimary,
          cursorWidth: 1.5,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _filterInterests,
          decoration: InputDecoration(
            hintText: 'Search interest',
            hintStyle: AppTextStyles.bodyText.copyWith(
              color: const Color(0XFF898989),
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 22,
              color: Color(0XFF898989),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 46,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0XFF898989),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterInterests('');
                    },
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 46,
            ),
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(right: 12),
          ),
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
      appBar: const CommonAppBar(title: 'Interests', showBackButton: true),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading && _interests.isEmpty
                ? Center(
                    child: Loader(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : _filteredInterests.isEmpty
                ? Center(
                    child: Text(
                      'No interests found',
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.muted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredInterests.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final item = _filteredInterests[index];
                        final isSelected = _selectedInterests.contains(
                          item.name,
                        );

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              setState(() {
                                _selectedInterests.remove(item.name);
                              });
                            } else {
                              setState(() {
                                _selectedInterests.add(item.name);
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? (isSelected
                                        ? const Color.fromARGB(46, 51, 32, 36)
                                        : Theme.of(context).colorScheme.outline
                                              .withOpacity(0.1))
                                  : (isSelected
                                        ? const Color(
                                            0xFFFAF7F8,
                                          ).withOpacity(0.8)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ── Tinted Circle for Icon
                                Container(
                                  width: 57,
                                  height: 57,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : (isDarkMode
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.05)
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1)),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      item.icon,
                                      width: 28,
                                      height: 28,
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    item.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.3,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: txt.title,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 35),
        child: _buildSaveButton(),
      ),
    );
  }

  Future<void> _saveInterests() async {
    if (_isSaving || !_hasChanged) return;

    setState(() {
      _isSaving = true;
    });

    final List<dynamic> selectedIds = _interests
        .where((item) => _selectedInterests.contains(item.name))
        .map((item) => int.tryParse(item.id) ?? item.id)
        .toList();

    try {
      final success = await ApiService().updateUserInterests(
        interests: selectedIds,
      );
      if (success && mounted) {
        _initialInterests.clear();
        _initialInterests.addAll(_selectedInterests);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateUserField('interests', selectedIds);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error updating interests: $e');
      final errorMsg = e.toString().startsWith('Exception: ')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to save interests';
      showToast(message: errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildSaveButton() {
    final isEnabled = !_isSaving && _hasChanged;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _saveInterests : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: const Color(0x269B3046),
          disabledForegroundColor: const Color(0xFF898989),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save Changes',
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
