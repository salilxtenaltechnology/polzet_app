// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../data/token/shared_preferences.dart';
import '../../gen/assets.gen.dart';
import '../../main.dart';
import '../../provider/user_provider.dart';
import '../../widgets/loader.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/country/country_model.dart';
import '../../widgets/show_toast.dart';
import 'flow_scaffold.dart';

class SecondStepScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final bool showCountryLanguage;

  const SecondStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    this.showCountryLanguage = true,
  });

  @override
  State<SecondStepScreen> createState() => _SecondStepScreenState();
}

class _SecondStepScreenState extends State<SecondStepScreen> {
  // ── Sub-step inside SecondStepScreen: 0 = Country & Language, 1 = Attention (Interests)
  int _subStep = 0;

  // ── Step 0 state: Country & Language
  String _selectedCountry = 'India';
  String _selectedLanguage = 'English';

  final _countryLayerLink = LayerLink();
  OverlayEntry? _countryOverlayEntry;
  bool _isCountryDropdownOpen = false;
  double _countryFieldWidth = 0;
  final _countrySearchController = TextEditingController();

  static const Map<String, String> _languageCodeMap = {
    'Arabic': 'ar',
    'English': 'en',
    'German': 'de',
    'Hindi': 'hi',
    'Indonasian': 'id',
    'Indonesian': 'id',
    'Spanish': 'es',
    'Vietnamese': 'vi',
  };

  static const Map<String, String> _codeToLanguageMap = {
    'ar': 'Arabic',
    'en': 'English',
    'de': 'German',
    'hi': 'Hindi',
    'id': 'Indonasian',
    'es': 'Spanish',
    'vi': 'Vietnamese',
  };

  @override
  void initState() {
    super.initState();
    if (!widget.showCountryLanguage) {
      _subStep = 1;
    }
    _loadInitialLanguage();
    _fetchInterestList();
  }

  Future<void> _loadInitialLanguage() async {
    final savedCode = await SharedPrefService.getLanguage();
    if (savedCode != null && _codeToLanguageMap.containsKey(savedCode)) {
      if (mounted) {
        setState(() {
          _selectedLanguage = _codeToLanguageMap[savedCode]!;
        });
      }
    }
  }

  void _applyLanguage(String lang) {
    final code = _languageCodeMap[lang] ?? 'en';
    SharedPrefService.saveLanguage(code);
    if (mounted) {
      MyApp.of(context)?.changeLanguage(Locale(code));
    }
  }

  final List<String> _languages = const [
    'Arabic',
    'English',
    'German',
    'Hindi',
    'Indonasian',
    'Spanish',
    'Vietnamese',
  ];

  // ── Step 1 state: Attention / Interests
  final Set<String> _selectedInterests = {};
  bool _isLoadingInterests = true;
  bool _isUpdatingInterests = false;

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

