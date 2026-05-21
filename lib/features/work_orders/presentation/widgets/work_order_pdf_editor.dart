import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image/image.dart" as img;
import "package:pdfx/pdfx.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../domain/work_order_pdf_annotation.dart";
import "work_order_signature_field.dart";

enum _EditTool { select, text, check, signature }

/// Editor a pantalla completa sobre la plantilla PDF oficial.
class WorkOrderPdfEditor extends StatefulWidget {
	const WorkOrderPdfEditor({
		super.key,
		required this.pdfBytes,
		this.onAnnotationsChanged,
	});

	final Uint8List pdfBytes;
	final ValueChanged<List<WorkOrderPdfAnnotation>>? onAnnotationsChanged;

	@override
	State<WorkOrderPdfEditor> createState() => WorkOrderPdfEditorState();
}

class WorkOrderPdfEditorState extends State<WorkOrderPdfEditor> {
	PdfDocument? _document;
	int _pageIndex = 0;
	int _pageCount = 0;
	Uint8List? _pageImage;
	int _imgW = 1;
	int _imgH = 1;
	bool _loadingPage = true;
	_EditTool _tool = _EditTool.text;
	final List<WorkOrderPdfAnnotation> _annotations = [];
	Uint8List? _signaturePng;
	String? _selectedId;
	String? _editingTextId;
	int _idSeq = 0;
	final _inlineTextCtrl = TextEditingController();
	final _inlineFocus = FocusNode();

	List<WorkOrderPdfAnnotation> get annotations => List.unmodifiable(_annotations);
	Uint8List? get signaturePng => _signaturePng;

	@override
	void initState() {
		super.initState();
		_openDoc();
	}

	@override
	void dispose() {
		_document?.close();
		_inlineTextCtrl.dispose();
		_inlineFocus.dispose();
		super.dispose();
	}

	Future<void> _openDoc() async {
		try {
			final doc = await PdfDocument.openData(widget.pdfBytes);
			if (!mounted) {
				await doc.close();
				return;
			}
			setState(() {
				_document = doc;
				_pageCount = doc.pagesCount;
			});
			await _loadPageImage(0);
		} catch (_) {
			if (mounted) setState(() => _loadingPage = false);
		}
	}

	Future<void> _loadPageImage(int index) async {
		final doc = _document;
		if (doc == null) return;
		setState(() {
			_loadingPage = true;
			_editingTextId = null;
		});
		try {
			final page = await doc.getPage(index + 1);
			final dpr = MediaQuery.devicePixelRatioOf(context);
			final screenW = MediaQuery.sizeOf(context).width;
			final targetW = (screenW * dpr * 2).clamp(1200.0, 4096.0);
			final scale = targetW / page.width;
			final rendered = await page.render(
				width: targetW,
				height: page.height * scale,
				format: PdfPageImageFormat.png,
				backgroundColor: "#FFFFFF",
			);
			await page.close();
			if (!mounted || rendered == null) return;
			final decoded = img.decodePng(rendered.bytes);
			setState(() {
				_pageIndex = index;
				_pageImage = rendered.bytes;
				_imgW = decoded?.width ?? targetW.round();
				_imgH = decoded?.height ?? (page.height * scale).round();
				_loadingPage = false;
			});
		} catch (_) {
			if (mounted) setState(() => _loadingPage = false);
		}
	}

	void _notify() {
		widget.onAnnotationsChanged?.call(_annotations);
	}

	void _addAnnotation(WorkOrderPdfAnnotation a) {
		setState(() {
			_annotations.add(a);
			_selectedId = a.id;
		});
		_notify();
	}

	void _updateAnnotation(WorkOrderPdfAnnotation a) {
		final i = _annotations.indexWhere((e) => e.id == a.id);
		if (i < 0) return;
		setState(() => _annotations[i] = a);
		_notify();
	}

	void _removeSelected() {
		if (_selectedId == null) return;
		setState(() {
			_annotations.removeWhere((e) => e.id == _selectedId);
			if (_editingTextId == _selectedId) _editingTextId = null;
		});
		_selectedId = null;
		_notify();
	}

	String _newId() => "ann_${_idSeq++}";

