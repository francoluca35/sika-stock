import "package:flutter/material.dart";

import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../supervisor/domain/maintenance_order.dart";

enum MaintenanceTimelineStepState { done, current, pending, cancelled }

class MaintenanceTimelineStep {
	const MaintenanceTimelineStep({
		required this.label,
		required this.subtitle,
		required this.state,
		this.timestamp,
	});

	final String label;
	final String subtitle;
	final MaintenanceTimelineStepState state;
	final String? timestamp;
}

/// Pasos del flujo operativo (barra de progreso y línea de tiempo).
const List<String> maintenanceProgressStepLabels = [
	"Enviado",
	"Supervisor",
	"Pañol",
	"Listo retiro",
	"Completado",
];

int maintenanceProgressStepIndex(MaintenanceWorkflowStatus status) {
	switch (status) {
		case MaintenanceWorkflowStatus.pendingSupervisor:
			return 1;
		case MaintenanceWorkflowStatus.forwardedToPanol:
		case MaintenanceWorkflowStatus.panolRequestedCompras:
		case MaintenanceWorkflowStatus.comprasOcNotified:
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			return 2;
		case MaintenanceWorkflowStatus.supervisorStockOk:
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			return 3;
		case MaintenanceWorkflowStatus.completed:
			return 4;
		case MaintenanceWorkflowStatus.cancelled:
			return 4;
	}
}

double maintenanceProgressFraction(MaintenanceWorkflowStatus status) {
	if (status == MaintenanceWorkflowStatus.cancelled) return 0;
	final idx = maintenanceProgressStepIndex(status);
	return (idx + 1) / maintenanceProgressStepLabels.length;
}

List<MaintenanceTimelineStep> buildMaintenanceTimelineSteps(MaintenanceOrder order) {
	final alta = ArgentinaDateTime.formatDateTime(order.fechaPedido);
	final actualizado = order.updatedAt != null
			? ArgentinaDateTime.formatDateTime(order.updatedAt!)
			: null;

	if (order.workflowStatus == MaintenanceWorkflowStatus.cancelled) {
		final motivo = order.cancellationObservacion.trim();
		return [
			MaintenanceTimelineStep(
				label: "Pedido registrado",
				subtitle: "${order.producto} · ${order.quantity} u.",
				state: MaintenanceTimelineStepState.done,
				timestamp: alta,
			),
			MaintenanceTimelineStep(
				label: "Cancelado",
				subtitle: motivo.isNotEmpty
						? "Motivo: $motivo"
						: "El pedido fue cancelado en el sistema.",
				state: MaintenanceTimelineStepState.cancelled,
				timestamp: order.cancelledAt != null
						? ArgentinaDateTime.formatDateTime(order.cancelledAt!)
						: actualizado,
			),
		];
	}

	final currentIdx = maintenanceProgressStepIndex(order.workflowStatus);

	MaintenanceTimelineStep step({
		required int index,
		required String label,
		required String subtitle,
		String? timestamp,
	}) {
		final state = index < currentIdx
				? MaintenanceTimelineStepState.done
				: index == currentIdx
				? MaintenanceTimelineStepState.current
				: MaintenanceTimelineStepState.pending;
		return MaintenanceTimelineStep(
			label: label,
			subtitle: subtitle,
			state: state,
			timestamp: timestamp,
		);
	}

	return [
		step(
			index: 0,
			label: "Pediste",
			subtitle: "${order.producto} · ${order.quantity} u. · ${order.destination}",
			timestamp: alta,
		),
		step(
			index: 1,
			label: "Supervisor",
			subtitle: switch (order.workflowStatus) {
				MaintenanceWorkflowStatus.pendingSupervisor =>
					"Pendiente de revisión del supervisor.",
				MaintenanceWorkflowStatus.supervisorStockOk =>
					"Supervisor confirmó stock disponible para retiro.",
				MaintenanceWorkflowStatus.forwardedToPanol =>
					"Supervisor derivó a pañol: sin stock suficiente en depósito.",
				_ => currentIdx > 1
						? "Supervisor revisó el pedido."
						: "Esperando revisión del supervisor.",
			},
			timestamp: currentIdx >= 1 && currentIdx == 1 ? null : (currentIdx > 1 ? actualizado : null),
		),
		step(
			index: 2,
			label: "Pañol",
			subtitle: switch (order.workflowStatus) {
				MaintenanceWorkflowStatus.forwardedToPanol =>
					"Pañol gestiona la consulta / posible pedido a compras.",
				MaintenanceWorkflowStatus.panolRequestedCompras =>
					"Pañol registró pedido a compras (sin stock en planta).",
				MaintenanceWorkflowStatus.comprasOcNotified ||
				MaintenanceWorkflowStatus.comprasPurchaseDone =>
					"Pedido a compras en gestión por pañol.",
				MaintenanceWorkflowStatus.supervisorStockOk =>
					currentIdx > 2
							? "Pañol avisado para preparar el retiro."
							: "Pañol prepara el retiro (stock confirmado por supervisor).",
				_ => currentIdx > 2
						? "Pañol gestionó el pedido."
						: "Pendiente de gestión en pañol.",
			},
		),
		step(
			index: 3,
			label: "Listo para retirar",
			subtitle: switch (order.workflowStatus) {
				MaintenanceWorkflowStatus.supervisorStockOk =>
					"Podés retirar en pañol; al registrar el retiro se descuenta el inventario.",
				MaintenanceWorkflowStatus.comprasArrivedNotified =>
					"Pañol avisó que el material está listo para retirar.",
				MaintenanceWorkflowStatus.completed =>
					"Retiro registrado en pañol.",
				_ => currentIdx >= 3
						? "Material disponible para retiro en pañol."
						: "Aún no está listo para retirar.",
			},
			timestamp: order.workflowStatus == MaintenanceWorkflowStatus.comprasArrivedNotified
					? actualizado
					: null,
		),
		step(
			index: 4,
			label: "Completado",
			subtitle: order.workflowStatus == MaintenanceWorkflowStatus.completed
					? order.stockItemId != null && order.stockItemId!.isNotEmpty
							? "Retiro cerrado · se descontaron ${order.quantity} u. del inventario."
							: "Pedido cerrado en el sistema."
					: "Pendiente de cierre en pañol.",
			timestamp: order.workflowStatus == MaintenanceWorkflowStatus.completed
					? actualizado
					: null,
		),
	];
}

