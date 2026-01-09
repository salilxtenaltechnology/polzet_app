// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/country/country_model.dart';
import '../custom_text_styles.dart';
import 'code_bottomsheet.dart';

class CustomCountryCode extends StatefulWidget {
  final Function(Country)? onCountrySelected;
  final Country? initialCountry;
  final String? hintText;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const CustomCountryCode({
    super.key,
    this.onCountrySelected,
    this.initialCountry,
    this.hintText,
    this.textStyle,
    this.padding,
  });

  @override
  State<CustomCountryCode> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<CustomCountryCode> {
  Country? selectedCountry;

  @override
  void initState() {
    super.initState();
    selectedCountry = widget.initialCountry ?? _getDefaultCountry();
  }

  Country _getDefaultCountry() {
    return Country(
      name: 'United States',
      code: 'US',
      dialCode: '+1',
      flag: '🇺🇸',
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CountryPickerBottomSheet(
        onCountrySelected: (country) {
          setState(() {
            selectedCountry = country;
          });
          widget.onCountrySelected?.call(country);
          Navigator.pop(context);
        },
        selectedCountry: selectedCountry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: _showCountryPicker,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedCountry?.flag ?? '🌍',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                selectedCountry?.dialCode ?? '+1',
                style: CustomTextStyles.lblPrimaryText(context),
              ),
            ],
          ),
        ));
  }
}
