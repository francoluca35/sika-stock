# Plan de desarrollo — Sistema Pañol (Flutter + Supabase)

Documento maestro con **todos los pasos** para construir la aplicación (Web · Android · iOS), alineado al flujo del PDF de arquitectura, los mockups de roles y el rol **SUPERADMIN** con modelo **unidireccional** (sin escalado desde roles inferiores).

---

## Por dónde empezar (tenés la BD en Supabase ya)

Con la base **ya creada en Supabase**, no arrancás por esquema SQL ni migraciones iniciales de tablas. Empezás por **conectar el cliente Flutter al proyecto existente** y **validar Auth + rol desde `profiles`**.

**Orden de arranque recomendado:**

1. **Verificar en Supabase** que existan: `profiles` (o equivalente) con columna de rol, tablas core (`products`, `requests`, `purchase_orders`, etc.) y **RLS** activo con políticas coherentes para cada rol.
2. **Crear el proyecto Flutter** en este repo (o abrir el repo donde vivirá la app) y agregar dependencias: `supabase_flutter`, `flutter_riverpod`, `go_router`.
3. **Variables de entorno**: URL del proyecto y `anon` key (nunca la service role en la app).
4. **Implementar login** + lectura de **rol** tras sesión + **GoRouter** con redirección por rol (incl. `SUPERADMIN`).
5. **Una pantalla vacía por rol** (“shell” con navegación) para comprobar que el flujo de rutas es correcto antes de llenar features.

A partir de ahí seguí las **fases numeradas** más abajo en orden.

---

## Roles del sistema

| Rol | Uso principal |
|-----|----------------|
| **MANTENIMIENTO** | Crear pedidos, historial, seguimiento propio. |
| **SUPERVISOR** | Revisar/aprobar/rechazar pedidos, vista de stock resumida. |
| **PANOL** | Stock, reservas, analizar disponibilidad, derivar a compras si falta stock. |
| **COMPRAS** | Órdenes de compra, estados, proveedor, recepción en depósito. |
| **SUPERADMIN** | Administración global (usuarios/config según definan políticas); **no escalable** desde otros roles vía app. |
| **ADMIN** *(opcional)* | Backoffice sin mismo alcance que SUPERADMIN si querés separar. |

**SUPERADMIN unidireccional:** solo procesos controlados (SQL migración, Dashboard Supabase o función con **service role**) asignan `SUPERADMIN`. La app cliente no debe permitir que un usuario inferior cambie `rol` hacia `SUPERADMIN`.

---

## Stack recomendado

- Flutter 3.x  
- Supabase (Auth, Postgres + RLS, Realtime, Storage, Edge Functions si hace falta)  
- Riverpod 2  
- GoRouter  
- Paquetes según necesidad: `fl_chart`, `flutter_local_notifications`, `pdf`, export Excel, etc.

---

## Fase 0 — Comprobaciones sobre la BD existente

Objetivo: no duplicar trabajo ni romper RLS cuando conecte la app.

- [ ] Confirmar enums o equivalentes para estados de `requests` y compras.  
- [ ] Confirmar tabla `profiles` ligada a `auth.users` (`id` = UUID del usuario).  
- [ ] Revisar políticas RLS: cada rol solo ve/edita lo que le corresponde; **SUPERADMIN** con bypass explícito donde aplique.  
- [ ] Función tipo `get_my_role()` o `is_superadmin()` si ya existe — reutilizarla en políticas.  
- [ ] Realtime: decidir qué tablas publicar para suscripciones.  

Si falta algo crítico, documentarlo y **completarlo en Supabase antes** de cargar mucha lógica en Flutter.

---

## Inicialización Flutter (repo `sika-stock`)

Ya existe un esqueleto con `pubspec.yaml`, `lib/main.dart` y tema en `lib/core/theme/` (tokens inspirados en los mockups).

**En tu máquina** (con Flutter instalado y en el `PATH`), desde la raíz del repo:

```bash
flutter pub get
flutter create . --project-name sika_stock --org com.sika.stock --platforms=web,android,ios
```

Esto **completa** carpetas `web/`, `android/`, `ios/` y configuración nativa sin pisar el `pubspec` si ya está creado (revisá el diff).

Comprobación rápida:

```bash
flutter run -d chrome
flutter devices
flutter run -d <id_android_o_ios>
```

### ¿Tailwind?

**No se usa Tailwind CSS en Flutter** (no hay clases `bg-yellow-500` en HTML: la UI son widgets). Equivalentes:

- **`lib/core/theme/app_tokens.dart`**: colores y radios como en un `tailwind.config`.
- Opcional: paquete **tailwind_colors** en pub.dev solo aporta **colores** de la paleta Tailwind como `Color` en Dart.

---

## Fase 1 — Proyecto Flutter y núcleo

