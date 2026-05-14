import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "auth_providers.dart";

/// Sesión activa; se actualiza con [onAuthStateChange] (restauración async en web).
final authSessionProvider =
		NotifierProvider<AuthSessionNotifier, Session?>(AuthSessionNotifier.new);

class AuthSessionNotifier extends Notifier<Session?> {
	StreamSubscription<AuthState>? _sub;

	@override
	Session? build() {
		ref.keepAlive();
		final client = ref.watch(supabaseClientProvider);
		_sub?.cancel();
		_sub = client.auth.onAuthStateChange.listen((event) {
			state = event.session;
		});
		ref.onDispose(() {
			unawaited(_sub?.cancel());
			_sub = null;
		});
		return client.auth.currentSession;
	}
}
