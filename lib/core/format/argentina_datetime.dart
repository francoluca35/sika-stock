import "package:intl/intl.dart";
import "package:timezone/data/latest.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;

/// Hora civil de Argentina (America/Argentina/Buenos_Aires).
abstract final class ArgentinaDateTime {
	static bool _ready = false;

	static void ensureInitialized() {
		if (_ready) return;
		tz_data.initializeTimeZones();
		_ready = true;
	}

	static tz.Location get _location =>
			tz.getLocation("America/Argentina/Buenos_Aires");

	/// Normaliza a UTC y convierte a hora Argentina.
	static DateTime toArgentina(DateTime value) {
		ensureInitialized();
		final utc = value.isUtc ? value : value.toUtc();
		return tz.TZDateTime.from(utc, _location);
	}

	/// Parse ISO de Supabase → hora Argentina para mostrar.
	static DateTime parseDbToArgentina(Object? raw) {
		if (raw == null) return toArgentina(DateTime.now().toUtc());
		if (raw is DateTime) return toArgentina(raw);
		final parsed = DateTime.tryParse(raw.toString());
		if (parsed == null) return toArgentina(DateTime.now().toUtc());
		return toArgentina(parsed);
	}

	static final DateFormat _dateTime = DateFormat("dd/MM/yyyy HH:mm");
	static final DateFormat _dateOnly = DateFormat("dd/MM/yyyy");

	static String formatDateTime(DateTime value) =>
			_dateTime.format(toArgentina(value));

	static String formatDateOnly(DateTime value) =>
			_dateOnly.format(toArgentina(value));

	static String formatDb(Object? raw) => formatDateTime(parseDbToArgentina(raw));
}
