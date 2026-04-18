// lib/features/profile/edit_profile.dart

// ignore_for_file: prefer_final_fields, unused_field, deprecated_member_use

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/settings/settings_import.dart';
import 'package:provider/provider.dart';

import '../../../../api/app_api.dart';
import '../../../../api/services/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/user/user_profile_model.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/profile/profile_form_section.dart';
import '../../../../widgets/profile/profile_header_section.dart';
import '../../../../widgets/show_toast.dart';
import 'set_password.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> with UtilityMixin {
  // =====================
  // Controllers & Models
  // =====================
  final _formControllers = FormControllers();
  final ApiService _apiService = ApiService();

  // Initial and current state
  UserProfileModel? _initialProfile;
  String _selectedGender = 'Other';
  String? _countryCode = '91';

  // Error messages
  String _usernameErrorText = '';
  String? currentPasswordErrorText;
  String? newPasswordErrorText;
  String? confirmPasswordErrorText;

  // Images
  File? _coverImage;
  File? _profileImage;
  Uint8List? _cachedProfileImage;
  Uint8List? _cachedCoverImage;

  // Loading states
  bool _isLoading = false;
  bool _isSaveProfile = false;
  bool _isSaveUsername = false;
  bool _isUploadingCover = false;
  bool _isUploadingProfile = false;

  // Change tracking
  bool _showUpdateProfileButton = false;
  bool _showUpdateUsernameButton = false;

  // Set Password
  bool _hasGoogleAuth = false;
  bool _hasLocalPassword = false;

  // =====================
  // Lifecycle Methods
  // =====================
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _setupListeners();
  }

  @override
  void dispose() {
    _formControllers.dispose();
    super.dispose();
  }

  // =====================
  // Data Loading
  // =====================
  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final response = await Dio().get(
        ApiConstants.userProfile,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200 && mounted) {
        final profile = UserProfileModel.fromJson(response.data);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        setState(() {
          _initialProfile = profile;
          _selectedGender = _getDisplayGender(profile.gender);
          _countryCode = profile.countryCode;
          _formControllers.populateFromProfile(profile);

          _hasGoogleAuth = response.data['has_google_auth'] ?? false;
          _hasLocalPassword = response.data['has_local_password'] ?? false;

          // Cache images
          _cachedProfileImage = userProvider.getProfileImage(
            profile.profilePictureUrl,
          );
          _cachedCoverImage = userProvider.getCoverImage(profile.coverPhotoUrl);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =====================
  // Setup Listeners
  // =====================
  void _setupListeners() {
    _formControllers.firstName.addListener(_checkProfileChanges);
    _formControllers.lastName.addListener(_checkProfileChanges);
    _formControllers.bio.addListener(_checkProfileChanges);
    _formControllers.dob.addListener(_checkProfileChanges);
    _formControllers.username.addListener(_checkUsernameChanges);
  }

  void _checkProfileChanges() {
    if (_initialProfile == null || _isLoading) return;

    setState(() {
      _showUpdateProfileButton =
          _formControllers.firstName.text != _initialProfile!.firstName ||
          _formControllers.lastName.text != _initialProfile!.lastName ||
          _formControllers.bio.text != _initialProfile!.bio ||
          _formControllers.dob.text != (_initialProfile!.dob ?? '') ||
          _selectedGender != _getDisplayGender(_initialProfile!.gender);
    });
  }

  void _checkUsernameChanges() {
    if (_initialProfile == null || _isLoading) return;

    setState(() {
      _showUpdateUsernameButton =
          _formControllers.username.text != _initialProfile!.username;
    });
  }

  // =====================
  // Update Methods
  // =====================
  Future<void> _updateProfile() async {
    setState(() => _isSaveProfile = true);

    final errorMessage = await _apiService.updateProfile(
      firstName: _formControllers.firstName.text.trim(),
      lastName: _formControllers.lastName.text.trim(),
      bio: _formControllers.bio.text.trim(),
      dob: _formControllers.dob.text,
      gender: _selectedGender.toLowerCase(),
    );

    if (!mounted) return;

    if (errorMessage.isEmpty) {
      // Success - update initial values
      _initialProfile = _initialProfile?.copyWith(
        firstName: _formControllers.firstName.text.trim(),
        lastName: _formControllers.lastName.text.trim(),
        bio: _formControllers.bio.text.trim(),
        dob: _formControllers.dob.text,
        gender: _selectedGender.toLowerCase(),
      );

      setState(() => _showUpdateProfileButton = false);
      showToast(message: 'Profile updated successfully');
    }

    setState(() => _isSaveProfile = false);
  }

  Future<void> _updateUsername() async {
    final username = _formControllers.username.text.trim();

    if (username.isEmpty) {
      setState(() => _usernameErrorText = 'Username is required');
      return;
    }

    setState(() => _isSaveUsername = true);

    final errorMessage = await _apiService.updateUsername(
      newUsername: username,
    );

    if (!mounted) return;

    setState(() {
      _usernameErrorText = errorMessage;
      if (errorMessage.isEmpty) {
        _initialProfile = _initialProfile?.copyWith(username: username);
        _showUpdateUsernameButton = false;
        showToast(message: 'Username updated successfully');
      }
      _isSaveUsername = false;
    });
  }

  // =====================
  // Image Picking
  // =====================
  Future<void> _pickProfilePhoto() async {
    try {
      final file = await ImagePickerService.pickImage(context: context);
      if (file == null || !mounted) return;

      final shouldCrop = await _showCropDialog();
      if (!mounted) return;

      File finalFile = file;
      if (shouldCrop == true) {
        final croppedFile = await ImagePickerService.cropImage(file);
        if (croppedFile != null) finalFile = croppedFile;
      }

      if (!mounted) return;

      setState(() {
        _profileImage = finalFile;
        _isUploadingProfile = true;
      });

      await _uploadProfilePhoto(finalFile);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking profile photo: $e');
      if (mounted) {
        setState(() {
          _isUploadingProfile = false;
          _profileImage = null;
        });
        showToast(message: 'Failed to select photo');
      }
    }
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final file = await ImagePickerService.pickImage(context: context);
      if (file == null || !mounted) return;

      final shouldCrop = await _showCropDialog();
      if (!mounted) return;

      File finalFile = file;
      if (shouldCrop == true) {
        final croppedFile = await ImagePickerService.cropImage(file);
        if (croppedFile != null) finalFile = croppedFile;
      }

      if (!mounted) return;

      setState(() {
        _coverImage = finalFile;
        _isUploadingCover = true;
      });

      await _uploadCoverPhoto(finalFile);
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking cover photo: $e');
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
          _coverImage = null;
        });
        showToast(message: 'Failed to select photo');
      }
    }
  }

  // show crop diolog
  Future<bool?> _showCropDialog() {
    return cropImageDiolog(context);
  }

  // =====================
  // Upload Methods
  // =====================
  Future<void> _uploadProfilePhoto(File file) async {
    try {
      final result = await _apiService.uploadProfileImage(file);

      if (!mounted) return;

      setState(() => _isUploadingProfile = false);

      if (result.isEmpty) {
        // showToast(message: 'Profile photo uploaded successfully!');
        await _refreshUserData();
      } else {
        showToast(message: result);
        setState(() => _profileImage = null);
      }
    } catch (e) {
      if (kDebugMode) print('Error uploading profile photo: $e');
      if (mounted) {
        setState(() {
          _isUploadingProfile = false;
          _profileImage = null;
        });
        showToast(message: 'Upload failed');
      }
    }
  }

  Future<void> _uploadCoverPhoto(File file) async {
    try {
      final result = await _apiService.uploadCoverPhoto(file);

      if (!mounted) return;

      setState(() => _isUploadingCover = false);

      if (result.isEmpty) {
        //showToast(message: 'Cover photo uploaded successfully!');
        await _refreshUserData();
      } else {
        showToast(message: result);
        setState(() => _coverImage = null);
      }
    } catch (e) {
      if (kDebugMode) print('Error uploading cover photo: $e');
      if (mounted) {
        setState(() {
          _isUploadingCover = false;
          _coverImage = null;
        });
        showToast(message: 'Upload failed');
      }
    }
  }

  Future<void> _refreshUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.loadUserData();

    if (mounted) {
      setState(() {
        _cachedProfileImage = userProvider.getProfileImage(
          userProvider.profile_picture,
        );
        _cachedCoverImage = userProvider.getCoverImage(
          userProvider.cover_photo,
        );
        _profileImage = null;
        _coverImage = null;
      });
    }
  }

  // =====================
  // Date Picker
  // =====================
  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _formControllers.dob.text =
            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // =====================
  // Helper Methods
  // =====================
  String _getDisplayGender(String storedGender) {
    switch (storedGender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Other';
    }
  }

  // =====================
  // UI Build
  // =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: const PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.editprofile,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: _isLoading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.primary),
            ) //const ProfileSimmer()
          : ListView(
              children: [
                // Profile Header with images
                ProfileHeaderSection(
                  cachedProfileImage: _cachedProfileImage,
                  cachedCoverImage: _cachedCoverImage,
                  profileImage: _profileImage,
                  coverImage: _coverImage,
                  isUploadingProfile: _isUploadingProfile,
                  isUploadingCover: _isUploadingCover,
                  onPickProfile: _pickProfilePhoto,
                  onPickCover: _pickCoverPhoto,
                ),

                SizedBox(height: 20.h),

                // Profile Form
                ProfileFormSection(
                  firstNameController: _formControllers.firstName,
                  lastNameController: _formControllers.lastName,
                  usernameController: _formControllers.username,
                  dobController: _formControllers.dob,
                  bioController: _formControllers.bio,
                  emailController: _formControllers.email,
                  phoneNumberController: _formControllers.phoneNumber,
                  selectedGender: _selectedGender,
                  countryCode: _countryCode,
                  usernameErrorText: _usernameErrorText,
                  onDateSelect: _selectDate,
                  onGenderChanged: (gender) {
                    setState(() => _selectedGender = gender);
                    _checkProfileChanges();
                  },
                  onCountryCodeChanged: (code) {
                    setState(() => _countryCode = code);
                  },
                ),

                // Save Button
                if (_showUpdateProfileButton || _showUpdateUsernameButton)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: GestureDetector(
                      onTap: () {
                        if (_showUpdateUsernameButton) _updateUsername();
                        if (_showUpdateProfileButton) _updateProfile();
                      },
                      child: Container(
                        height: 30.h,
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 10.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(50.r),
                        ),
                        child: Center(
                          child: (_isSaveProfile || _isSaveUsername)
                              ? Loader(color: Colors.white)
                              : Text(
                                  AppLocalizations.of(context)!.savechanges,
                                  style: CustomTextStyles.btnPrimaryText,
                                ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: GestureDetector(
                    onTap: () {
                      navigationPush(context, const Settings());
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: AppColors.primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.moresettings,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${AppLocalizations.of(context)!.darkmode},${AppLocalizations.of(context)!.security},${AppLocalizations.of(context)!.privacypolicy},${AppLocalizations.of(context)!.blockedaccounts}...',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onBackground.withOpacity(0.5),
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.primaryColor,
                            size: 14.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),
                if (_hasGoogleAuth && !_hasLocalPassword)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: GestureDetector(
                      onTap: () {
                        navigationPush(context, const SetPasswordScreen());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.setaccountpassword,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onBackground,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.addapasswordtosigninwithoutgoogle,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onBackground
                                          .withOpacity(0.5),
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppColors.primaryColor,
                              size: 14.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: 30.h),
              ],
            ),
    );
  }
}