	void _startInlineText(double nx, double ny) {
		final id = _newId();
		_addAnnotation(
			WorkOrderPdfAnnotation(
				id: id,
				pageIndex: _pageIndex,
				type: "text",
				x: nx,
				y: ny,
				text: "",
				width: 0.28,
				height: 0.025,
			),
		);
		_inlineTextCtrl.clear();
		setState(() => _editingTextId = id);
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted) _inlineFocus.requestFocus();
		});
	}

	void _commitInlineText() {
		final id = _editingTextId;
		if (id == null) return;
		final i = _annotations.indexWhere((e) => e.id == id);
		if (i < 0) return;
		final text = _inlineTextCtrl.text.trim();
		if (text.isEmpty) {
			setState(() {
				_annotations.removeAt(i);
				_editingTextId = null;
			});
		} else {
			_updateAnnotation(_annotations[i].copyWith(text: text));
			setState(() => _editingTextId = null);
		}
		_notify();
	}

	void _onCanvasTap(Offset local, Size displaySize) {
		if (displaySize.width <= 0 || displaySize.height <= 0) return;
		final nx = (local.dx / displaySize.width).clamp(0.0, 0.95);
		final ny = (local.dy / displaySize.height).clamp(0.0, 0.97);

		switch (_tool) {
			case _EditTool.text:
				if (_editingTextId != null) {
					_commitInlineText();
				}
				_startInlineText(nx, ny);
			case _EditTool.check:
				_addAnnotation(
					WorkOrderPdfAnnotation(
						id: _newId(),
						pageIndex: _pageIndex,
						type: "check",
						x: nx,
						y: ny,
						width: 0.025,
						height: 0.025,
					),
				);
			case _EditTool.signature:
				if (_signaturePng == null || _signaturePng!.isEmpty) {
					_openSignatureSheet();
					return;
				}
				_addAnnotation(
					WorkOrderPdfAnnotation(
						id: _newId(),
						pageIndex: _pageIndex,
						type: "signature",
						x: nx,
						y: ny,
						width: 0.2,
						height: 0.06,
					),
				);
			case _EditTool.select:
				setState(() {
					_selectedId = null;
					_editingTextId = null;
				});
		}
	}

	Future<void> _openSignatureSheet() async {
		await showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			showDragHandle: true,
			builder: (ctx) => Padding(
				padding: EdgeInsets.only(
					left: 16,
					right: 16,
					top: 8,
					bottom: MediaQuery.paddingOf(ctx).bottom + 16,
				),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						const Text(
							"Firma",
							style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
						),
						const SizedBox(height: 8),
						WorkOrderSignatureField(
							onChanged: (b) => setState(() => _signaturePng = b),
						),
						FilledButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text("Listo"),
						),
					],
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Stack(
			fit: StackFit.expand,
			children: [
				ColoredBox(
					color: Colors.grey.shade300,
					child: _loadingPage || _pageImage == null
							? const Center(child: CircularProgressIndicator())
							: _FullPagePdfCanvas(
									pageImage: _pageImage!,
									imgW: _imgW,
									imgH: _imgH,
									annotations: _annotations.where((a) => a.pageIndex == _pageIndex).toList(),
									selectedId: _selectedId,
									editingTextId: _editingTextId,
									inlineTextCtrl: _inlineTextCtrl,
									inlineFocus: _inlineFocus,
									signaturePng: _signaturePng,
									onTapCanvas: _onCanvasTap,
									onSelect: (id) => setState(() => _selectedId = id),
									onAnnotationChanged: _updateAnnotation,
									onInlineCommit: _commitInlineText,
								),
				),
				Positioned(
					top: 0,
					left: 0,
					right: 0,
					child: Material(
						elevation: 3,
						color: Colors.white.withValues(alpha: 0.96),
						child: SafeArea(
							bottom: false,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									SingleChildScrollView(
										scrollDirection: Axis.horizontal,
										padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
										child: Row(
											children: [
												_ToolChip(
													label: "Escribir",
													icon: Icons.edit_outlined,
													selected: _tool == _EditTool.text,
													onTap: () => setState(() => _tool = _EditTool.text),
												),
												_ToolChip(
													label: "Tilde",
													icon: Icons.check,
													selected: _tool == _EditTool.check,
													onTap: () => setState(() => _tool = _EditTool.check),
												),
												_ToolChip(
													label: "Firma",
													icon: Icons.draw_outlined,
													selected: _tool == _EditTool.signature,
													onTap: () {
														setState(() => _tool = _EditTool.signature);
														_openSignatureSheet();
													},
												),
												_ToolChip(
													label: "Mover",
													icon: Icons.pan_tool_alt_outlined,
													selected: _tool == _EditTool.select,
													onTap: () => setState(() => _tool = _EditTool.select),
												),
												IconButton(
													tooltip: "Eliminar",
													onPressed: _selectedId == null ? null : _removeSelected,
													icon: const Icon(Icons.delete_outline, size: 22),
												),
												if (_pageCount > 1) ...[
													const VerticalDivider(width: 8),
													IconButton(
														onPressed: _pageIndex > 0
																? () => _loadPageImage(_pageIndex - 1)
																: null,
														icon: const Icon(Icons.chevron_left),
														visualDensity: VisualDensity.compact,
													),
													Text(
														"${_pageIndex + 1}/$_pageCount",
														style: const TextStyle(fontWeight: FontWeight.w700),
													),
													IconButton(
														onPressed: _pageIndex < _pageCount - 1
																? () => _loadPageImage(_pageIndex + 1)
																: null,
														icon: const Icon(Icons.chevron_right),
														visualDensity: VisualDensity.compact,
													),
												],
											],
										),
									),
									const Padding(
										padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
										child: Text(
											"Tocá cada renglón para escribir. Pellizcá para acercar.",
											style: TextStyle(fontSize: 11, color: Colors.black54),
										),
									),
								],
							),
						),
					),
				),
			],
		);
	}
}

