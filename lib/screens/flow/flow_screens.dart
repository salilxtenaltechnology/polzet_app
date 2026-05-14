// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../api/services/api_service.dart';
import '../../../data/token/shared_preferences.dart';
import '../home/home_imports.dart';
import 'first_step_screen.dart';
import 'second_step_screen.dart';
import 'third_step_screen.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});
  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  int _step = 0;
  String _userName = '';
  File? _savedProfileImage; 

  @override
  void initState() {
    super.initState();
    _prefetchHomeFeed();
  }

  void _prefetchHomeFeed() async {
    try {
      final response = await ApiService.fetchHomeFeedPosts();
      if (response.results.isNotEmpty) {
        final jsonList = response.results.map((post) => post.toJson()).toList();
        final jsonString = jsonEncode(jsonList);
        await SharedPrefService.setString('home_feed_cache', jsonString);
        await SharedPrefService.setString(
          'home_feed_cache_time',
          DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('Prefetch home feed error: $e');
    }
  }

  void _next() {
    if (_step < 2) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _skip() => _next();

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 0)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: switch (_step) {
        0 => FirstStepScreen(
            key: const ValueKey(0),
            initialImage: _savedProfileImage, // ← restore saved image
            onContinue: (name, image) {
              setState(() {
                _userName = name;
                _savedProfileImage = image; // ← save it
                _step++;
              });
            },
            onSkip: _skip,
            onBack: null,
          ),
        1 => SecondStepScreen(
            key: const ValueKey(1),
            onContinue: _next,
            onSkip: _skip,
            onBack: _back,
          ),
        _ => ThirdStepScreen(
            key: const ValueKey(2),
            onContinue: _goHome,
            onSkip: _goHome,
            onBack: _back,
          ),
      },
    );
  }
}