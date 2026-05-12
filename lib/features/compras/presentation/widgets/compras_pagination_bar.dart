import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "compras_screen_metrics.dart";

/// Paginación con flechas y números; cómoda en móvil (scroll horizontal en páginas).
class ComprasPaginationBar extends StatelessWidget {
	const ComprasPaginationBar({
		super.key,
		required this.currentPage,
		required this.totalPages,
		required this.onPage,
	});

	final int currentPage;
	final int totalPages;
	final ValueChanged<int> onPage;

	@override
	Widget build(BuildContext context) {
		final bottom = MediaQuery.paddingOf(context).bottom;
		final pad = ComprasScreenMetrics.horizontalPadding(context);

		return Padding(
			padding: EdgeInsets.fromLTRB(pad.left, 8, pad.right, 12 + bottom),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					IconButton(
						onPressed: currentPage > 0 ? () => onPage(currentPage - 1) : null,
						icon: const Icon(Icons.chevron_left),
						color: Colors.black87,
						tooltip: "Anterior",
					),
					Flexible(
						child: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: Row(
								mainAxisSize: MainAxisSize.min,
								children: [
									for (var i = 0; i < totalPages; i++)
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 3),
											child: InkWell(
												onTap: () => onPage(i),
												borderRadius: BorderRadius.circular(8),
												child: Container(
													constraints: const BoxConstraints(
														minWidth: 36,
														minHeight: 36,
													),
													alignment: Alignment.center,
													padding: const EdgeInsets.symmetric(horizontal: 8),
													decoration: BoxDecoration(
														color: currentPage == i
															? AppTokens.yellowHeader
															: AppTokens.whiteSurface,
														borderRadius: BorderRadius.circular(8),
														border: Border.all(
															color: currentPage == i
																? Colors.black26
																: AppTokens.greyBorder,
														),
													),
													child: Text(
														"${i + 1}",
														style: TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 13,
															color: currentPage == i
																? Colors.black87
																: Colors.grey.shade700,
														),
													),
												),
											),
										),
								],
							),
						),
					),
					IconButton(
						onPressed: currentPage < totalPages - 1
							? () => onPage(currentPage + 1)
							: null,
						icon: const Icon(Icons.chevron_right),
						color: Colors.black87,
						tooltip: "Siguiente",
					),
				],
			),
		);
	}
}
