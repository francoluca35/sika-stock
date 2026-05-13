import "dart:async";
import "dart:js_interop";

import "package:web/web.dart";

import "stock_excel_picked_file.dart";

/// Selector de `.xlsx` vía `<input type="file">` (web, sin plugin nativo).
Future<StockExcelPickedFile?> pickStockExcelFile() async {
	final completer = Completer<StockExcelPickedFile?>();
	final input = document.createElement("input") as HTMLInputElement
		..type = "file"
		..accept =
				".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
		..style.display = "none";
	document.body!.appendChild(input);

	var changeTriggered = false;

	void cleanup() {
		input.remove();
	}

	void complete(StockExcelPickedFile? value) {
		if (completer.isCompleted) return;
		cleanup();
		completer.complete(value);
	}

	void onChange(Event _) {
		if (changeTriggered) return;
		changeTriggered = true;
		final files = input.files;
		if (files == null || files.length == 0) {
			complete(null);
			return;
		}
		final file = files.item(0);
		if (file == null) {
			complete(null);
			return;
		}
		final name = file.name;
		if (!name.toLowerCase().endsWith(".xlsx")) {
			complete(null);
			return;
		}
		final reader = FileReader();
		reader.addEventListener(
			"loadend",
			((Event _) {
				final buf = (reader.result as JSArrayBuffer?)?.toDart;
				if (buf == null) {
					complete(null);
					return;
				}
				complete(StockExcelPickedFile(name: name, bytes: buf.asUint8List()));
			}).toJS,
		);
		reader.readAsArrayBuffer(file);
	}

	void onWindowFocus(Event _) {
		Future<void>.delayed(const Duration(milliseconds: 800), () {
			if (!changeTriggered) complete(null);
		});
	}

	input.addEventListener("change", onChange.toJS);
	window.addEventListener("focus", onWindowFocus.toJS);

	input.click();

	return completer.future.whenComplete(() {
		window.removeEventListener("focus", onWindowFocus.toJS);
	});
}
