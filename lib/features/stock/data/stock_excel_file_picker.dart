import "stock_excel_file_picker_io.dart"
		if (dart.library.js_interop) "stock_excel_file_picker_web.dart" as impl;

import "stock_excel_picked_file.dart";

export "stock_excel_picked_file.dart";

Future<StockExcelPickedFile?> pickStockExcelFile() => impl.pickStockExcelFile();
