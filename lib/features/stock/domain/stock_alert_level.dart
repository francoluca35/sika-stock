import "stock_product.dart";

/// Estado de alerta según cantidad actual vs mínimo/máximo del ítem.
enum StockAlertLevel {
	ok,
	bajo,
	alto,
}

extension StockProductAlert on StockProduct {
	StockAlertLevel get alertLevel {
		if (cantidadMaxima > 0 && cantidad > cantidadMaxima) {
			return StockAlertLevel.alto;
		}
		if (cantidadMinima > 0 && cantidad < cantidadMinima) {
			return StockAlertLevel.bajo;
		}
		if (cantidadMinima == 0 && cantidadMaxima == 0 && cantidad == 0) {
			return StockAlertLevel.bajo;
		}
		return StockAlertLevel.ok;
	}
}
