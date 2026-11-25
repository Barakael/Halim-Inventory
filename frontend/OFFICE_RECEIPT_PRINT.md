# Office PC automatic receipts (browser + Windows POS-80)

Cashiers sell on the **hosted** system. The **office Windows PC** does **not** need Node or any local agent.

A normal browser tab **cannot** silent-print by itself (Chrome blocks it). For real auto-print use the setup below.

## Required office setup (auto-print)

1. Set the Windows default printer to **POS-80**.
2. Create a Chrome desktop shortcut (right‑click Chrome → Properties → Target) like:

```text
"C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk-printing --new-window https://haslim.co.tz/login
```

3. Open that shortcut, log in as **admin**, leave the tab open during work hours.
4. When Chrome blocks a pop-up, click the address-bar icon → **Always allow pop-ups** for `haslim.co.tz`.

With that, each sale opens the receipt and `--kiosk-printing` sends it straight to POS-80 (no print dialog). Queued jobs also catch up when admin is online.

## Fallback (no kiosk)

- Mauzo → yellow **Print** button, or the bottom-right **Print queued now** banner.
- Still needs POS-80 as the Windows default printer (or pick it in the dialog).

## Other options (if you cannot use kiosk Chrome)

| Option | What it is |
|--------|------------|
| **QZ Tray** | Small Windows app; website talks to it for true silent POS printing |
| **PrintNode** | Cloud print client on the office PC |
| **Local print agent** | Custom Windows program that listens for jobs (needs install on office PC) |

For Haslim, **Chrome + `--kiosk-printing` + allow pop-ups** is the simplest path with no extra software.

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