/// Barra de progreso compacta para listados y tablero.
class MaintenanceOrderProgressBar extends StatelessWidget {
	const MaintenanceOrderProgressBar({
		super.key,
		required this.status,
		this.height = 6,
	});

	final MaintenanceWorkflowStatus status;
	final double height;

	@override
	Widget build(BuildContext context) {
		if (status == MaintenanceWorkflowStatus.cancelled) {
			return ClipRRect(
				borderRadius: BorderRadius.circular(height),
				child: LinearProgressIndicator(
					value: 1,
					minHeight: height,
					backgroundColor: Colors.grey.shade300,
					color: Colors.grey.shade600,
				),
			);
		}

		final fraction = maintenanceProgressFraction(status);
		final current = maintenanceProgressStepIndex(status);
		final label = maintenanceProgressStepLabels[current];

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				ClipRRect(
					borderRadius: BorderRadius.circular(height),
					child: LinearProgressIndicator(
						value: fraction,
						minHeight: height,
						backgroundColor: Colors.grey.shade300,
						color: AppTokens.blackNav,
					),
				),
				const SizedBox(height: 4),
				Text(
					label,
					style: TextStyle(
						fontSize: 11,
						fontWeight: FontWeight.w600,
						color: Colors.grey.shade700,
					),
				),
			],
		);
	}
}

/// Línea de tiempo vertical unificada.
class MaintenanceOrderTimeline extends StatelessWidget {
	const MaintenanceOrderTimeline({
		super.key,
		required this.order,
		this.compact = false,
	});

	final MaintenanceOrder order;
	final bool compact;

	@override
	Widget build(BuildContext context) {
		final steps = buildMaintenanceTimelineSteps(order);
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				for (var i = 0; i < steps.length; i++)
					_TimelineRow(
						step: steps[i],
						isLast: i == steps.length - 1,
						compact: compact,
					),
			],
		);
	}
}

class _TimelineRow extends StatelessWidget {
	const _TimelineRow({
		required this.step,
		required this.isLast,
		required this.compact,
	});

	final MaintenanceTimelineStep step;
	final bool isLast;
	final bool compact;

	Color _dotColor() {
		return switch (step.state) {
			MaintenanceTimelineStepState.done => const Color(0xFF2E7D32),
			MaintenanceTimelineStepState.current => AppTokens.blackNav,
			MaintenanceTimelineStepState.pending => Colors.grey.shade400,
			MaintenanceTimelineStepState.cancelled => Colors.grey.shade700,
		};
	}

	@override
	Widget build(BuildContext context) {
		final dot = Container(
			width: compact ? 10 : 12,
			height: compact ? 10 : 12,
			decoration: BoxDecoration(
				color: _dotColor(),
				shape: BoxShape.circle,
				border: step.state == MaintenanceTimelineStepState.current
						? Border.all(color: AppTokens.yellowHeader, width: 2)
						: null,
			),
		);

		return IntrinsicHeight(
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					SizedBox(
						width: compact ? 22 : 26,
						child: Column(
							children: [
								Padding(
									padding: EdgeInsets.only(top: compact ? 3 : 4),
									child: dot,
								),
								if (!isLast)
									Expanded(
										child: Container(
											width: 2,
											margin: const EdgeInsets.symmetric(vertical: 2),
											color: step.state == MaintenanceTimelineStepState.done
													? const Color(0xFF2E7D32)
													: Colors.grey.shade300,
										),
									),
							],
						),
					),
					Expanded(
						child: Padding(
							padding: EdgeInsets.only(bottom: isLast ? 0 : (compact ? 10 : 14)),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										step.label,
										style: TextStyle(
											fontWeight: step.state == MaintenanceTimelineStepState.current
													? FontWeight.w800
													: FontWeight.w700,
											fontSize: compact ? 12.5 : 14,
											color: step.state == MaintenanceTimelineStepState.pending
													? Colors.grey.shade600
													: Colors.black87,
										),
									),
									if (step.timestamp != null) ...[
										const SizedBox(height: 2),
										Text(
											step.timestamp!,
											style: TextStyle(
												fontSize: compact ? 11 : 12,
												color: Colors.grey.shade600,
											),
										),
									],
									const SizedBox(height: 2),
									Text(
										step.subtitle,
										style: TextStyle(
											fontSize: compact ? 11.5 : 13,
											height: 1.3,
											color: Colors.grey.shade800,
										),
									),
								],
							),
						),
					),
				],
			),
		);
	}
}
