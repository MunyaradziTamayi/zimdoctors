import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zimdoctors/Screens/login_screen.dart';
import 'package:zimdoctors/Screens/registration_screen.dart';
import 'package:zimdoctors/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('welcome: can navigate to Sign In and Sign Up', (tester) async {
    await tester.pumpWidget(const zimdoctors());
    await tester.pumpAndSettle();

    // Sign In
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Back then Sign Up
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationScreen), findsOneWidget);
  });
}

