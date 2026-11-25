# Office PC automatic receipts (hosted + WebSocket)

Cashiers sell on the **hosted** system. The **office Windows PC** keeps a local print agent running. That agent connects **out** to Laravel Reverb over WebSocket. Each new sale is pushed once; no idle polling.

Printing uses the **admin’s login session** on this PC — no password is stored in `.env`.
When an admin logs into the local dashboard, the agent catches up on every `queued` receipt and stays connected for live sales. Logging out pauses printing.

## Hosted server

1. Deploy the backend that includes Laravel Reverb.
2. In hosted `.env`:

```env
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=...
REVERB_APP_KEY=...
REVERB_APP_SECRET=...
REVERB_HOST=api.your-domain.com
REVERB_PORT=443
REVERB_SCHEME=https
```

3. Keep Reverb running (Supervisor / systemd), for example:

```bash
php artisan reverb:start --host=0.0.0.0 --port=8080
```

Put HTTPS/WSS in front of that port (Nginx, Caddy, or a host panel).

## Office Windows PC

1. Install Node.js 18+, Google Chrome or Edge, and ImageMagick (`magick` on PATH).
2. Install the normal Windows driver for the POS80 so it appears under Printers (name e.g. `POS80`).
3. Copy the `frontend` app, run `npm install`, then set `.env`:

```env
LARAVEL_URL=https://api.your-domain.com
RECEIPT_API_BASE=https://api.your-domain.com/api
RECEIPT_AUTO_PRINT=1
RECEIPT_TRANSPORT=windows
RECEIPT_PRINTER=POS80
REVERB_APP_KEY=same-as-hosted
REVERB_HOST=api.your-domain.com
REVERB_PORT=443
REVERB_SCHEME=https
```

4. Start and leave running during work hours:

```bat
npm start
```

Or use PM2 / a Windows service so it starts when the PC boots.

5. Admin opens `http://127.0.0.1:40000/login` on that PC and signs in with their normal account.
   Any unprinted receipts print immediately. New online sales print while that admin stays logged in.

## Checks

- Agent log shows `WebSocket subscribed → private-shop.{id}.receipts`.
- After a cashier sale: `live sale … → job …` then `printed`.
- After admin login with queued jobs: `admin login … → catch up`.
