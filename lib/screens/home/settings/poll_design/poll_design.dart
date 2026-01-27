// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';

class PollDesign extends StatefulWidget {
  const PollDesign({super.key});

  @override
  State<PollDesign> createState() => _PollDesignState();
}

class _PollDesignState extends State<PollDesign> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          'Poll Design',
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,

        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: const Center(child: Text('Poll Design Screen')),
    );
  }
}
