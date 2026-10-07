## Kuendesha Mfumo Kwenye Local Server (LAN) na Kama Portable

### 1. Kuanza kawaida na Node.js

- **Mahitaji**: Node.js 18+ imewekwa kwenye mashine ya server.
- **Hatua**:
  - Fungua terminal ndani ya folder la project hili.
  - Mara ya kwanza:
    - `npm install`
  - Kuanzisha server:
    - `npm start`
  - Mfumo utasikiliza kwenye `0.0.0.0:40000`.

- **Kufikia kwenye mashine hiyo hiyo**:
  - Fungua browser na nenda `http://127.0.0.1:40000/login`.

- **Kufikia kutoka kwenye simu / kompyuta nyingine kwenye mtandao huo huo**:
  - Pata IP ya server (mfano `192.168.1.10`).
  - Tumia `http://192.168.1.10:40000/login` kwenye browser ya kifaa kingine (kikiwa kwenye WiFi/Mtandao huo huo wa LAN).

### 2. Uendeshaji bila kutegemea internet

- Backend na frontend zote zinatoka kwenye server hii ya ndani.
- Kama CDN za Bootstrap/Icons hazipatikani (hakuna internet), mfumo utaendelea kufanya kazi:
  - Fomu, mauzo, madeni, n.k. zitaendelea kufanya kazi.
  - Modals zinategemea fallback ndogo ya JavaScript ili ziendelee kufunguka hata bila Bootstrap JS halisi.
  - Muonekano (styles/icons) unaweza kupungua ubora kama CDN hazipatikani, lakini utendaji (functionality) utaendelea.

### 3. Kutengeneza toleo la “portable” (executable) kwa Linux

Hii hukuruhusu kuhamisha mfumo kama faili moja la programu (plus folda za data), bila ku-install Node.js kwenye kila mashine.

- **Mahitaji (mara moja tu kwenye mashine ya kujenga)**:
  - Node.js 18+
  - `npm install`

- **Kujenga executable ya Linux**:
  - Kwenye terminal:
    - `npm install`
    - `npm run build:linux`
  - Hii itatengeneza faili `haslim-inventory` kwenye mzizi wa project.

- **Kukimbiza executable kwenye mashine nyingine ya Linux**:
  - Kopi:
    - faili `haslim-inventory`
    - folda zifuatazo: `public`, `data`, `uploads`, `backups`, `receipts` (na `sessions` kama unataka kuhifadhi sessions).
  - Kwenye mashine lengwa:
    - Hakikisha faili lina ruhusa ya kutekelezwa: `chmod +x haslim-inventory`
    - Endesha: `./haslim-inventory`
  - Kisha tumia browser:
    - `http://127.0.0.1:40000/login` (mashine hiyo)
    - au `http://IP_YA_HII_MASHINE:40000/login` kwenye vifaa vingine vilivyo kwenye mtandao huo huo.

### 4. Vidokezo vya usalama na matumizi

- Badilisha nenosiri la `admin` mara ya kwanza baada ya kuingia.
- Hakikisha firewall ya mashine ya server inaruhusu port `40000` ndani ya LAN ikiwa unataka vifaa vingine vifike mfumo.
- Kwa backup, tumia menu ya **Backup** ndani ya mfumo; mafaili yatawekwa kwenye folda `backups/`.

### 5. Launcher (icon) ndani ya project

Ndani ya folder la project kuna launchers zifuatazo:

- **Linux**:
  - `run-linux.sh` – script ya kukagua kama Node.js na npm zipo, ku-run `npm install` kama `node_modules` haipo, kisha kuanza server (`npm start`).
  - `haslim-inventory.desktop` – faili la desktop (icon). Mara nyingi utahitaji:
    - Kutoa ruhusa ya kutekelezwa: `chmod +x run-linux.sh haslim-inventory.desktop`
    - Kufungua `.desktop` mara ya kwanza na kuruhusu kama “Trust/Allow launching”.
- **Windows**:
  - `run-windows.bat` – script ya kukagua Node.js/npm, ku-run `npm install` kama `node_modules` haipo, kisha kuanza server (`npm start`).

Kwa mfumo wa kawaida:

- **Linux**: double‑click `haslim-inventory.desktop` au `run-linux.sh` kwenye file manager.
- **Windows**: double‑click `run-windows.bat` kwenye File Explorer.

