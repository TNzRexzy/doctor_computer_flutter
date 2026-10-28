import 'package:doctor_computer/widgets/common/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows feedback at the top and dismisses it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AppToast.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saved'),
                    duration: Duration(seconds: 1),
                  ),
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Saved'), findsNothing);
  });
}
