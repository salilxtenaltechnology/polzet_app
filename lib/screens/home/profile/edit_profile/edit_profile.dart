// ignore_for_file: unused_element, deprecated_member_use

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../api/services/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../models/country/country_model.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/country_code/code_bottomsheet.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../widgets/base64/image_convert.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isUploadingProfile = false;
  bool _obscurePassword = true;
  bool _isSaving = false;
  DateTime? _dob;
  bool _hasChanges = false;

  String _selectedGender = 'Other';
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalUsername = '';
  String _originalDob = '';
  String _originalGender = '';

  String _firstNameErrorText = '';
  String _lastNameErrorText = '';
  String _usernameErrorText = '';

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  Country _selectedCountry = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
  );
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupListeners();
  }

  void _setupListeners() {
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    bool needsStateUpdate = false;
    if (_usernameErrorText.isNotEmpty) {
      _usernameErrorText = '';
      needsStateUpdate = true;
    }
    if (_firstNameErrorText.isNotEmpty) {
      _firstNameErrorText = '';
      needsStateUpdate = true;
    }
    if (_lastNameErrorText.isNotEmpty) {
      _lastNameErrorText = '';
      needsStateUpdate = true;
    }

    if (needsStateUpdate) {
      setState(() {});
    }

    _checkChanges();
  }

  void _checkChanges() {
    final dobStr = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';
    final hasChanges =
        _firstNameController.text != _originalFirstName ||
        _lastNameController.text != _originalLastName ||
        _usernameController.text != _originalUsername ||
        dobStr != _originalDob ||
        _selectedGender != _originalGender;

    if (_hasChanges != hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _firstNameController.text = userProvider.firstName ?? '';
    _lastNameController.text = userProvider.lastName ?? '';
    _usernameController.text = userProvider.username ?? '';
    _emailController.text = userProvider.email ?? '';
    _phoneController.text = userProvider.mobile_number ?? '';
    _dob = userProvider.dob != null ? DateTime.parse(userProvider.dob!) : null;
    final rawGender = userProvider.gender ?? 'Other';
    _selectedGender = _genderOptions.firstWhere(
      (g) => g.toLowerCase() == rawGender.toLowerCase(),
      orElse: () => 'Other',
    );

    _originalFirstName = _firstNameController.text;
    _originalLastName = _lastNameController.text;
    _originalUsername = _usernameController.text;
    _originalDob = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';
    _originalGender = _selectedGender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Profile photo ──────────────────────────────────────────────────────────
  Future<void> _pickProfilePhoto() async {
    try {
      final file = await ImagePickerService.pickImage(context: context);
      if (file == null || !mounted) return;

      final shouldCrop = await cropImageDiolog(context);
      if (!mounted) return;

      File finalFile = file;
      if (shouldCrop == true) {
        final croppedFile = await ImagePickerService.cropImage(file);
        if (croppedFile != null) finalFile = croppedFile;
      }

      if (!mounted) return;
      setState(() => _isUploadingProfile = true);

      final result = await ApiService().uploadProfileImage(finalFile);

      if (!mounted) return;
      if (result.isEmpty) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
      }

      setState(() => _isUploadingProfile = false);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking profile photo: $e');
      if (mounted) setState(() => _isUploadingProfile = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    bool hasError = false;
    setState(() {
      _firstNameErrorText = '';
      _lastNameErrorText = '';
      _usernameErrorText = '';
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();

    if (firstName.isEmpty) {
      setState(() => _firstNameErrorText = 'First name is required');
      hasError = true;
    }
    if (lastName.isEmpty) {
      setState(() => _lastNameErrorText = 'Last name is required');
      hasError = true;
    }
    if (username.isEmpty) {
      setState(() => _usernameErrorText = 'Username is required');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isSaving = true);

    bool profileUpdated = false;
    bool usernameUpdated = false;

    final dobStr = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '';

    if (firstName != _originalFirstName ||
        lastName != _originalLastName ||
        dobStr != _originalDob ||
        _selectedGender != _originalGender) {
      final bioStr =
          Provider.of<UserProvider>(context, listen: false).bio ?? '';
      final profileError = await ApiService().updateProfile(
        firstName: firstName,
        lastName: lastName,
        bio: bioStr,
        dob: dobStr,
        gender: _selectedGender.toLowerCase(),
      );

      if (profileError.isEmpty) {
        profileUpdated = true;
        _originalFirstName = firstName;
        _originalLastName = lastName;
        _originalDob = dobStr;
        _originalGender = _selectedGender;
      }
    }

    if (username != _originalUsername) {
      final usernameError = await ApiService().updateUsername(
        newUsername: username,
      );

      if (usernameError.isNotEmpty) {
        // ← must be isNotEmpty, not isEmpty
        if (mounted) {
          setState(() => _usernameErrorText = usernameError);
        }
        setState(() => _isSaving = false);
        return;
      } else {
        if (mounted) {
          setState(() {
            usernameUpdated = true;
            _originalUsername = username;
            _usernameErrorText = usernameError;
          });
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    _checkChanges();

    if (profileUpdated || usernameUpdated) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData();
    }
  }

  // ── Country picker ─────────────────────────────────────────────────────────
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerBottomSheet(
        selectedCountry: _selectedCountry,
        onCountrySelected: (country) {
          setState(() => _selectedCountry = country);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      helpText: 'Select date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
      });
      _checkChanges();
    }
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF898989),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String errorText = '',
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTextStyles.subText.copyWith(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.subText.copyWith(
                fontSize: 14.5,
                color: const Color(0XFF898989),
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.primary),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: AppTextStyles.subText.copyWith(
          fontSize: 15.3,
          color: Theme.of(context).colorScheme.onBackground,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: AppTextStyles.subText.copyWith(
            fontSize: 14.5,
            color: const Color(0xFFB3B3B3),
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF8E8E8E),
              size: 22,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCountryCodeButton() {
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              _selectedCountry.dialCode,
              style: AppTextStyles.subText.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF8A8A8A),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    final userProvider = Provider.of<UserProvider>(context);
    final profileUrl = userProvider.profile_picture;
    final imageBytes = profileUrl != null ? getProfileImage(profileUrl) : null;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: imageBytes != null
                ? MemoryImage(imageBytes)
                : AssetImage(Assets.images.icAvatar.path) as ImageProvider,
            child: _isUploadingProfile
                ? Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.35),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingProfile ? null : _pickProfilePhoto,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.background, width: 1.5),
                ),
                child: Icon(
                  FeatherIcons.camera,
                  size: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          dropdownColor: Theme.of(context).colorScheme.tertiaryContainer,
          isExpanded: true,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.5,
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF8A8A8A),
          ),
          items: _genderOptions.map((gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedGender = newValue);
              _checkChanges();
            }
          },
          iconEnabledColor: const Color(0XFF898989),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.editprofile,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _hasChanges
              ? IconButton(onPressed: _save, icon: const Icon(Icons.check))
              : const SizedBox(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          _buildAvatar(),
          const SizedBox(height: 28),

          // ── First Name ──────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.firstname),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _firstNameController,
            hint: AppLocalizations.of(context)!.enterfirstname,
            errorText: _firstNameErrorText,
          ),
          const SizedBox(height: 16),

          // ── Last Name ───────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.lastname),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _lastNameController,
            hint: AppLocalizations.of(context)!.enterlastname,
            errorText: _lastNameErrorText,
          ),
          const SizedBox(height: 16),

          // ── Username ────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.username),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _usernameController,
            hint: AppLocalizations.of(context)!.enterusername,
            errorText: _usernameErrorText,
          ),
          const SizedBox(height: 16),

          // ── Email ───────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.email),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _emailController,
            hint: 'Enter email address',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // ── Phone ───────────────────────────────────────────────────────
          _buildFieldLabel(AppLocalizations.of(context)!.phonenumber),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildCountryCodeButton(),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: _phoneController,
                  hint: AppLocalizations.of(context)!.enteryourphonenumber,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(AppLocalizations.of(context)!.dateofbirth),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dob != null
                          ? DateFormat('dd MMM yyyy').format(_dob!)
                          : AppLocalizations.of(context)!.selectyourdateofbirth,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: _dob != null
                            ? Theme.of(context).colorScheme.onBackground
                            : const Color(0xFFB3B3B3),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFFB3B3B3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(AppLocalizations.of(context)!.gender),
          const SizedBox(height: 6),
          _buildGenderField(),
        ],
      ),
    );
  }
}
