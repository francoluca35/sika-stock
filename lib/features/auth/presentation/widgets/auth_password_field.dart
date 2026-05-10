import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

class AuthPasswordField extends StatefulWidget {
	const AuthPasswordField({
		super.key,
		required this.controller,
		required this.label,
		this.hint,
		this.labelInDecoration = true,
		this.validator,
	});

	final TextEditingController controller;
	final String label;
	final String? hint;

	/// Si es false, solo dibuja el campo; el label va arriba en el padre (mockup login).
	final bool labelInDecoration;

	final FormFieldValidator<String>? validator;

	@override
	State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
	bool _obscure = true;

	@override
	Widget build(BuildContext context) {
		final decoration = InputDecoration(
			labelText: widget.labelInDecoration ? widget.label : null,
			hintText: widget.hint,
			floatingLabelBehavior: widget.labelInDecoration
				? FloatingLabelBehavior.auto
				: FloatingLabelBehavior.never,
			prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
			suffixIcon: IconButton(
				tooltip: _obscure ? "Mostrar" : "Ocultar",
				onPressed: () => setState(() => _obscure = !_obscure),
				icon: Icon(
					_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
					color: Colors.black54,
				),
			),
			filled: true,
			fillColor: AppTokens.whiteSurface,
			contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
			border: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: const BorderSide(color: AppTokens.greyBorder),
			),
			enabledBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: const BorderSide(color: AppTokens.greyBorder),
			),
			focusedBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.35)),
			),
		);

		return TextFormField(
			controller: widget.controller,
			obscureText: _obscure,
			validator: widget.validator,
			decoration: decoration,
		);
	}
}
