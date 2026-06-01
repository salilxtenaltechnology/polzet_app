// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/services/api_service.dart';
import '../../api/services/image/image_picker_service.dart';
import '../../gen/assets.gen.dart';
import '../../widgets/loader.dart';
import 'flow_scaffold.dart';

class FirstStepScreen extends StatefulWidget {
  final void Function(String name, File image) onContinue;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final File? initialImage; // ← accept saved image

  const FirstStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    this.initialImage,
  });

  @override
  State<FirstStepScreen> createState() => _FirstStepScreenState();
}

class _FirstStepScreenState extends State<FirstStepScreen> {
  final _nameController = TextEditingController();
  File? _profileImage;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _canContinue => _profileImage != null;

  @override
  void initState() {
    super.initState();
    _profileImage = widget.initialImage; // ← restore on back navigation
    _nameController.addListener(() => setState(() {}));
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    try {
      final File? pickedFile = await ImagePickerService.pickImage(
        context: context,
        allowCamera: true,
      );
      if (pickedFile != null) {
        final File? croppedFile = await ImagePickerService.cropImage(
          pickedFile,
        );
        setState(() {
          _profileImage = croppedFile ?? pickedFile; // ← replaces old image
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
    }
  }

  Future<void> _handleContinue() async {
    if (!_canContinue || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final error = await ApiService().uploadProfileImage(_profileImage!);

      if (!mounted) return;

      if (error.isNotEmpty) {
        setState(() => _errorMessage = error);
        return;
      }

      widget.onContinue('', _profileImage!);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      currentStep: 1,
      totalSteps: 3,
      onBack: widget.onBack,
      title: "Let's set up your profile",
      subtitle: 'Add a photo and your name so people can recognize you',
      primaryLabel: _isLoading ? 'Uploading...' : 'Continue',
      onPrimary: (_canContinue && !_isLoading) ? _handleContinue : null,
      onSkip: widget.onSkip,
      body: Column(
        children: [
          // ── Avatar with loading overlay inside ──
          GestureDetector(
            onTap: _isLoading ? null : _pickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar circle
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8E8E8),
                    image: DecorationImage(
                      image: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider
                          : AssetImage(Assets.images.icAvatar.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Loading overlay inside the circle
                if (_isLoading)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Loader(color: Colors.white),
                      ),
                    ),
                  ),

                // Camera badge — hide while loading
                if (!_isLoading)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.background,
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        FeatherIcons.camera,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Error message ──
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
