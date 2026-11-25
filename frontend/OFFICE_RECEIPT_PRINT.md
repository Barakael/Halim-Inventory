# Office PC automatic receipts (browser + Windows POS-80)

Cashiers sell on the **hosted** system. The **office Windows PC** does **not** need Node or any local agent.

1. Set the Windows default printer to **POS-80** (exact name you registered).
2. On that PC, open Chrome/Edge to https://haslim.co.tz and log in as **admin**.
3. Leave the dashboard tab open during work hours.

The admin browser listens over WebSocket. Each new sale opens the receipt and prints to the default POS-80. When the admin opens the dashboard, any still-queued receipts print too.

Optional silent printing (no print dialog): create a Chrome desktop shortcut with  
`--kiosk-printing https://haslim.co.tz/login`  
and set POS-80 as the Windows default printer.

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

1. Confirm **POS-80** prints a Windows test page.
2. Set **POS-80** as the default printer.
3. Open https://haslim.co.tz, log in as admin, leave the tab open.
4. Make a cashier sale → the print dialog (or silent kiosk print) should fire on that PC.

## Checks

- Browser console shows `browser subscribed private-shop.{id}.receipts`.
- After a cashier sale: receipt print runs on the office PC.
- Opening the admin dashboard prints any still-queued receipts.
