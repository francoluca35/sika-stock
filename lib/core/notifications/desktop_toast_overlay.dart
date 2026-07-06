import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../theme/app_tokens.dart";
import "desktop_toast_controller.dart";

/// Cuadros de aviso en la esquina inferior derecha (estilo escritorio).
class DesktopToastOverlay extends ConsumerWidget {
	const DesktopToastOverlay({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final toasts = ref.watch(desktopToastProvider);
		if (toasts.isEmpty) return const SizedBox.shrink();

		final bottom = MediaQuery.paddingOf(context).bottom;
		final right = MediaQuery.paddingOf(context).right;
		final wide = MediaQuery.sizeOf(context).width >= 720;
		final navOffset = wide ? 76.0 : 8.0;

		return Positioned(
			right: 16 + right,
			bottom: 16 + bottom + navOffset,
			child: ConstrainedBox(
				constraints: const BoxConstraints(maxWidth: 360, minWidth: 280),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						for (final toast in toasts.reversed)
							Padding(
								padding: const EdgeInsets.only(top: 10),
								child: _DesktopToastCard(toast: toast),
							),
					],
				),
			),
		);
	}
}

class _DesktopToastCard extends ConsumerWidget {
	const _DesktopToastCard({required this.toast});

	final DesktopToastItem toast;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return Material(
			color: AppTokens.whiteSurface,
			elevation: 8,
			shadowColor: Colors.black38,
			borderRadius: BorderRadius.circular(12),
			child: InkWell(
				onTap: toast.onAction,
				borderRadius: BorderRadius.circular(12),
				child: Container(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(12),
						border: Border.all(color: Colors.black87, width: 1.4),
					),
					padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Container(
								width: 40,
								height: 40,
								decoration: BoxDecoration(
									color: AppTokens.yellowHeader,
									borderRadius: BorderRadius.circular(10),
									border: Border.all(color: Colors.black87, width: 1),
								),
								child: const Icon(
									Icons.notifications_active,
									color: Colors.black87,
									size: 22,
								),
							),
							const SizedBox(width: 12),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											toast.title,
											style: const TextStyle(
												fontWeight: FontWeight.w800,
												fontSize: 13.5,
												color: Colors.black87,
											),
										),
										const SizedBox(height: 4),
										Text(
											toast.message,
											style: const TextStyle(
												fontSize: 13,
												height: 1.3,
												fontWeight: FontWeight.w600,
												color: Colors.black87,
											),
										),
										if (toast.subtitle != null &&
												toast.subtitle!.trim().isNotEmpty) ...[
											const SizedBox(height: 4),
											Text(
												toast.subtitle!,
												style: TextStyle(
													fontSize: 12,
													height: 1.25,
													color: Colors.grey.shade700,
												),
											),
										],
										if (toast.actionLabel != null &&
												toast.onAction != null) ...[
											const SizedBox(height: 8),
											Text(
												toast.actionLabel!,
												style: TextStyle(
													fontSize: 12,
													fontWeight: FontWeight.w800,
													color: Colors.blue.shade800,
												),
											),
										],
									],
								),
							),
							IconButton(
								tooltip: "Cerrar",
								padding: EdgeInsets.zero,
								constraints: const BoxConstraints(
									minWidth: 32,
									minHeight: 32,
								),
								icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
								onPressed: () =>
										ref.read(desktopToastProvider.notifier).dismiss(toast.id),
							),
						],
					),
				),
			),
		);
	}
}
