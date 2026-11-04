import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polzet_app/screens/home/new poll/widgets/poll_keyboard_dismiss_wrapper.dart';
import 'package:polzet_app/widgets/text_field/secondry_textfield.dart';

void main() {
  testWidgets('PollKeyboardDismissWrapper unfocuses when tapping outside',
      (WidgetTester tester) async {
    final controller1 = TextEditingController(text: 'Initial 1');
    final controller2 = TextEditingController(text: 'Initial 2');
    final focusNode1 = FocusNode();
    final focusNode2 = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PollKeyboardDismissWrapper(
            child: Column(
              children: [
                Container(
                  key: const Key('outside_space'),
                  height: 100,
                  width: double.infinity,
                  color: Colors.grey,
                ),
                TextField(
                  key: const Key('field_1'),
                  controller: controller1,
                  focusNode: focusNode1,
                ),
                TextField(
                  key: const Key('field_2'),
                  controller: controller2,
                  focusNode: focusNode2,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 1. Tap field 1 to focus
    await tester.tap(find.byKey(const Key('field_1')));
    await tester.pump();
    expect(focusNode1.hasFocus, isTrue);

    // 2. Tap outside space -> should unfocus
    await tester.tap(find.byKey(const Key('outside_space')));
    await tester.pump();
    expect(focusNode1.hasFocus, isFalse);
    expect(controller1.text, 'Initial 1');

    // 3. Switch between fields: tap field 1 then tap field 2
    await tester.tap(find.byKey(const Key('field_1')));
    await tester.pump();
    expect(focusNode1.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('field_2')));
    await tester.pump();
    expect(focusNode2.hasFocus, isTrue);
    expect(focusNode1.hasFocus, isFalse);
    expect(controller2.text, 'Initial 2');

    // 4. Tap field 2 again: stays focused, text unchanged
    await tester.tap(find.byKey(const Key('field_2')));
    await tester.pump();
    expect(focusNode2.hasFocus, isTrue);
    expect(controller2.text, 'Initial 2');
  });

  testWidgets(
      'PollKeyboardDismissWrapper unfocuses when keyboard transitions from visible to hidden',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'Poll Question');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PollKeyboardDismissWrapper(
            child: Column(
              children: [
                TextField(
                  key: const Key('question_field'),
                  controller: controller,
                  focusNode: focusNode,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Focus text field
    await tester.tap(find.byKey(const Key('question_field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Simulate keyboard showing (insets > 0)
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Simulate keyboard dismissing via Android Back button (insets become 0)
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.binding.handleMetricsChanged();
    await tester.pump();

    // Must lose primary focus
    expect(focusNode.hasFocus, isFalse);
    // Text must remain unchanged
    expect(controller.text, 'Poll Question');
  });

  testWidgets(
      'Works with SecondryTextfield and dynamic poll options without explicit focus nodes',
      (WidgetTester tester) async {
    final questionController = TextEditingController(text: 'Best Framework?');
    final descController = TextEditingController(text: '#flutter #dart');
    final option1Controller = TextEditingController(text: 'Flutter');
    final option2Controller = TextEditingController(text: 'React Native');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PollKeyboardDismissWrapper(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    key: const Key('empty_header'),
                    height: 80,
                    width: double.infinity,
                    color: Colors.blue,
                  ),
                  SecondryTextfield(
                    key: const Key('q_field'),
                    controller: questionController,
                    hintText: 'Enter question',
                  ),
                  SecondryTextfield(
                    key: const Key('desc_field'),
                    controller: descController,
                    hintText: 'Enter description',
                  ),
                  SecondryTextfield(
                    key: const Key('opt1_field'),
                    controller: option1Controller,
                    hintText: 'Option 1',
                  ),
                  SecondryTextfield(
                    key: const Key('opt2_field'),
                    controller: option2Controller,
                    hintText: 'Option 2',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Tap Option 1
    await tester.tap(find.byKey(const Key('opt1_field')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    // Simulate keyboard open
    tester.view.viewInsets = const FakeViewPadding(bottom: 350);
    tester.binding.handleMetricsChanged();
    await tester.pump();

    // Type text into option 1
    await tester.enterText(find.byKey(const Key('opt1_field')), 'Flutter 3.x');
    await tester.pump();
    expect(option1Controller.text, 'Flutter 3.x');

    // Switch to option 2 directly
    await tester.tap(find.byKey(const Key('opt2_field')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('opt2_field')), 'React Native 0.74');
    await tester.pump();
    expect(option1Controller.text, 'Flutter 3.x');
    expect(option2Controller.text, 'React Native 0.74');

    // Dismiss keyboard via Android Back button
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.binding.handleMetricsChanged();
    await tester.pump();

    final scope = FocusScope.of(tester.element(find.byKey(const Key('empty_header'))));
    expect(scope.focusedChild, isNull);

    // Text in all fields preserved
    expect(questionController.text, 'Best Framework?');
    expect(descController.text, '#flutter #dart');
    expect(option1Controller.text, 'Flutter 3.x');
    expect(option2Controller.text, 'React Native 0.74');

    // Tap outside on header
    await tester.tap(find.byKey(const Key('opt2_field')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('empty_header')));
    await tester.pump();
    expect(scope.focusedChild, isNull);
  });
}