  Future<void> _fetchInterestList() async {
    setState(() {
      _isLoadingInterests = true;
    });
    try {
      final response = await ApiService().getInterestList();
      if (response['status'] == 'success' && response['data'] != null) {
        final List dataList = response['data'] as List;
        final List<({String id, String name, String icon})> loadedList = [];

        for (final item in dataList) {
          if (item is Map) {
            final String id = item['id']?.toString() ?? '';
            final String name = item['name']?.toString() ?? '';
            final String staticIcon =
                _staticIcons[name] ?? Assets.images.icMovie.path;
            loadedList.add((id: id, name: name, icon: staticIcon));
          }
        }

        if (mounted) {
          setState(() {
            _interests = loadedList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching interest list in SecondStepScreen: $e');
      final errorMsg = e.toString().startsWith('Exception: ')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to load interests';
      showToast(message: errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInterests = false;
        });
      }
    }
  }

  Future<void> _updateUserInterests() async {
    if (!_canContinueStep1 || _isUpdatingInterests) return;

    setState(() {
      _isUpdatingInterests = true;
    });

    final selectedIds = _interests
        .where((item) => _selectedInterests.contains(item.name))
        .map((item) => int.tryParse(item.id) ?? item.id)
        .toList();

    try {
      final success =
          await ApiService().updateUserInterests(interests: selectedIds);
      if (success) {
        if (mounted) {
          try {
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            userProvider.updateUserField('interests', selectedIds);
          } catch (_) {}
        }
        widget.onContinue();
      }
    } catch (e) {
      debugPrint('Error updating interests in SecondStepScreen: $e');
      final errorMsg = e.toString().startsWith('Exception: ')
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Failed to update interests';
      showToast(message: errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingInterests = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _closeCountryDropdown();
    _countrySearchController.dispose();
    super.dispose();
  }

  // ── Country Dropdown Overlay Logic ──────────────────────────────────────────
  void _toggleCountryDropdown() {
    if (_isCountryDropdownOpen) {
      _closeCountryDropdown();
    } else {
      _openCountryDropdown();
    }
  }

  void _openCountryDropdown() {
    if (_countryOverlayEntry != null) return;

    _countrySearchController.clear();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    _countryOverlayEntry = OverlayEntry(
      builder: (context) {
        List<Country> currentFiltered = List.from(allCountries);

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Stack(
              children: [
                // Dismiss on outside tap
                GestureDetector(
                  onTap: _closeCountryDropdown,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Dropdown overlay menu positioned right below dropdown field
                Positioned(
                  width: _countryFieldWidth > 0
                      ? _countryFieldWidth
                      : (MediaQuery.of(context).size.width - 48.w),
                  child: CompositedTransformFollower(
                    link: _countryLayerLink,
                    showWhenUnlinked: false,
                    offset: Offset(0, 48.h + 6),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? const Color(0xFF1F1F23)
                          : Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1F1F23)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search field inside dropdown menu
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2A2A2E)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _countrySearchController,
                                  autofocus: true,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.5,
                                    color: txt.title,
                                  ),
                                  onChanged: (q) {
                                    setOverlayState(() {
                                      if (q.trim().isEmpty) {
                                        currentFiltered = List.from(allCountries);
                                      } else {
                                        final query = q.toLowerCase().trim();
                                        currentFiltered = allCountries.where((c) {
                                          return c.name
                                                  .toLowerCase()
                                                  .contains(query) ||
                                              c.code
                                                  .toLowerCase()
                                                  .contains(query);
                                        }).toList();
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search country...',
                                    hintStyle: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.5,
                                      color: const Color(0xFF898989),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: Color(0xFF898989),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 40,
                                    ),
                                    suffixIcon: _countrySearchController.text.isNotEmpty
                                        ? IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 40,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Color(0xFF898989),
                                            ),
                                            onPressed: () {
                                              _countrySearchController.clear();
                                              setOverlayState(() {
                                                currentFiltered = List.from(allCountries);
                                              });
                                            },
                                          )
                                        : null,
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 40,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(right: 10),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5),
                            // Filtered country list
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: currentFiltered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Text(
                                        'No country found',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 13,
                                          color: txt.muted,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: currentFiltered.length,
                                      itemBuilder: (context, index) {
                                        final country = currentFiltered[index];
                                        final isSelected =
                                            country.name.toLowerCase() ==
                                                _selectedCountry.toLowerCase();

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedCountry = country.name;
                                            });
                                            _closeCountryDropdown();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            color: isSelected
                                                ? (isDarkMode
                                                    ? const Color(0xFF2A2A2E)
                                                    : const Color(0xFFF0F0F0))
                                                : Colors.transparent,
                                            child: Row(
                                              children: [
                                                Text(
                                                  country.flag,
                                                  style: const TextStyle(fontSize: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    country.name,
                                                    style: AppTextStyles.bodyText.copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      color: txt.title,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_countryOverlayEntry!);
    setState(() {
      _isCountryDropdownOpen = true;
    });
  }

  void _closeCountryDropdown() {
    _countryOverlayEntry?.remove();
    _countryOverlayEntry = null;
    if (mounted) {
      setState(() {
        _isCountryDropdownOpen = false;
      });
    }
  }

  // ── Validations
  bool get _canContinueStep0 =>
      _selectedCountry.isNotEmpty && _selectedLanguage.isNotEmpty;

  bool get _canContinueStep1 =>
      _selectedInterests.length >= 3 && !_isUpdatingInterests;

  @override
  Widget build(BuildContext context) {
    return _subStep == 0 ? _buildStep0(context) : _buildStep1(context);
  }

  // ── Sub-Step 0: Personalize your feed (Country & Language) ──
  Widget _buildStep0(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FlowScaffold(
      currentStep: 2,
      totalSteps: 4,
      onBack: () {
        _closeCountryDropdown();
        widget.onBack();
      },
      title: 'Personalize your feed',
      subtitle: 'Tell us what you like to see on Polzet',
      primaryLabel: 'Continue',
      onPrimary: _canContinueStep0
          ? () {
              _closeCountryDropdown();
              _applyLanguage(_selectedLanguage);
              setState(() => _subStep = 1);
            }
          : null,
      onSkip: null, // Mandatory
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Select Country Label
          Text(
            'Select Country',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: txt.title,
            ),
          ),
          const SizedBox(height: 8),

          // ── Country Dropdown Box
          LayoutBuilder(
            builder: (context, constraints) {
              _countryFieldWidth = constraints.maxWidth;
              final selectedCountryObj = allCountries.firstWhere(
                (c) =>
                    c.name.toLowerCase() == _selectedCountry.toLowerCase() ||
                    c.code.toLowerCase() == _selectedCountry.toLowerCase(),
                orElse: () => allCountries.firstWhere(
                  (c) => c.name == 'India',
                  orElse: () => allCountries.first,
                ),
              );

              return CompositedTransformTarget(
                link: _countryLayerLink,
                child: InkWell(
                  onTap: _toggleCountryDropdown,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Theme.of(context).colorScheme.background
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(selectedCountryObj.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedCountryObj.name,
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: txt.title,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _isCountryDropdownOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: txt.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Language Label
          Text(
            'App Language',
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: txt.title,
            ),
          ),
          const SizedBox(height: 12),

          // ── Language Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _languages.map((lang) {
              final isSelected = _selectedLanguage == lang;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLanguage = lang;
                  });
                  _applyLanguage(lang);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isDarkMode ? Colors.transparent : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    lang,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: isSelected ? Colors.white : txt.title,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Sub-Step 1: What catches your attention? (Interests Grid) ──
  Widget _buildStep1(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FlowScaffold(
      currentStep: 2,
      totalSteps: 4,
      onBack: () {
        if (widget.showCountryLanguage) {
          setState(() => _subStep = 0);
        } else {
          widget.onBack();
        }
      },
      title: 'What catches your attention?',
      subtitle: 'Select at least 3 topics you are interested in.',
      primaryLabel: 'Continue',
      onPrimary: _canContinueStep1 ? _updateUserInterests : null,
      onSkip: null,
      body: _isLoadingInterests && _interests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Loader(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _interests.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final item = _interests[index];
          final isSelected = _selectedInterests.contains(item.name);

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
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.1))
                    : (isSelected
                          ? const Color(0xFFFAF7F8).withOpacity(0.8)
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
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.05)
                                : Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1)),
                    ),
                    child: Center(
                      child: Image.asset(
                        item.icon,
                        width: 28,
                        height: 28,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
    );
  }
}
