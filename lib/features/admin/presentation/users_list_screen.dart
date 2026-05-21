import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/domain/profile_row.dart";
import "../application/admin_providers.dart";
import "edit_user_modal.dart";
import "widgets/admin_shell_bottom_bar.dart";

/// Listado de usuarios (ADMIN / SUPERADMIN), alineado al mockup USUARIOS.
class UsersListScreen extends ConsumerStatefulWidget {
	const UsersListScreen({super.key});

	@override
	ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
	static const int _pageSize = 8;

	final TextEditingController _searchController = TextEditingController();
	int _page = 1;

	static final DateFormat _dateFmt = DateFormat("dd/MM/yyyy");

	static const TextStyle _tableHeaderStyle = TextStyle(
		fontWeight: FontWeight.w700,
		fontSize: 11,
		letterSpacing: 0.65,
		color: Color(0xFF475569),
	);

	InputDecoration _searchDecoration() {
		final base = OutlineInputBorder(
			borderRadius: BorderRadius.circular(10),
			borderSide: BorderSide(color: Colors.grey.shade300),
		);
		return InputDecoration(
			hintText: "Buscar usuario...",
			hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
			prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
			filled: true,
			fillColor: AppTokens.surfaceMuted,
			contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
			border: base,
			enabledBorder: base,
			focusedBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(10),
				borderSide: BorderSide(color: Colors.grey.shade700, width: 1.5),
			),
		);
	}

	@override
	void dispose() {
		_searchController.dispose();
		super.dispose();
	}

	void _soon(BuildContext context, String feature) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$feature — próximamente.")),
		);
	}

	List<ProfileRow> _filter(List<ProfileRow> all, String query) {
		final s = query.trim().toLowerCase();
		if (s.isEmpty) return all;
		return all.where((p) {
			final name = (p.nombre ?? "").toLowerCase();
			final email = (p.email ?? "").toLowerCase();
			return name.contains(s) || email.contains(s);
		}).toList();
	}

	int _totalPages(int count) => count == 0 ? 1 : ((count - 1) ~/ _pageSize) + 1;

	String _initials(ProfileRow p) {
		final n = p.nombre?.trim();
		if (n != null && n.isNotEmpty) {
			final parts = n.split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
			if (parts.length >= 2) {
				String firstChar(String x) =>
					x.isEmpty ? "?" : String.fromCharCode(x.runes.first);
				return "${firstChar(parts[0])}${firstChar(parts[1])}".toUpperCase();
			}
			final single = parts.first;
			if (single.runes.length >= 2) {
				final it = single.runes.iterator;
				it.moveNext();
				final a = String.fromCharCode(it.current);
				it.moveNext();
				final b = String.fromCharCode(it.current);
				return "$a$b".toUpperCase();
			}
			return String.fromCharCode(single.runes.first).toUpperCase();
		}
		final e = p.email ?? "?";
		return e.length >= 2 ? e.substring(0, 2).toUpperCase() : "?";
	}

	Widget _roleBadge(AppRole? rol) {
		final text = (rol?.dbValue ?? "—").toUpperCase();
		Color bg;
		Color fg;
		switch (rol) {
			case AppRole.compras:
				bg = AppTokens.roleComprasBg;
				fg = AppTokens.roleComprasFg;
				break;
			case AppRole.panol:
				bg = AppTokens.rolePanolBg;
				fg = AppTokens.rolePanolFg;
				break;
			case AppRole.mantenimiento:
				bg = AppTokens.roleMantenimientoBg;
				fg = AppTokens.roleMantenimientoFg;
				break;
			case AppRole.supervisor:
				bg = AppTokens.roleSupervisorBg;
				fg = AppTokens.roleSupervisorFg;
				break;
			case AppRole.admin:
			case AppRole.superadmin:
				bg = AppTokens.roleAdminBg;
				fg = AppTokens.roleAdminFg;
				break;
			case null:
				bg = Colors.grey.shade400;
				fg = Colors.black87;
				break;
		}
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(8),
				boxShadow: [
					BoxShadow(
						color: bg.withValues(alpha: 0.22),
						blurRadius: 6,
						offset: const Offset(0, 2),
					),
				],
			),
			child: Text(
				text,
				style: TextStyle(
					color: fg,
					fontWeight: FontWeight.w600,
					fontSize: 10.5,
					letterSpacing: 0.45,
				),
			),
		);
	}

	List<Widget> _pageNumberWidgets(int totalPages, int current) {
		if (totalPages <= 7) {
			return List.generate(
				totalPages,
				(i) => _pageChip(i + 1, current),
			);
		}
		final pages = <int>{1, totalPages};
		for (var d = -2; d <= 2; d++) {
			final p = current + d;
			if (p > 1 && p < totalPages) {
				pages.add(p);
			}
		}
		final sorted = pages.toList()..sort();
		final out = <Widget>[];
		int? last;
		for (final p in sorted) {
			if (last != null && p - last > 1) {
				out.add(
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 4),
						child: Text("...", style: TextStyle(color: Colors.grey.shade700)),
					),
				);
			}
			out.add(_pageChip(p, current));
			last = p;
		}
		return out;
	}

	Widget _pageChip(int page, int current) {
		final selected = page == current;
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 2),
			child: InkWell(
				onTap: () => setState(() => _page = page),
				borderRadius: BorderRadius.circular(8),
				child: Container(
					constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
					alignment: Alignment.center,
					decoration: BoxDecoration(
						color: selected ? AppTokens.yellowAccent.withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
						borderRadius: BorderRadius.circular(8),
						border: Border.all(
							color: selected ? const Color(0xFFCA8A04) : Colors.grey.shade300,
						),
					),
					child: Text(
						"$page",
						style: TextStyle(
							fontWeight: selected ? FontWeight.bold : FontWeight.w500,
							color: Colors.black87,
						),
					),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.paddingOf(context).bottom;
		final usersAsync = ref.watch(usersListProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					_UserListYellowHeader(
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
					),
					Expanded(
						child: usersAsync.when(
							data: (all) {
								final filtered = _filter(all, _searchController.text);
								final tp = _totalPages(filtered.length);
								if (_page > tp) {
									WidgetsBinding.instance.addPostFrameCallback((_) {
										if (mounted) setState(() => _page = tp);
									});
								}
								final safePage = math.min(math.max(_page, 1), tp);
								final start = (safePage - 1) * _pageSize;
								final pageItems = filtered.skip(start).take(_pageSize).toList();

								return RefreshIndicator(
									onRefresh: () async {
										ref.invalidate(usersListProvider);
										await ref.read(usersListProvider.future);
									},
									child: SingleChildScrollView(
										physics: const AlwaysScrollableScrollPhysics(),
										padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
										child: Center(
											child: ConstrainedBox(
												constraints: const BoxConstraints(maxWidth: 960),
												child: Container(
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius: BorderRadius.circular(16),
														border: Border.all(color: Colors.grey.shade200),
														boxShadow: [
															BoxShadow(
																color: Colors.black.withValues(alpha: 0.05),
																blurRadius: 20,
																offset: const Offset(0, 8),
															),
														],
													),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.stretch,
														children: [
															Padding(
																padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
																child: LayoutBuilder(
																	builder: (context, c) {
																		final narrow = c.maxWidth < 560;
																		if (narrow) {
																			return Column(
																				crossAxisAlignment:
																					CrossAxisAlignment.stretch,
																				children: [
																					SizedBox(
																						width: double.infinity,
																						child: ElevatedButton.icon(
																							style: ElevatedButton.styleFrom(
																								backgroundColor:
																									AppTokens.redAction,
																								foregroundColor:
																									Colors.white,
																								elevation: 0,
																								shape: RoundedRectangleBorder(
																									borderRadius:
																										BorderRadius.circular(
																											10,
																										),
																								),
																								padding:
																									const EdgeInsets.symmetric(
																										vertical: 14,
																									),
																							),
																							icon: const Icon(
																								Icons.person_add_alt_1,
																								size: 22,
																							),
																							label: const Text(
																								"+ AGREGAR USUARIO",
																								style: TextStyle(
																									fontWeight:
																										FontWeight.bold,
																								),
																							),
																							onPressed: () async {
																								await context.push(
																									"/admin/nuevos-usuarios",
																								);
																								if (context.mounted) {
																									ref.invalidate(
																										usersListProvider,
																									);
																								}
																							},
																						),
																					),
																					const SizedBox(height: 10),
																					TextField(
																						controller: _searchController,
																						decoration: _searchDecoration(),
																						onChanged: (_) => setState(() {
																							_page = 1;
																						}),
																					),
																				],
																			);
																		}
																		return Row(
																			crossAxisAlignment:
																				CrossAxisAlignment.center,
																			children: [
																				ElevatedButton.icon(
																					style: ElevatedButton.styleFrom(
																						backgroundColor:
																							AppTokens.redAction,
																						foregroundColor: Colors.white,
																						elevation: 0,
																						shape: RoundedRectangleBorder(
																							borderRadius:
																								BorderRadius.circular(10),
																						),
																						padding:
																							const EdgeInsets.symmetric(
																								horizontal: 16,
																								vertical: 14,
																							),
																					),
																					icon: const Icon(
																						Icons.person_add_alt_1,
																						size: 22,
																					),
																					label: const Text(
																						"+ AGREGAR USUARIO",
																						style: TextStyle(
																							fontWeight: FontWeight.bold,
																						),
																					),
																					onPressed: () async {
																						await context.push(
																							"/admin/nuevos-usuarios",
																						);
																						if (context.mounted) {
																							ref.invalidate(
																								usersListProvider,
																							);
																						}
																					},
																				),
																				const SizedBox(width: 16),
																				Expanded(
																					child: TextField(
																						controller: _searchController,
																						decoration: _searchDecoration(),
																						onChanged: (_) => setState(() {
																							_page = 1;
																						}),
																					),
																				),
																			],
																		);
																	},
																),
															),
															Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
															if (filtered.isEmpty && all.isNotEmpty)
																Padding(
																	padding: const EdgeInsets.all(24),
																	child: Text(
																		"No hay resultados para la búsqueda.",
																		textAlign: TextAlign.center,
																		style: TextStyle(color: Colors.grey.shade700),
																	),
																)
															else if (all.isEmpty)
																Padding(
																	padding: const EdgeInsets.all(24),
																	child: Text(
																		"No hay usuarios registrados.",
																		textAlign: TextAlign.center,
																		style: TextStyle(color: Colors.grey.shade700),
																	),
																),
															if (pageItems.isNotEmpty)
																LayoutBuilder(
																	builder: (context, tableConstraints) {
																		final cw = tableConstraints.maxWidth;
																		final tableWidth = cw.isFinite
																			? math.max(720.0, cw)
																			: math.max(
																					720.0,
																					MediaQuery.sizeOf(context).width - 48,
																				);
																		return SingleChildScrollView(
																			scrollDirection: Axis.horizontal,
																			child: SizedBox(
																				width: tableWidth,
																				child: Column(
																					crossAxisAlignment:
																						CrossAxisAlignment.stretch,
																					children: [
																						Container(
																							decoration: BoxDecoration(
																								color: AppTokens.surfaceMuted,
																								border: Border(
																									bottom: BorderSide(
																										color:
																											Colors.grey.shade300,
																									),
																								),
																							),
																							padding: const EdgeInsets.symmetric(
																								vertical: 14,
																								horizontal: 12,
																							),
																							child: const Row(
																								children: [
																									SizedBox(width: 44),
																									Expanded(
																										flex: 2,
																										child: Text(
																											"NOMBRE",
																											style:
																												_tableHeaderStyle,
																										),
																									),
																									Expanded(
																										flex: 2,
																										child: Text(
																											"EMAIL",
																											style:
																												_tableHeaderStyle,
																										),
																									),
																									Expanded(
																										flex: 1,
																										child: Text(
																											"ROL",
																											style:
																												_tableHeaderStyle,
																										),
																									),
																									Expanded(
																										flex: 1,
																										child: Text(
																											"FECHA DE CREACIÓN",
																											style:
																												_tableHeaderStyle,
																										),
																									),
																									SizedBox(width: 40),
																								],
																							),
																						),
																						for (var i = 0; i < pageItems.length; i++)
																							_UserTableRow(
																								striped: i.isOdd,
																								profile: pageItems[i],
																								initials: _initials(pageItems[i]),
																								roleBadge: _roleBadge(
																									pageItems[i].rol,
																								),
																								dateLabel: pageItems[i].createdAt !=
																										null
																									? _dateFmt.format(
																										pageItems[i].createdAt!.toLocal(),
																									)
																									: "—",
																								onMenu: (ctx) {
																									showModalBottomSheet<void>(
																										context: ctx,
																										builder: (c) => SafeArea(
																											child: Column(
																												mainAxisSize:
																													MainAxisSize.min,
																												children: [
																													ListTile(
																														leading: const Icon(
																															Icons.edit_outlined,
																														),
																														title: const Text(
																															"Editar",
																														),
																														onTap: () {
																															Navigator.pop(
																																c,
																															);
																															showEditUserModal(
																																context,
																																pageItems[i],
																															);
																														},
																													),
																													ListTile(
																														leading: Icon(
																															Icons.delete_outline,
																															color: Colors.red.shade700,
																														),
																														title: Text(
																															"Eliminar",
																															style: TextStyle(
																																color: Colors.red.shade700,
																															),
																														),
																														onTap: () {
																															Navigator.pop(
																																c,
																															);
																															_soon(
																																ctx,
																																"Eliminar usuario",
																															);
																														},
																													),
																												],
																											),
																										),
																									);
																								},
																							),
																					],
																				),
																			),
																		);
																	},
																),
															const SizedBox(height: 12),
															if (filtered.isNotEmpty)
																Padding(
																	padding: const EdgeInsets.only(bottom: 12),
																	child: SingleChildScrollView(
																		scrollDirection: Axis.horizontal,
																		child: Row(
																			mainAxisAlignment: MainAxisAlignment.center,
																			children: [
																				IconButton(
																					icon: const Icon(Icons.chevron_left),
																					onPressed: safePage > 1
																						? () => setState(() => _page--)
																						: null,
																				),
																				..._pageNumberWidgets(tp, safePage),
																				IconButton(
																					icon: const Icon(Icons.chevron_right),
																					onPressed: safePage < tp
																						? () => setState(() => _page++)
																						: null,
																				),
																			],
																		),
																	),
																),
														],
													),
												),
											),
										),
									),
								);
							},
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Text("No se pudo cargar la lista: $e"),
											const SizedBox(height: 16),
											FilledButton(
												onPressed: () =>
													ref.invalidate(usersListProvider),
												child: const Text("Reintentar"),
											),
										],
									),
								),
							),
						),
					),
					AdminShellBottomBar(
						bottomPadding: bottomInset,
						onInicio: () => context.go("/home"),
						onOrdenCompra: () => _soon(context, "Crear orden de compra"),
						onConfig: () => context.push("/configuracion"),
					),
				],
			),
		);
	}
}