- [x] Crear proyecto Flutter multiplataforma en el repo (esqueleto + completar con `flutter create`).
- [x] Dependencias en `pubspec.yaml`: `supabase_flutter`, `flutter_riverpod`, `go_router`, `intl`, `flutter_dotenv`, `fl_chart`, `pdf`, `printing`, `excel`, `flutter_local_notifications`, `qr_flutter`, `mobile_scanner`. Variables locales: copiar `.env.example` → `.env` (no commitear `.env`; el asset `.env` debe existir para compilar).
- [ ] Estructura **feature-first**: `lib/core`, `lib/features`, `lib/shared`.
- [x] `Env.load()` + `Supabase.initialize` en `main.dart`; helpers en `lib/core/config/env.dart` y `lib/core/supabase/supabase_bootstrap.dart`.
- [ ] Config por entorno (dev/staging/prod): URLs y keys vía `--dart-define` o `.env` según convención del equipo.  
- [ ] Tema UI alineado a mockups (amarillo / rojo / negro / blanco).  

---

## Fase 2 — Autenticación y rutas por rol

- [ ] Pantalla de login (email/password o magic link según Supabase).  
- [ ] Tras login: fetch de `profiles` y cache del **rol** en Riverpod.  
- [ ] **GoRouter**: rutas anidadas por rol (`/mantenimiento/...`, `/supervisor/...`, `/panol/...`, `/compras/...`, `/superadmin/...`).  
- [ ] Guards: si la ruta no corresponde al rol → redirect al home del rol o login.  
- [ ] Logout limpiando sesión y estado.  

---

## Fase 3 — Features por rol (orden sugerido)

### 3.1 Pañol — Stock

- [ ] Repositorio `products` / stock: CRUD permitido por políticas.  
- [ ] Pantalla tabla: código, nombre, uso, cantidad, estado OK / BAJO STOCK.  
- [ ] Acciones: editar, añadir, eliminar, **utilizar** (descuento de stock).  

### 3.2 Mantenimiento — Pedidos

- [ ] Crear solicitud (producto, cantidad, prioridad, observación, destino si aplica).  
- [ ] Listados e historial (tabs si coincide con mockup).  
- [ ] Estados visibles según RLS (solo los propios salvo otros roles).  

### 3.3 Supervisor — Cola de pedidos

- [ ] Lista de pedidos pendientes / en revisión.  
- [ ] Acciones: aprobar, rechazar, ajustar prioridad (según estados del backend).  
- [ ] Panel lateral o vista resumida de stock (solo lectura o según diseño).  

### 3.4 Pañol — Workflow pedidos

- [ ] Analizar stock frente al pedido aprobado.  
- [ ] Con stock: reservar → estados hacia listo retiro / entrega según modelo.  
- [ ] Sin stock: crear o vincular flujo hacia **Compras** (`purchase_orders` o tabla equivalente).  

### 3.5 Compras — Gerente

- [ ] Bandeja de órdenes de compra por estado.  
- [ ] Detalle: proveedor, fechas, vínculo a solicitud origen.  
- [ ] Transiciones de estado con notificaciones (Realtime + opcional push).  

### 3.6 SUPERADMIN

- [ ] Pantallas acordadas (usuarios, auditoría global, configuración).  
- [ ] Operaciones sensibles de rol **solo** con backend seguro (RLS + opcional Edge Function con service role); nunca confiar solo en el cliente.  

---

## Fase 4 — Tiempo real y notificaciones

- [ ] Streams Riverpod desde repos (`stream` / Realtime Supabase).  
- [ ] `flutter_local_notifications` en Android/iOS donde aplique.  
- [ ] Badge / pantalla notificaciones (Supervisor y otros roles según mockups).  

---

## Fase 5 — Auditoría y reportes

- [ ] Registrar acciones importantes en `audit_log` (si la tabla existe).  
- [ ] Dashboard con `fl_chart` (stock crítico, tiempos, etc.).  
- [ ] Export PDF / Excel si están en alcance.  

---

## Fase 6 — Calidad y deploy

- [ ] Pruebas manuales por rol (cuentas de test en Supabase).  
- [ ] Verificación RLS: intentar violar permisos desde la app con usuario de menor rol.  
- [ ] `flutter build web`, builds móviles, hosting web (Vercel/Netlify/etc.) y proyecto Supabase de producción con keys de prod.  

---

## Extras (cuando el núcleo esté estable)

- Código QR para retiro (`qr_flutter`, `mobile_scanner`).  
- Internacionalización (`flutter_localizations`).  
- Integración SAP u otros vía Edge Functions y webhooks.  

---

## Dependencias entre fases (resumen)

```text
Fase 0 (BD verificada) → Fase 1 (Flutter core) → Fase 2 (Auth + router)
    → Fase 3 (features por rol, puede paralelizarse por persona si RLS está listo)
    → Fase 4 (Realtime) → Fase 5 (auditoría/reportes) → Fase 6 (deploy)
```

---

## Checklist rápido “¿estoy en el camino?”

- Conectás la app a Supabase sin errores de red ni CORS (web).  
- Login funciona y el **rol** se refleja en la UI correcta.  
- Un usuario de prueba **no** puede ver datos de otro rol ni escalarse a SUPERADMIN.  
- Los flujos de pedido avanzan estado según las reglas de negocio acordadas.  

---

*Última actualización: generado como guía de trabajo para el repo sika-stock; ajustá nombres de tablas/columnas a tu esquema real en Supabase.*
