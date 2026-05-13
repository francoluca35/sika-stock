import "package:file_picker/file_picker.dart";

import "stock_excel_picked_file.dart";

Future<StockExcelPickedFile?> pickStockExcelFile() async {
	final picked = await FilePicker.pickFiles(
		type: FileType.custom,
		allowedExtensions: const ["xlsx"],
		withData: true,
		allowMultiple: false,
	);
	if (picked == null || picked.files.isEmpty) return null;
	final file = picked.files.first;
	final bytes = file.bytes;
	if (bytes == null) return null;
	return StockExcelPickedFile(name: file.name, bytes: bytes);
}