class _UserListYellowHeader extends StatelessWidget {
	const _UserListYellowHeader({required this.onBack});

	final VoidCallback onBack;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: AppTokens.yellowHeader,
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 10,
						offset: const Offset(0, 3),
					),
				],
			),
			child: SafeArea(
				bottom: false,
				child: SizedBox(
					height: 56,
					child: Stack(
						alignment: Alignment.center,
						children: [
							Align(
								alignment: Alignment.centerLeft,
								child: IconButton(
									icon: const Icon(Icons.arrow_back, color: Colors.black87),
									onPressed: onBack,
								),
							),
							const Text(
								"USUARIOS",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 18,
									letterSpacing: 1,
									color: Colors.black87,
								),
							),
						],
					),
				),
			),
		);
	}
}

class _UserTableRow extends StatelessWidget {
	const _UserTableRow({
		required this.striped,
		required this.profile,
		required this.initials,
		required this.roleBadge,
		required this.dateLabel,
		required this.onMenu,
	});

	final bool striped;
	final ProfileRow profile;
	final String initials;
	final Widget roleBadge;
	final String dateLabel;
	final void Function(BuildContext context) onMenu;

	@override
	Widget build(BuildContext context) {
		final name = profile.nombre?.trim().isNotEmpty == true
			? profile.nombre!
			: (profile.usuario ?? profile.email ?? "—");
		return ColoredBox(
			color: striped ? AppTokens.surfaceMuted : Colors.white,
			child: Padding(
				padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.center,
					children: [
						Container(
							decoration: BoxDecoration(
								shape: BoxShape.circle,
								border: Border.all(color: Colors.white, width: 2),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withValues(alpha: 0.07),
										blurRadius: 6,
										offset: const Offset(0, 2),
									),
								],
							),
							child: CircleAvatar(
								radius: 18,
								backgroundColor: const Color(0xFFE2E8F0),
								child: Text(
									initials,
									style: const TextStyle(
										color: Color(0xFF334155),
										fontWeight: FontWeight.w700,
										fontSize: 12,
									),
								),
							),
						),
						const SizedBox(width: 10),
						Expanded(
							flex: 2,
							child: Text(
								name,
								style: const TextStyle(
									fontWeight: FontWeight.w600,
									color: Color(0xFF0F172A),
									fontSize: 14,
								),
								overflow: TextOverflow.ellipsis,
							),
						),
						Expanded(
							flex: 2,
							child: Text(
								profile.email ?? "—",
								overflow: TextOverflow.ellipsis,
								style: TextStyle(
									fontSize: 13,
									color: Colors.grey.shade700,
								),
							),
						),
						Expanded(
							flex: 1,
							child: Align(
								alignment: Alignment.centerLeft,
								child: roleBadge,
							),
						),
						Expanded(
							flex: 1,
							child: Text(
								dateLabel,
								style: TextStyle(
									fontSize: 13,
									color: Colors.grey.shade600,
								),
							),
						),
						IconButton(
							icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
							onPressed: () => onMenu(context),
							padding: EdgeInsets.zero,
							constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
						),
					],
				),
			),
		);
	}
}
