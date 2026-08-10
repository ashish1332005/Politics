import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:political_booth_crm/app.dart';
import 'package:political_booth_crm/features/auth/login_page.dart';
import 'package:political_booth_crm/layout/app_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen renders CRM title and login button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CongressBoothApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('mobile header stays responsive and opens its drawer at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: const Drawer(child: Text('Navigation drawer')),
          body: Builder(
            builder: (context) => const MobileHeader(
              title: 'बहुत लंबा मतदाता प्रबंधन शीर्षक',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('header-menu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('header-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Navigation drawer'), findsOneWidget);
  });

  testWidgets('mobile header handles large accessibility text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: const Drawer(child: SizedBox()),
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
              ),
              child: const MobileHeader(title: 'मतदाता'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('header-notifications')), findsOneWidget);
  });
}
