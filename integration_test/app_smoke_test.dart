import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zimdoctors/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: welcome screen shows auth actions', (tester) async {
    await tester.pumpWidget(const zimdoctors());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}