/// PDF ocupa todo el ancho de pantalla; alto proporcional; scroll + zoom.
class _FullPagePdfCanvas extends StatelessWidget {
	const _FullPagePdfCanvas({
		required this.pageImage,
		required this.imgW,
		required this.imgH,
		required this.annotations,
		required this.selectedId,
		required this.editingTextId,
		required this.inlineTextCtrl,
		required this.inlineFocus,
		required this.signaturePng,
		required this.onTapCanvas,
		required this.onSelect,
		required this.onAnnotationChanged,
		required this.onInlineCommit,
	});

	final Uint8List pageImage;
	final int imgW;
	final int imgH;
	final List<WorkOrderPdfAnnotation> annotations;
	final String? selectedId;
	final String? editingTextId;
	final TextEditingController inlineTextCtrl;
	final FocusNode inlineFocus;
	final Uint8List? signaturePng;
	final void Function(Offset local, Size displaySize) onTapCanvas;
	final ValueChanged<String> onSelect;
	final ValueChanged<WorkOrderPdfAnnotation> onAnnotationChanged;
	final VoidCallback onInlineCommit;

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final aspect = imgH > 0 ? imgW / imgH : 1.0;
				final pageW = constraints.maxWidth;
				final pageH = pageW / aspect;

				const toolbarH = 72.0;
				return Padding(
					padding: const EdgeInsets.only(top: toolbarH),
					child: InteractiveViewer(
						boundaryMargin: const EdgeInsets.all(24),
						minScale: 0.6,
						maxScale: 5,
						child: SizedBox(
							width: pageW,
							height: pageH,
							child: _PageStack(
								pageImage: pageImage,
								displaySize: Size(pageW, pageH),
								annotations: annotations,
								selectedId: selectedId,
								editingTextId: editingTextId,
								inlineTextCtrl: inlineTextCtrl,
								inlineFocus: inlineFocus,
								signaturePng: signaturePng,
								onTapCanvas: onTapCanvas,
								onSelect: onSelect,
								onAnnotationChanged: onAnnotationChanged,
								onInlineCommit: onInlineCommit,
							),
						),
					),
				);
			},
		);
	}
}

class _PageStack extends StatelessWidget {
	const _PageStack({
		required this.pageImage,
		required this.displaySize,
		required this.annotations,
		required this.selectedId,
		required this.editingTextId,
		required this.inlineTextCtrl,
		required this.inlineFocus,
		required this.signaturePng,
		required this.onTapCanvas,
		required this.onSelect,
		required this.onAnnotationChanged,
		required this.onInlineCommit,
	});

	final Uint8List pageImage;
	final Size displaySize;
	final List<WorkOrderPdfAnnotation> annotations;
	final String? selectedId;
	final String? editingTextId;
	final TextEditingController inlineTextCtrl;
	final FocusNode inlineFocus;
	final Uint8List? signaturePng;
	final void Function(Offset local, Size displaySize) onTapCanvas;
	final ValueChanged<String> onSelect;
	final ValueChanged<WorkOrderPdfAnnotation> onAnnotationChanged;
	final VoidCallback onInlineCommit;

	@override
	Widget build(BuildContext context) {
		final fontScale = displaySize.width / 595;

		return GestureDetector(
			behavior: HitTestBehavior.translucent,
			onTapUp: (d) {
				final box = context.findRenderObject() as RenderBox?;
				if (box == null) return;
				onTapCanvas(box.globalToLocal(d.globalPosition), displaySize);
			},
			child: Stack(
				fit: StackFit.expand,
				children: [
					Image.memory(pageImage, width: displaySize.width, height: displaySize.height, fit: BoxFit.fill),
					...annotations.map((a) {
						if (a.id == editingTextId) {
							return _InlineTextField(
								annotation: a,
								displaySize: displaySize,
								controller: inlineTextCtrl,
								focusNode: inlineFocus,
								fontSize: 13 * fontScale,
								onCommit: onInlineCommit,
							);
						}
						return _AnnotationLayer(
							annotation: a,
							selected: a.id == selectedId,
							displaySize: displaySize,
							fontScale: fontScale,
							signaturePng: signaturePng,
							onSelect: () => onSelect(a.id),
							onChanged: onAnnotationChanged,
						);
					}),
				],
			),
		);
	}
}

