import 'package:flutter_test/flutter_test.dart';
import 'package:mm_cupid/main.dart';
import 'package:mm_cupid/services/api_service.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(apiService: ApiService()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
