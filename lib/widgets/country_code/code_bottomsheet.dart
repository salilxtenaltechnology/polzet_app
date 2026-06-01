// ignore_for_file: deprecated_member_use

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../models/country/country_model.dart';

class CountryPickerBottomSheet extends StatefulWidget {
  final Function(Country) onCountrySelected;
  final Country? selectedCountry;

  const CountryPickerBottomSheet({
    super.key,
    required this.onCountrySelected,
    this.selectedCountry,
  });

  @override
  State<CountryPickerBottomSheet> createState() =>
      _CountryPickerBottomSheetState();
}

class _CountryPickerBottomSheetState extends State<CountryPickerBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> filteredCountries = [];

  @override
  void initState() {
    super.initState();
    filteredCountries = _getAllCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCountries = _getAllCountries();
      } else {
        filteredCountries = _getAllCountries()
            .where(
              (country) =>
                  country.name.toLowerCase().contains(query.toLowerCase()) ||
                  country.dialCode.contains(query) ||
                  country.code.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: AppRadius.modalRadius,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Country',
                style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
              ),
            ),
          ),
          Container(
            height: 43,
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 12, horizontal: 10.w),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: TextField(
              controller: _searchController,
              cursorColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withOpacity(0.8),
              cursorWidth: 1.5,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(
                  right: 12.w,
                  left: 12.w,
                  top: 10.h,
                ),
                hintText: 'Search country',
                hintStyle: AppTextStyles.bodyText.copyWith(
                  color: const Color(0XFF898989),
                  fontWeight: FontWeight.w400,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,

                prefixIcon: Icon(
                  FeatherIcons.search,
                  size: 17.spMax,
                  color: const Color(0XFF898989),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                    width: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              onChanged: _filterCountries,
            ),
          ),

        
          // Countries list
          Expanded(
            child: ListView.builder(
              itemCount: filteredCountries.length,
              itemBuilder: (context, index) {
                final country = filteredCountries[index];
                final isSelected = widget.selectedCountry?.code == country.code;

                return ListTile(
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(
                    country.name,
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.title,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    country.dialCode,
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.body,
                      fontSize: 13.5,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  onTap: () => widget.onCountrySelected(country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Country> _getAllCountries() {
    return [
      Country(name: 'Afghanistan', code: 'AF', dialCode: '+93', flag: '🇦🇫'),
      Country(name: 'Albania', code: 'AL', dialCode: '+355', flag: '🇦🇱'),
      Country(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿'),
      Country(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
      Country(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
      Country(name: 'Austria', code: 'AT', dialCode: '+43', flag: '🇦🇹'),
      Country(name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
      Country(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
      Country(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
      Country(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
      Country(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
      Country(name: 'Denmark', code: 'DK', dialCode: '+45', flag: '🇩🇰'),
      Country(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
      Country(name: 'Finland', code: 'FI', dialCode: '+358', flag: '🇫🇮'),
      Country(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
      Country(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
      Country(name: 'Greece', code: 'GR', dialCode: '+30', flag: '🇬🇷'),
      Country(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
      Country(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
      Country(name: 'Iran', code: 'IR', dialCode: '+98', flag: '🇮🇷'),
      Country(name: 'Iraq', code: 'IQ', dialCode: '+964', flag: '🇮🇶'),
      Country(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
      Country(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
      Country(name: 'Jordan', code: 'JO', dialCode: '+962', flag: '🇯🇴'),
      Country(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
      Country(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
      Country(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
      Country(name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
      Country(name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
      Country(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
      Country(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
      Country(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
      Country(name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
      Country(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
      Country(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
      Country(name: 'Russia', code: 'RU', dialCode: '+7', flag: '🇷🇺'),
      Country(name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
      Country(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
      Country(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
      Country(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
      Country(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
      Country(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
      Country(name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
      Country(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
      Country(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
      Country(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),
      Country(
        name: 'United Arab Emirates',
        code: 'AE',
        dialCode: '+971',
        flag: '🇦🇪',
      ),
      Country(
        name: 'United Kingdom',
        code: 'GB',
        dialCode: '+44',
        flag: '🇬🇧',
      ),
      Country(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
      Country(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),
    ];
  }
}
