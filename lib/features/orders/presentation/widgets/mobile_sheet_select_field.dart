import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/presentation/widgets/auth_field_styles.dart";

/// Duración de apertura/cierre del panel (más lenta, sensación Material / Android).
const Duration kMobileSelectSheetOpen = Duration(milliseconds: 450);
const Duration kMobileSelectSheetClose = Duration(milliseconds: 360);

/// Bottom sheet con transición más lenta (slide desde abajo + velo), compatible con SDKs sin `transitionDuration` en `showModalBottomSheet`.
Future<T?> showSlowModalBottomSheet<T>({
	required BuildContext context,
	required WidgetBuilder builder,
	bool barrierDismissible = true,
}) {
	return Navigator.of(context).push<T>(
		PageRouteBuilder<T>(
			opaque: false,
			barrierDismissible: barrierDismissible,
			barrierColor: Colors.transparent,
			transitionDuration: kMobileSelectSheetOpen,
			reverseTransitionDuration: kMobileSelectSheetClose,
			pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
			transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
				final curved = CurvedAnimation(
					parent: animation,
					curve: Curves.fastOutSlowIn,
					reverseCurve: Curves.easeInCubic,
				);
				return Stack(
					fit: StackFit.expand,
					children: [
						GestureDetector(
							behavior: HitTestBehavior.opaque,
							onTap: barrierDismissible ? () => Navigator.maybePop(ctx) : null,
							child: FadeTransition(
								opacity: curved,
								child: Container(color: Colors.black54),
							),
						),
						Align(
							alignment: Alignment.bottomCenter,
							child: SlideTransition(
								position: Tween<Offset>(
									begin: const Offset(0, 1),
									end: Offset.zero,
								).animate(curved),
								child: child,
							),
						),
					],
				);
			},
		),
	);
}

/// Campo con apariencia de outline que abre un **bottom sheet** con lista (en lugar del menú rápido del `Dropdown`).
class MobileSheetSelectFormField<T> extends FormField<T> {
	MobileSheetSelectFormField({
		super.key,
		required T? value,
		required List<T> options,
		required String Function(T) labelOf,
		required String hintText,
		required IconData prefixIcon,
		String? title,
		super.validator,
		super.onSaved,
		super.enabled = true,
		super.autovalidateMode,
		ValueChanged<T?>? onChanged,
	}) : super(
					initialValue: value,
					builder: (fieldState) {
						return _MobileSheetSelectBody<T>(
							fieldState: fieldState,
							options: options,
							labelOf: labelOf,
							hintText: hintText,
							prefixIcon: prefixIcon,
							title: title,
							enabled: enabled,
							onChanged: onChanged,
						);
					},
				);

	@override
	FormFieldState<T> createState() => _MobileSheetSelectFormFieldState<T>();
}

class _MobileSheetSelectFormFieldState<T> extends FormFieldState<T> {
	@override
	void didUpdateWidget(covariant MobileSheetSelectFormField<T> oldWidget) {
		super.didUpdateWidget(oldWidget);
		final w = widget as MobileSheetSelectFormField<T>;
		final oldW = oldWidget;
		if (w.initialValue != oldW.initialValue) {
			setValue(w.initialValue);
		}
	}
}

class _MobileSheetSelectBody<T> extends StatelessWidget {
	const _MobileSheetSelectBody({
		required this.fieldState,
		required this.options,
		required this.labelOf,
		required this.hintText,
		required this.prefixIcon,
		this.title,
		required this.enabled,
		this.onChanged,
	});

	final FormFieldState<T> fieldState;
	final List<T> options;
	final String Function(T) labelOf;
	final String hintText;
	final IconData prefixIcon;
	final String? title;
	final bool enabled;
	final ValueChanged<T?>? onChanged;

	Future<void> _openSheet(BuildContext context) async {
		if (!enabled) return;

		final chosen = await showSlowModalBottomSheet<T>(
			context: context,
			builder: (ctx) {
				final bottomInset = MediaQuery.paddingOf(ctx).bottom;
				final maxListHeight = MediaQuery.sizeOf(ctx).height * 0.48;
				return Padding(
					padding: EdgeInsets.only(bottom: bottomInset),
					child: ClipRRect(
						borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
						child: Material(
							color: Colors.white,
							child: SafeArea(
								top: false,
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Padding(
											padding: const EdgeInsets.only(top: 12, bottom: 8),
											child: Center(
												child: Container(
													width: 40,
													height: 5,
													decoration: BoxDecoration(
														color: Colors.grey.shade300,
														borderRadius: BorderRadius.circular(40),
													),
												),
											),
										),
										if (title != null)
											Padding(
												padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
												child: Text(
													title!,
													style: const TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 16,
													),
												),
											),
										ConstrainedBox(
											constraints: BoxConstraints(maxHeight: maxListHeight),
											child: ListView(
												shrinkWrap: true,
												children: [
													for (final o in options)
														ListTile(
															contentPadding: const EdgeInsets.symmetric(
																horizontal: 20,
																vertical: 2,
															),
															title: Text(
																labelOf(o),
																style: const TextStyle(fontSize: 16),
															),
															trailing: fieldState.value == o
																? const Icon(
																		Icons.check_circle,
																		color: AppTokens.redAction,
																	)
																: Icon(
																		Icons.circle_outlined,
																		color: Colors.grey.shade400,
																	),
															onTap: () => Navigator.pop(ctx, o),
														),
												],
											),
										),
										const SizedBox(height: 8),
									],
								),
							),
						),
					),
				);
			},
		);

		if (chosen != null) {
			fieldState.didChange(chosen);
			onChanged?.call(chosen);
		}
	}

	@override
	Widget build(BuildContext context) {
		final v = fieldState.value;
		final display = v != null ? labelOf(v as T) : hintText;
		final hasValue = v != null;

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				InkWell(
					onTap: enabled ? () => _openSheet(context) : null,
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					child: InputDecorator(
						decoration: AuthFieldStyles.outline(
							hintText: hintText,
							prefixIcon: prefixIcon,
						).copyWith(
							errorText: fieldState.hasError ? fieldState.errorText : null,
							errorMaxLines: 2,
						),
						isEmpty: !hasValue,
						child: Row(
							children: [
								Expanded(
									child: Text(
										display,
										style: TextStyle(
											fontSize: 14,
											color: hasValue ? Colors.black87 : Colors.grey.shade400,
										),
										overflow: TextOverflow.ellipsis,
									),
								),
								Icon(
									Icons.keyboard_arrow_down_rounded,
									color: enabled ? Colors.black54 : Colors.grey.shade400,
									size: 26,
								),
							],
						),
					),
				),
			],
		);
	}
}