class _InlineTextField extends StatelessWidget {
	const _InlineTextField({
		required this.annotation,
		required this.displaySize,
		required this.controller,
		required this.focusNode,
		required this.fontSize,
		required this.onCommit,
	});

	final WorkOrderPdfAnnotation annotation;
	final Size displaySize;
	final TextEditingController controller;
	final FocusNode focusNode;
	final double fontSize;
	final VoidCallback onCommit;

	@override
	Widget build(BuildContext context) {
		return Positioned(
			left: annotation.x * displaySize.width,
			top: annotation.y * displaySize.height,
			width: annotation.width * displaySize.width,
			child: Material(
				color: Colors.transparent,
				child: TextField(
					controller: controller,
					focusNode: focusNode,
					autofocus: true,
					style: TextStyle(
						fontSize: fontSize.clamp(10, 22),
						fontWeight: FontWeight.w600,
						color: Colors.black,
						height: 1.1,
					),
					decoration: const InputDecoration(
						isDense: true,
						border: InputBorder.none,
						contentPadding: EdgeInsets.zero,
						filled: false,
					),
					onSubmitted: (_) => onCommit(),
					onTapOutside: (_) => onCommit(),
				),
			),
		);
	}
}

class _ToolChip extends StatelessWidget {
	const _ToolChip({
		required this.label,
		required this.icon,
		required this.selected,
		required this.onTap,
	});

	final String label;
	final IconData icon;
	final bool selected;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(right: 4),
			child: FilterChip(
				label: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(icon, size: 16),
						const SizedBox(width: 4),
						Text(label, style: const TextStyle(fontSize: 12)),
					],
				),
				selected: selected,
				onSelected: (_) => onTap(),
				selectedColor: AppTokens.yellowHeader,
				padding: const EdgeInsets.symmetric(horizontal: 4),
				visualDensity: VisualDensity.compact,
			),
		);
	}
}

class _AnnotationLayer extends StatelessWidget {
	const _AnnotationLayer({
		required this.annotation,
		required this.selected,
		required this.displaySize,
		required this.fontScale,
		required this.signaturePng,
		required this.onSelect,
		required this.onChanged,
	});

	final WorkOrderPdfAnnotation annotation;
	final bool selected;
	final Size displaySize;
	final double fontScale;
	final Uint8List? signaturePng;
	final VoidCallback onSelect;
	final ValueChanged<WorkOrderPdfAnnotation> onChanged;

	@override
	Widget build(BuildContext context) {
		final left = annotation.x * displaySize.width;
		final top = annotation.y * displaySize.height;

		switch (annotation.type) {
			case "check":
				return Positioned(
					left: left - 2,
					top: top - 4,
					child: GestureDetector(
						onTap: onSelect,
						child: Text(
							"X",
							style: TextStyle(
								fontSize: (22 * fontScale).clamp(14, 32),
								fontWeight: FontWeight.bold,
								color: Colors.green.shade800,
							),
						),
					),
				);
			case "signature":
				return Positioned(
					left: left,
					top: top,
					width: annotation.width * displaySize.width,
					height: annotation.height * displaySize.height,
					child: GestureDetector(
						onTap: onSelect,
						child: signaturePng != null && signaturePng!.isNotEmpty
								? Image.memory(signaturePng!, fit: BoxFit.contain)
								: const SizedBox.shrink(),
					),
				);
			default:
				final text = annotation.text ?? "";
				if (text.isEmpty) return const SizedBox.shrink();
				return Positioned(
					left: left,
					top: top,
					child: GestureDetector(
						onTap: onSelect,
						onPanUpdate: (d) {
							onChanged(
								annotation.copyWith(
									x: (annotation.x + d.delta.dx / displaySize.width).clamp(0.0, 0.95),
									y: (annotation.y + d.delta.dy / displaySize.height).clamp(0.0, 0.97),
								),
							);
						},
						child: Text(
							text,
							style: TextStyle(
								fontSize: (13 * fontScale).clamp(10, 22),
								fontWeight: FontWeight.w600,
								color: Colors.black,
								height: 1.1,
								backgroundColor: selected ? Colors.yellow.shade100 : null,
							),
						),
					),
				);
		}
	}
}
