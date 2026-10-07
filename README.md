# Halim Inventory — Monorepo

Local-first layout for the web dashboard, SaaS API, and mobile POS.

| Package | Stack | Role |
|---------|--------|------|
| [`frontend/`](frontend/) | Vanilla JS + Bootstrap + Express | Web dashboard + legacy JSON API |
| [`backend/`](backend/) | Laravel + MySQL + Sanctum | Multi-tenant SaaS API for mobile |
| [`mobile/`](mobile/) | Flutter | POS app (Bearer token → Laravel) |

**Do not push or deploy to production until the moving phase is explicitly approved.**

## Quick start (local)

### 1. Frontend (legacy web)

```bash
cd frontend
npm install
npm start
# http://localhost:40000
```

### 2. Backend (Laravel API)

```bash
cd backend
cp .env.example .env   # if needed
# Configure MySQL in .env, then:
php artisan migrate
php artisan serve --host=0.0.0.0 --port=8000
# API root: http://<PC_LAN_IP>:8000/api
```

Import a local JSON copy (copy-only; does not delete `frontend/data`):

```bash
php artisan migrate:from-json ../frontend/data
```

### 3. Mobile (same Wi‑Fi as PC)

```bash
cd mobile
# Replace with your Mac Wi‑Fi IP from: ipconfig getifaddr en0
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/api
```

## Docs

- Frontend deploy notes: [`frontend/LOCAL_DEPLOYMENT.md`](frontend/LOCAL_DEPLOYMENT.md)
- Backend local runbook: [`backend/README.md`](backend/README.md)
