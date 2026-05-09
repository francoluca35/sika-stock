import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:sika_stock/main.dart";

void main() {
	testWidgets("App arranca", (WidgetTester tester) async {
		await tester.pumpWidget(
			const ProviderScope(
				child: SikaStockApp(),
			),
		);
		expect(find.text("Sika Stock"), findsOneWidget);
	});
}
