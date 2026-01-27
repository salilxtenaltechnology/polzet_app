// lib/features/profile/widgets/profile_form_section.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/country/country_model.dart';
import '../../models/user/user_profile_model.dart';
import '../country code/custom_country_code.dart';
import '../custom_card.dart';
import '../custom_text_styles.dart';

class ProfileFormSection extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController usernameController;
  final TextEditingController dobController;
  final TextEditingController bioController;
  final TextEditingController emailController;
  final TextEditingController phoneNumberController;
  final String selectedGender;
  final String? countryCode;
  final String usernameErrorText;
  final VoidCallback onDateSelect;
  final Function(String) onGenderChanged;
  final Function(String) onCountryCodeChanged;

  const ProfileFormSection({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.usernameController,
    required this.dobController,
    required this.bioController,
    required this.emailController,
    required this.phoneNumberController,
    required this.selectedGender,
    required this.countryCode,
    required this.usernameErrorText,
    required this.onDateSelect,
    required this.onGenderChanged,
    required this.onCountryCodeChanged,
  });

  @override
  State<ProfileFormSection> createState() => _ProfileFormSectionState();
}

class _ProfileFormSectionState extends State<ProfileFormSection> {
  final List<String> genderOptions = ['Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: CustomCard(
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.usersettings,
              style: CustomTextStyles.lblContentText(context),
            ),
            SizedBox(height: 12.h),

            // First Name
            _buildFieldLabel(AppLocalizations.of(context)!.firstname),
            _buildTextField(
              widget.firstNameController,
              TextInputType.text,
              AppLocalizations.of(context)!.enterfirstname,
            ),
            SizedBox(height: 12.h),

            // Last Name
            _buildFieldLabel(AppLocalizations.of(context)!.lastname),
            _buildTextField(
              widget.lastNameController,
              TextInputType.text,
              AppLocalizations.of(context)!.enterlastname,
            ),
            SizedBox(height: 12.h),

            // Username
            _buildFieldLabel(AppLocalizations.of(context)!.username),
            _buildTextField(
              widget.usernameController,
              TextInputType.text,
              AppLocalizations.of(context)!.enterusername,
            ),
            if (widget.usernameErrorText.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 5.h),
                child: Text(
                  widget.usernameErrorText,
                  style: CustomTextStyles.msgErrorText,
                ),
              ),
            SizedBox(height: 12.h),

            // Date of Birth
            _buildFieldLabel(AppLocalizations.of(context)!.dateofbirth),
            _buildDateOfBirthField(),
            SizedBox(height: 12.h),

            // Gender
            _buildFieldLabel(AppLocalizations.of(context)!.gender),
            _buildGenderField(),
            SizedBox(height: 12.h),

            // Bio
            _buildFieldLabel(AppLocalizations.of(context)!.bio),
            _buildBioTextField(
              widget.bioController,
              TextInputType.multiline,
              AppLocalizations.of(context)!.enterbio,
            ),
            SizedBox(height: 12.h),

            // Email
            _buildFieldLabel(AppLocalizations.of(context)!.enteryouremail),
            _buildTextField(
              widget.emailController,
              TextInputType.emailAddress,
              AppLocalizations.of(context)!.enteryouremail,
            ),
            SizedBox(height: 12.h),

            // Phone Number
            _buildFieldLabel(AppLocalizations.of(context)!.phonenumber),
            _buildPhoneNumber(
              widget.phoneNumberController,
              widget.countryCode ?? '91',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: CustomTextStyles.lblProfileContentText(context));
  }

  Widget _buildTextField(
    TextEditingController controller,
    TextInputType inputType,
    String hintText,
  ) {
    return SizedBox(
      height: 35.h,
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLines: null,
        style: CustomTextStyles.lblPrimaryText(context),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(left: 10.w),
          hintText: hintText,
          hintStyle: CustomTextStyles.lblPrimaryHintText(context),
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primaryColor.withOpacity(0.7),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Container(
      height: 35.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: widget.dobController,
              readOnly: true,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(left: 10.w, bottom: 5.h),
                hintText: AppStrings.lblDateOfBirth,
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
              ),
              style: CustomTextStyles.lblPrimaryText(context),
              onTap: widget.onDateSelect,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return Container(
      height: 35.h,
      width: double.infinity,
      padding: EdgeInsets.only(right: 12.w, left: 12.w, bottom: 5.h),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.selectedGender,
          dropdownColor: Theme.of(context).colorScheme.background,
          items: genderOptions.map((gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              widget.onGenderChanged(newValue);
            }
          },
          iconEnabledColor: Theme.of(
            context,
          ).colorScheme.onBackground.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildBioTextField(
    TextEditingController controller,
    TextInputType inputType,
    String hintText,
  ) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: 5,
      style: CustomTextStyles.lblPrimaryText(context),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.only(left: 10.w, top: 6.h),
        hintText: hintText,
        hintStyle: CustomTextStyles.lblPrimaryHintText(context),
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.primaryColor.withOpacity(0.7),
          ),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }

  Widget _buildPhoneNumber(
    TextEditingController controller,
    String countryCode,
  ) {
    Country? initialCountry = getCountryByDialCode(widget.countryCode ?? '91');

    return Container(
      height: 35.h,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Country code section
          CustomCountryCode(
            initialCountry: initialCountry,
            onCountrySelected: (country) {
              widget.onCountryCodeChanged(country.dialCode.replaceAll('+', ''));
            },
          ),
          // Vertical divider
          Container(
            height: 20.h,
            width: 1,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
          ),
          // Phone number input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: CustomTextStyles.lblPrimaryText(context),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.only(left: 5.w, bottom: 4.h),
                hintText: AppLocalizations.of(context)!.enteryourphonenumber,
                hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Helper Class for Form Controllers
// ============================================================

class FormControllers {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController username = TextEditingController();
  final TextEditingController dob = TextEditingController();
  final TextEditingController bio = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  final TextEditingController currentPassword = TextEditingController();
  final TextEditingController newPassword = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  void populateFromProfile(UserProfileModel profile) {
    firstName.text = profile.firstName;
    lastName.text = profile.lastName;
    username.text = profile.username;
    dob.text = profile.dob ?? '';
    bio.text = profile.bio;
    email.text = profile.email;
    phoneNumber.text = profile.mobileNumber;
  }

  UserProfileModel toProfile({
    required String gender,
    required String countryCode,
    String? profilePictureUrl,
    String? coverPhotoUrl,
  }) {
    return UserProfileModel(
      firstName: firstName.text.trim(),
      lastName: lastName.text.trim(),
      username: username.text.trim(),
      dob: dob.text,
      gender: gender,
      bio: bio.text.trim(),
      email: email.text.trim(),
      mobileNumber: phoneNumber.text.trim(),
      countryCode: countryCode,
      profilePictureUrl: profilePictureUrl,
      coverPhotoUrl: coverPhotoUrl,
    );
  }

  void addListeners(VoidCallback callback) {
    firstName.addListener(callback);
    lastName.addListener(callback);
    username.addListener(callback);
    dob.addListener(callback);
    bio.addListener(callback);
    currentPassword.addListener(callback);
    newPassword.addListener(callback);
    confirmPassword.addListener(callback);
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    username.dispose();
    dob.dispose();
    bio.dispose();
    email.dispose();
    phoneNumber.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
  }
}
