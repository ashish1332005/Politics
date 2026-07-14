import 'package:flutter_test/flutter_test.dart';
import 'package:political_booth_crm/app.dart';
import 'package:political_booth_crm/features/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen renders CRM title and login button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CongressBoothApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
