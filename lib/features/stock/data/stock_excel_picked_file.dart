import "dart:typed_data";

/// Archivo Excel elegido por el usuario.
class StockExcelPickedFile {
	const StockExcelPickedFile({required this.name, required this.bytes});

	final String name;
	final Uint8List bytes;
}
