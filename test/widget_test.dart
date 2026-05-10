import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:sika_stock/core/config/env.dart";
import "package:sika_stock/core/supabase/supabase_bootstrap.dart";
import "package:sika_stock/main.dart";

void main() {
	setUpAll(() async {
		TestWidgetsFlutterBinding.ensureInitialized();
		SharedPreferences.setMockInitialValues(<String, Object>{});
		await Env.load();
		await SupabaseBootstrap.initialize();
	});

	testWidgets("App arranca en login", (WidgetTester tester) async {
		await tester.pumpWidget(
			const ProviderScope(
				child: SikaStockApp(),
			),
		);
		await tester.pumpAndSettle();
		expect(find.textContaining("INICIAR SESIÓN"), findsAtLeastNWidgets(1));
	});
}
