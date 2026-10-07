#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "=== HASLIM INVENTORY - Linux Launcher ==="

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js haijapatikana. Tafadhali weka Node.js 18+ kwenye mashine hii."
  read -rp "Bonyeza ENTER kufunga..."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm haijapatikana. Tafadhali weka Node.js (pamoja na npm)."
  read -rp "Bonyeza ENTER kufunga..."
  exit 1
fi

if [ ! -d "node_modules" ]; then
  echo "node_modules haipo. Naendesha 'npm install' mara ya kwanza..."
  npm install || {
    echo "npm install imeshindikana. Angalia makosa hapo juu."
    read -rp "Bonyeza ENTER kufunga..."
    exit 1
  }
fi

echo "Kuanza server kwenye port 40000..."
echo "Unaweza kufungua: http://127.0.0.1:40000/login au http://IP_YA_SERVER:40000/login"

npm start

