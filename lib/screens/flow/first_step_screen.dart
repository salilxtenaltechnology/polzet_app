import 'dart:io';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/services/image/image_picker_service.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import 'flow_scaffold.dart';

class FirstStepScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  const FirstStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<FirstStepScreen> createState() => _FirstStepScreenState();
}

class _FirstStepScreenState extends State<FirstStepScreen> {
  final _nameController = TextEditingController();
  File? _profileImage;

  static const _kDark = Color(0xFF1A1A1A);

  // ── Validation: both name and image required
  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty && _profileImage != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {})); // rebuild on every keystroke
  }

  Future<void> _pickImage() async {
    try {
      final File? pickedFile = await ImagePickerService.pickImage(
        context: context,
        allowCamera: true,
      );
      if (pickedFile != null) {
        final File? croppedFile = await ImagePickerService.cropImage(pickedFile);
        setState(() => _profileImage = croppedFile ?? pickedFile);
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
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
      primaryLabel: 'Continue',
      onPrimary: _canContinue ? widget.onContinue : null, // ← disabled until valid
      onSkip: widget.onSkip,
      body: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
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
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Icon(FeatherIcons.camera, size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14.5, color: _kDark),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: AppTextStyles.subText.copyWith(
                fontSize: 14.5,
                color: const Color(0xFFAAAAAA),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        ],
      ),
    );
  }
}