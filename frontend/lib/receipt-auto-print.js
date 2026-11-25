/**
 * Prints receipts on the office PC when the hosted API pushes a WebSocket
 * event (Laravel Reverb). Also catches up on queued jobs at start and when
 * an admin logs in. Optional POST /hooks/receipt-print remains for LAN tests.
 */
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFile } = require('child_process');
const { promisify } = require('util');
const Pusher = require('pusher-js');
const {
    LARAVEL_URL,
    adaptSale,
    adaptSettings,
    renderSaleReceiptHtml,
    unwrapData,
} = require('./laravel-sot');

const execFileAsync = promisify(execFile);

function apiBase() {
    const configured = (process.env.RECEIPT_API_BASE || '').replace(/\/$/, '');
    if (configured) return configured;
    return `${LARAVEL_URL}/api`;
}

function laravelOrigin() {
    return String(LARAVEL_URL || 'http://127.0.0.1:8000').replace(/\/$/, '');
}

function chromeBinary() {
    const candidates = [
        process.env.CHROME_PATH,
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
        '/usr/bin/google-chrome',
        '/usr/bin/chromium',
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
        'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    ].filter(Boolean);
    return candidates.find((candidate) => fs.existsSync(candidate)) || null;
}

async function api(pathName, { method = 'GET', token, body } = {}) {
    const url = `${apiBase()}${pathName.startsWith('/') ? pathName : `/${pathName}`}`;
    const res = await fetch(url, {
        method,
        headers: {
            Accept: 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        },
        body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let json = null;
    try {
        json = text ? JSON.parse(text) : null;
    } catch {
        json = { message: text || res.statusText };
    }
    return { status: res.status, json, ok: res.ok };
}

async function htmlToPdf(html, pdfPath) {
    const chrome = chromeBinary();
    if (!chrome) {
        throw new Error('Google Chrome / Edge was not found. Set CHROME_PATH.');
    }
    const dir = path.dirname(pdfPath);
    const htmlPath = path.join(dir, 'receipt.html');
    const userDataDir = path.join(dir, 'chrome-profile');
    fs.mkdirSync(userDataDir, { recursive: true });
    fs.writeFileSync(htmlPath, html);
    await execFileAsync(chrome, [
        '--headless=new',
        '--disable-gpu',
        '--no-sandbox',
        '--disable-dev-shm-usage',
        `--user-data-dir=${userDataDir}`,
        '--no-pdf-header-footer',
        `--print-to-pdf=${pdfPath}`,
        htmlPath,
    ], { timeout: 30000 });
    if (!fs.existsSync(pdfPath) || fs.statSync(pdfPath).size < 100) {
        throw new Error('Chrome did not write a receipt PDF');
    }
}

async function pdfToPng(pdfPath, pngPath) {
    if (process.platform === 'darwin') {
        await execFileAsync('sips', [
            '-s', 'format', 'png',
            '--resampleWidth', '1800',
            pdfPath,
            '--out', pngPath,
        ], { timeout: 20000 });
        return;
    }
    await execFileAsync('magick', [
        '-density', '203',
        pdfPath,
        '-background', 'white',
        '-alpha', 'remove',
        '-resize', '1800x',
        pngPath,
    ], { timeout: 30000 });
}

function parsePbm(buf) {
    if (buf[0] !== 0x50 || buf[1] !== 0x34) {
        throw new Error('Receipt image was not a monochrome bitmap');
    }
    let i = 2;
    function skip() {
        while (i < buf.length) {
            const c = buf[i];
            if (c === 0x20 || c === 0x09 || c === 0x0a || c === 0x0d) {
                i += 1;
                continue;
            }
            if (c === 0x23) {
                while (i < buf.length && buf[i] !== 0x0a) i += 1;
                continue;
            }
            break;
        }
    }
    function readInt() {
        skip();
        let n = 0;
        let saw = false;
        while (i < buf.length && buf[i] >= 0x30 && buf[i] <= 0x39) {
            saw = true;
            n = (n * 10) + (buf[i] - 0x30);
            i += 1;
        }
        if (!saw) throw new Error('Bad receipt bitmap size');
        return n;
    }
    const width = readInt();
    const height = readInt();
    if (buf[i] === 0x20 || buf[i] === 0x0a || buf[i] === 0x0d || buf[i] === 0x09) i += 1;
    const rowBytes = Math.ceil(width / 8);
    const need = rowBytes * height;
    if (buf.length - i < need) {
        throw new Error('Receipt bitmap was cut short');
    }
    return { width, height, rowBytes, data: buf.subarray(i, i + need) };
}

function escPosRaster(pbm) {
    const { height, rowBytes, data } = pbm;
    const header = Buffer.from([
        0x1b, 0x40,
        0x1d, 0x76, 0x30, 0x00,
        rowBytes & 0xff,
        (rowBytes >> 8) & 0xff,
        height & 0xff,
        (height >> 8) & 0xff,
    ]);
    const feed = Buffer.from([0x1b, 0x64, 0x04, 0x1d, 0x56, 0x00]);
    return Buffer.concat([header, data, feed]);
}

function writeBluetooth(bytes) {
    const port = process.env.RECEIPT_BT_PORT || '/dev/cu.MPT-II';
    const chunkSize = 512;
    return new Promise((resolve, reject) => {
        fs.open(port, 'r+', (err, fd) => {
            if (err) {
                reject(new Error(`Bluetooth printer is not connected (${port})`));
                return;
            }
            let offset = 0;
            const writeNext = () => {
                if (offset >= bytes.length) {
                    fs.close(fd, () => resolve(`Bluetooth ${port} ${bytes.length} bytes`));
                    return;
                }
                const length = Math.min(chunkSize, bytes.length - offset);
                fs.write(fd, bytes, offset, length, null, (writeErr, written) => {
                    if (writeErr) {
                        fs.close(fd, () => reject(writeErr));
                        return;
                    }
                    offset += written || length;
                    setTimeout(writeNext, 15);
                });
            };
            writeNext();
        });
    });
}

function writeUsb(bytes) {
    const vendor = Number.parseInt(process.env.RECEIPT_USB_VENDOR || '0416', 16);
    const product = Number.parseInt(process.env.RECEIPT_USB_PRODUCT || '5011', 16);
    return new Promise((resolve, reject) => {
        const usbLib = require('usb');
        const device = usbLib.findByIds(vendor, product);
        if (!device) {
            reject(new Error('POS80 printer is not connected on USB'));
            return;
        }
        device.open();
        const iface = device.interfaces[0];
        const endpoint = iface.endpoints.find((item) => item.direction === 'out');
        if (!endpoint) {
            try { device.close(); } catch { /* already closed */ }
            reject(new Error('POS80 has no USB output endpoint'));
            return;
        }
        try {
            iface.claim();
        } catch (err) {
            try { device.close(); } catch { /* already closed */ }
            reject(err);
            return;
        }
        endpoint.transfer(bytes, (err) => {
            const done = () => {
                try { device.close(); } catch { /* already closed */ }
            };
            try {
                iface.release(true, done);
            } catch {
                done();
            }
            if (err) reject(err);
            else resolve(`POS80 USB ${bytes.length} bytes`);
        });
    });
}

function windowsRawPrintScript(binPath, printerName) {
    const safeBin = binPath.replace(/'/g, "''");
    const safePrinter = printerName.replace(/'/g, "''");
    return `
$ErrorActionPreference = 'Stop'
$printer = '${safePrinter}'
$path = '${safeBin}'
$bytes = [System.IO.File]::ReadAllBytes($path)
$code = @"
using System;
using System.Runtime.InteropServices;
public class HaslimRawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.drv", EntryPoint = "OpenPrinterA", SetLastError = true)]
  public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);
  [DllImport("winspool.drv", EntryPoint = "ClosePrinter", SetLastError = true)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "StartDocPrinterA", SetLastError = true)]
  public static extern int StartDocPrinter(IntPtr hPrinter, int level, [In] DOCINFOA di);
  [DllImport("winspool.drv", EntryPoint = "EndDocPrinter", SetLastError = true)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "StartPagePrinter", SetLastError = true)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "EndPagePrinter", SetLastError = true)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.drv", EntryPoint = "WritePrinter", SetLastError = true)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);
}
"@
Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue
$h = [IntPtr]::Zero
if (-not [HaslimRawPrint]::OpenPrinter($printer, [ref]$h, [IntPtr]::Zero)) {
  throw "Could not open printer $printer"
}
try {
  $di = New-Object HaslimRawPrint+DOCINFOA
  $di.pDocName = 'HaslimReceipt'
  $di.pDataType = 'RAW'
  if ([HaslimRawPrint]::StartDocPrinter($h, 1, $di) -eq 0) { throw 'StartDocPrinter failed' }
  [void][HaslimRawPrint]::StartPagePrinter($h)
  $ptr = [Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
  [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $ptr, $bytes.Length)
  $written = 0
  if (-not [HaslimRawPrint]::WritePrinter($h, $ptr, $bytes.Length, [ref]$written)) {
    throw 'WritePrinter failed'
  }
  [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
  [void][HaslimRawPrint]::EndPagePrinter($h)
  [void][HaslimRawPrint]::EndDocPrinter($h)
} finally {
  [void][HaslimRawPrint]::ClosePrinter($h)
}
`;
}

async function writeWindowsPrinter(bytes) {
    const printer = (process.env.RECEIPT_PRINTER || 'POS80').trim();
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'haslim-raw-'));
    const binPath = path.join(dir, 'receipt.bin');
    const ps1Path = path.join(dir, 'print.ps1');
    fs.writeFileSync(binPath, bytes);
    fs.writeFileSync(ps1Path, windowsRawPrintScript(binPath, printer));
    try {
        await execFileAsync('powershell.exe', [
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ps1Path,
        ], { timeout: 30000 });
        return `Windows ${printer} ${bytes.length} bytes`;
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

function resolveTransport() {
    const configured = (process.env.RECEIPT_TRANSPORT || '').trim().toLowerCase();
    if (configured) return configured;
    return process.platform === 'win32' ? 'windows' : 'usb';
}

async function sendToPrinter(pdfPath) {
    const dir = path.dirname(pdfPath);
    const pngPath = path.join(dir, 'receipt.png');
    const pbmPath = path.join(dir, 'receipt.pbm');
    await pdfToPng(pdfPath, pngPath);
    await execFileAsync('magick', [
        pngPath,
        '-background', 'white',
        '-alpha', 'remove',
        '-colorspace', 'Gray',
        '-fuzz', '8%',
        '-trim', '+repage',
        '-resize', `${process.env.RECEIPT_PRINT_WIDTH || '576'}x`,
        '-threshold', '40%',
        '-morphology', 'Dilate', 'Diamond:1',
        '-monochrome',
        `pbm:${pbmPath}`,
    ], { timeout: 20000 });
    const raster = escPosRaster(parsePbm(fs.readFileSync(pbmPath)));
    const transport = resolveTransport();
    if (transport === 'bluetooth') return writeBluetooth(raster);
    if (transport === 'windows') return writeWindowsPrinter(raster);
    return writeUsb(raster);
}

function autoPrintEnabled() {
    return process.env.RECEIPT_AUTO_PRINT === '1';
}

function transportLabel() {
    const transport = resolveTransport();
    if (transport === 'bluetooth') {
        return `Bluetooth ${process.env.RECEIPT_BT_PORT || '/dev/cu.MPT-II'}`;
    }
    if (transport === 'windows') {
        return `Windows ${process.env.RECEIPT_PRINTER || 'POS80'}`;
    }
    return 'POS80 USB';
}

let token = null;
let pusherClient = null;

async function login() {
    const username = (process.env.RECEIPT_USERNAME || 'admin').trim();
    const password = process.env.RECEIPT_PASSWORD || '';
    if (!username || !password) {
        throw new Error('Set RECEIPT_USERNAME and RECEIPT_PASSWORD');
    }
    const { ok, json, status } = await api('/login', {
        method: 'POST',
        body: { username, password },
    });
    if (!ok || !json?.token) {
        throw new Error(json?.message || `Login failed (${status})`);
    }
    token = json.token;
}

async function withToken(run) {
    if (!token) await login();
    let result = await run(token);
    if (result.status === 401) {
        token = null;
        await login();
        result = await run(token);
    }
    return result;
}

async function printJob(jobId) {
    const jobRes = await withToken((auth) => api(`/receipt-jobs/${jobId}`, { token: auth }));
    if (!jobRes.ok) {
        throw new Error(jobRes.json?.message || `Receipt job ${jobId} failed (${jobRes.status})`);
    }
    const { job, sale: rawSale } = jobRes.json?.data || {};
    if (!job || !rawSale) {
        throw new Error(`Receipt job ${jobId} came back empty`);
    }
    if (job.status !== 'queued') return;

    const settingsRes = await withToken((auth) => api('/settings', { token: auth }));
    const sale = adaptSale(rawSale);
    const settings = settingsRes.ok
        ? adaptSettings(unwrapData(settingsRes.json) || settingsRes.json || {})
        : {};
    const html = renderSaleReceiptHtml(sale, { ...(settings || {}), receiptPaperMm: 80 });

    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'haslim-receipt-'));
    const pdfPath = path.join(dir, 'receipt.pdf');
    try {
        await htmlToPdf(html, pdfPath);
        const sent = await sendToPrinter(pdfPath);
        const marked = await withToken((auth) => api(`/receipt-jobs/${jobId}/printed`, {
            method: 'POST',
            token: auth,
            body: {},
        }));
        if (!marked.ok) {
            throw new Error(marked.json?.message || `Could not mark job ${jobId} printed`);
        }
        console.log(`[receipt-print] ${job.serial_number || job.sale_id} printed (${sent})`);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

const RETRY_DELAYS_MS = [5000, 15000, 45000];
const inFlight = new Set();
let chain = Promise.resolve();

function schedulePrint(jobId, attempt = 0) {
    const id = String(jobId);
    if (attempt === 0) {
        if (inFlight.has(id)) return;
        inFlight.add(id);
    }
    chain = chain
        .then(() => printJob(id))
        .then(() => {
            inFlight.delete(id);
        }, (err) => {
            const delay = RETRY_DELAYS_MS[attempt];
            if (delay === undefined) {
                inFlight.delete(id);
                console.error(`[receipt-print] job ${id} stayed queued: ${err.message}`);
                return;
            }
            console.error(`[receipt-print] job ${id} failed (${err.message}); retrying in ${delay / 1000}s`);
            setTimeout(() => schedulePrint(id, attempt + 1), delay);
        });
}

function secretMatches(given) {
    const secret = process.env.RECEIPT_PRINT_WEBHOOK_SECRET || '';
    if (!secret || !given) return false;
    const a = Buffer.from(given);
    const b = Buffer.from(secret);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function mountReceiptPrintHook(app) {
    app.post('/hooks/receipt-print', (req, res) => {
        if (!autoPrintEnabled()) {
            return res.status(503).json({ message: 'Receipt printing is off on this computer' });
        }
        const header = req.get('authorization') || '';
        if (!secretMatches(header.startsWith('Bearer ') ? header.slice(7) : '')) {
            return res.status(401).json({ message: 'Not allowed' });
        }
        const jobId = req.body?.job_id;
        if (!jobId) {
            return res.status(422).json({ message: 'job_id is required' });
        }
        res.status(202).json({ accepted: true });
        console.log(`[receipt-print] sale ${req.body.sale_id ?? '?'} → job ${jobId}`);
        schedulePrint(jobId);
    });
}

async function printQueuedOnce() {
    if (!autoPrintEnabled()) return;
    try {
        const result = await withToken((auth) => api('/receipt-jobs?status=queued', { token: auth }));
        if (!result.ok) {
            throw new Error(result.json?.message || `Queue failed (${result.status})`);
        }
        const jobs = Array.isArray(result.json?.data) ? result.json.data.slice().reverse() : [];
        if (jobs.length) {
            console.log(`[receipt-print] catching up on ${jobs.length} queued receipt(s)`);
        } else {
            console.log('[receipt-print] no queued receipts to catch up');
        }
        for (const job of jobs) schedulePrint(job.id);
    } catch (err) {
        console.error(`[receipt-print] catch-up skipped: ${err.message}`);
    }
}

function canCatchUpRole(role) {
    const normalized = String(role || '').toLowerCase();
    return normalized === 'admin' || normalized === 'owner';
}

function onAdminLogin(user) {
    if (!autoPrintEnabled()) return;
    if (!canCatchUpRole(user?.role)) return;
    console.log(`[receipt-print] admin login (${user.username || user.role}) → catch up`);
    printQueuedOnce();
}

async function startReceiptWebSocket() {
    if (!autoPrintEnabled()) return;
    const key = process.env.REVERB_APP_KEY;
    const host = process.env.REVERB_HOST;
    if (!key || !host) {
        console.log('[receipt-print] WebSocket off (set REVERB_APP_KEY and REVERB_HOST)');
        return;
    }

    const me = await withToken((auth) => api('/me', { token: auth }));
    if (!me.ok) {
        throw new Error(me.json?.message || `Could not load shop for WebSocket (${me.status})`);
    }
    const shopId = me.json?.shop_id ?? me.json?.data?.shop_id;
    if (!shopId) {
        throw new Error('Logged-in user has no shop_id for receipt channel');
    }

    if (pusherClient) {
        try { pusherClient.disconnect(); } catch { /* ignore */ }
        pusherClient = null;
    }

    const port = Number(process.env.REVERB_PORT || (process.env.REVERB_SCHEME === 'https' ? 443 : 8080));
    const forceTLS = (process.env.REVERB_SCHEME || 'https') === 'https';

    pusherClient = new Pusher(key, {
        wsHost: host,
        wsPort: port,
        wssPort: port,
        forceTLS,
        enabledTransports: ['ws', 'wss'],
        disableStats: true,
        cluster: 'mt1',
        authorizer: (channel) => ({
            authorize: (socketId, callback) => {
                withToken(async (auth) => {
                    const res = await fetch(`${laravelOrigin()}/api/broadcasting/auth`, {
                        method: 'POST',
                        headers: {
                            Authorization: `Bearer ${auth}`,
                            Accept: 'application/json',
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            socket_id: socketId,
                            channel_name: channel.name,
                        }),
                    });
                    const body = await res.json().catch(() => ({}));
                    if (!res.ok) {
                        callback(new Error(body.message || `Broadcast auth failed (${res.status})`), null);
                        return { status: res.status, json: body, ok: false };
                    }
                    callback(null, body);
                    return { status: res.status, json: body, ok: true };
                }).catch((err) => callback(err, null));
            },
        }),
    });

    const channelName = `private-shop.${shopId}.receipts`;
    const channel = pusherClient.subscribe(channelName);
    channel.bind('pusher:subscription_succeeded', () => {
        console.log(`[receipt-print] WebSocket subscribed → ${channelName}`);
    });
    channel.bind('pusher:subscription_error', (status) => {
        console.error(`[receipt-print] WebSocket subscribe failed (${status})`);
    });
    channel.bind('receipt.queued', (payload) => {
        const jobId = payload?.job_id;
        if (!jobId) return;
        console.log(`[receipt-print] live sale ${payload.sale_id ?? '?'} → job ${jobId}`);
        schedulePrint(jobId);
    });

    console.log(`[receipt-print] WebSocket connecting ${forceTLS ? 'wss' : 'ws'}://${host}:${port}`);
}

async function startReceiptPrintAgent() {
    if (!autoPrintEnabled()) return;
    console.log(`[receipt-print] ready → ${apiBase()} → ${transportLabel()}`);
    await printQueuedOnce();
    try {
        await startReceiptWebSocket();
    } catch (err) {
        console.error(`[receipt-print] WebSocket not started: ${err.message}`);
    }
}

module.exports = {
    mountReceiptPrintHook,
    printQueuedOnce,
    onAdminLogin,
    startReceiptPrintAgent,
};
