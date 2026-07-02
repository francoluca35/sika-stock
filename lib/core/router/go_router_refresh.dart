import "dart:async";

import "package:flutter/foundation.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Notifica a GoRouter solo en cambios de sesión relevantes (no en cada refresh de token).
final class GoRouterRefreshStream extends ChangeNotifier {
	GoRouterRefreshStream(Stream<AuthState> stream) {
		_sub = stream.listen((event) {
			switch (event.event) {
				case AuthChangeEvent.initialSession:
				case AuthChangeEvent.signedIn:
				case AuthChangeEvent.signedOut:
					notifyListeners();
				default:
					break;
			}
		});
	}

	late final StreamSubscription<AuthState> _sub;

	@override
	void dispose() {
		_sub.cancel();
		super.dispose();
	}
}
