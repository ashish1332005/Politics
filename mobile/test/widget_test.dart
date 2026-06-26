import 'package:flutter_test/flutter_test.dart';
import 'package:political_booth_crm/app.dart';
import 'package:political_booth_crm/features/auth/login_page.dart';

void main() {
  testWidgets('login screen renders CRM title and login button',
      (tester) async {
    await tester.pumpWidget(const CongressBoothApp());

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
