// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../../api/api_service.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../models/country/country_model.dart';
import '../../../../../provider/user_provider.dart';
import '../../../../../widgets/appbar/common_appbar.dart';

class CountryList extends StatefulWidget {
  const CountryList({super.key});

  @override
  State<CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<CountryList> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = [];
  String _selectedCountryCode = 'IN';
  String _initialCountryCode = 'IN';
  bool _isLoading = false;

  bool get _hasChanged =>
      _selectedCountryCode.trim().toUpperCase() !=
      _initialCountryCode.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _filterCountries('');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _syncSelectedCountry(userProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncSelectedCountry(UserProvider userProvider) {
    final userCountry = userProvider.country ?? userProvider.user?.country;

    if (userCountry != null && userCountry.isNotEmpty) {
      final cleanCountry = userCountry.trim().toLowerCase();
      try {
        final match = allCountries.firstWhere(
          (c) =>
              c.code.toLowerCase() == cleanCountry ||
              c.name.toLowerCase() == cleanCountry,
        );
        setState(() {
          _selectedCountryCode = match.code;
          _initialCountryCode = match.code;
          _filterCountries(_searchController.text);
        });
      } catch (_) {}
    }
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredCountries = List.from(allCountries);
      } else {
        final q = query.toLowerCase().trim();
        _filteredCountries = allCountries.where((country) {
          return country.name.toLowerCase().contains(q) ||
              country.code.toLowerCase().contains(q);
        }).toList();
      }
      _filteredCountries.sort((a, b) => a.name.compareTo(b.name));

      final savedIndex = _filteredCountries.indexWhere(
        (c) => c.code.toLowerCase() == _initialCountryCode.toLowerCase(),
      );
      if (savedIndex > 0) {
        final savedCountry = _filteredCountries.removeAt(savedIndex);
        _filteredCountries.insert(0, savedCountry);
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
          onChanged: _filterCountries,
          decoration: InputDecoration(
            hintText: 'Search country',
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
                      _filterCountries('');
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Country', showBackButton: true),
      body: Column(
        children: [
          _buildSearchBar(),

          // Country List (Alphabetically Sorted)
          Expanded(
            child: _filteredCountries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.muted,
                        fontSize: 14.sp,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected =
                          _selectedCountryCode.toLowerCase() ==
                          country.code.toLowerCase();

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCountryCode = country.code;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              Text(
                                country.flag,
                                style: TextStyle(fontSize: 19.sp),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: txt.title,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : txt.muted,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.circle
                                      : Icons.circle_outlined,
                                  size: 16.spMax,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Colors.transparent,
                                ),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 35),
        child: _buildSaveButton(),
      ),
    );
  }

  Widget _buildSaveButton() {
    final isEnabled = !_isLoading && _hasChanged;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _saveCountry : null,
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
        child: _isLoading
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

  Future<void> _saveCountry() async {
    if (!_hasChanged || _isLoading) return;

    final selectedCountry = allCountries.firstWhere(
      (c) => c.code.toUpperCase() == _selectedCountryCode.toUpperCase(),
      orElse: () => allCountries.first,
    );

    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final apiService = ApiService();

    final countryCodeToSave = selectedCountry.code.toUpperCase();

    final success = await apiService.updateCountry(
      country: countryCodeToSave,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        _initialCountryCode = countryCodeToSave;
        userProvider.updateUserField('country', countryCodeToSave);
        Navigator.pop(context);
      }
    }
  }
}
