# Halim SaaS API (Laravel + MySQL)

Local-first multi-tenant API for the Flutter POS app. **Do not deploy or push to production until the moving phase is approved.**

## Requirements

- PHP 8.2+
- Composer
- MySQL 8+
- Database `halim_saas` (created locally)

## Setup

```bash
cd backend
cp .env.example .env   # if needed; APP_KEY should already exist
# Ensure .env has:
#   DB_CONNECTION=mysql
#   DB_DATABASE=halim_saas
#   DB_USERNAME=root
#   DB_PASSWORD=

php artisan migrate:fresh
php artisan migrate:from-json ../frontend/data --demo-tenant2
php artisan storage:link
php artisan serve --host=0.0.0.0 --port=8000
```

API root: `http://<PC_LAN_IP>:8000/api`

Find your Mac Wi‑Fi IP:

```bash
ipconfig getifaddr en0
```

## Local test accounts (after migrator)

| Account | Username | Password | Shop |
|---------|----------|----------|------|
| Migrated admin | `admin` | `admin123` | Shop 1 (Haslim) |
| Demo tenant 2 | `owner2` | `password` | Shop 2 (isolation test) |

## API surface (Flutter contract)

| Area | Endpoints |
|------|-----------|
| Auth | `POST /login` `{username,password}`, `GET /me`, `POST /logout` |
| Dashboard | `GET /dashboard` |
| Products | `GET/POST /products`, `GET/PUT/DELETE /products/{id}`, `POST /products/{id}/image`, `?barcode=` |
| Categories | `GET/POST /categories`, `DELETE /categories/{id}` |
| Customers | `GET/POST /customers`, `GET/PUT/DELETE /customers/{id}`, `POST …/loyalty/refresh` |
| Debts | `GET /debts`, `GET /debts/summary`, `POST /debts`, `POST /debts/{id}/payments`, write-off |
| Sales | `GET /sales` (`date`, `from`, `to`, `per_page`), `GET/POST /sales`, `GET /sales/{id}` |
| Suppliers | `GET/POST /suppliers`, `PUT/DELETE /suppliers/{id}` |
| Purchases | `GET/POST /purchases`, `GET/PUT /purchases/{id}`, `POST …/receive`, `POST …/cancel` |
| Branches | `GET/POST /branches`, `PUT/DELETE /branches/{id}` |
| Staff | `GET/POST /staff`, `PUT/DELETE /staff/{id}` |
| Settings | `GET/PUT /settings` |
| Billing stub | `GET /subscriptions`, `GET /subscription-payments` (empty lists) |

## Verified locally (smoke matrix)

- [x] Login username + me + logout
- [x] Dashboard today counts
- [x] Products list/create/update/delete + categories create
- [x] Sales create (discount persisted) + list + from/to + detail
- [x] Customers + debts create/pay + summary
- [x] Suppliers list + purchase receive_now (stock in)
- [x] Branches + staff create
- [x] Settings + subscriptions stub
- [x] Tenant 2 cannot read Tenant 1 sale (404)

## Flutter (same Wi‑Fi)

```bash
cd ../mobile
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
# or Chrome:
flutter run -d chrome --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
```

Reports refetch after POS (`SaleCreated` → `SalesFetchRequested`) so new sales appear without pull-to-refresh.

## Import notes

- `migrate:from-json` is **copy-only**; it never modifies `frontend/data/*.json`.
- Use `--fresh` to wipe MySQL SaaS tables before re-import.
- Use `--demo-tenant2` to seed a second shop for isolation checks.
- Imports suppliers when `suppliers.json` is present.

## Security (local)

- Sanctum Bearer tokens
- Shop scoping on every authenticated query
- Login rate limiting
- `.env` is gitignored

## Moving phase (later — not now)

1. Backup production JSON  
2. Deploy Laravel + MySQL online  
3. Run migrator against the backup  
4. Point production Flutter at the public API  
5. Keep Express as rollback until verified  
