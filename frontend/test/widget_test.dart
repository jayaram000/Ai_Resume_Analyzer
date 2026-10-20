import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initDependencyInjection();
  });

  testWidgets('ResumeAI app builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
