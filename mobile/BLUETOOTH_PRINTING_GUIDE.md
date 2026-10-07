# Bluetooth Thermal Printer Configuration Guide

## Android 12+ Bluetooth Permissions Setup

### 1. App Permissions
Your app now has the correct Bluetooth permissions for Android 12+:

```xml
<!-- For Android 11 and below -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>

<!-- For Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
```

### 2. Manual Permission Grant (Android 12+)

On Android 12+ devices, you need to manually grant the "Nearby devices" permission:

1. Go to **Settings** → **Apps** → **Tera POS**
2. Tap on **Permissions**
3. Enable **Nearby devices** permission
4. Also enable **Bluetooth** and **Location** (if shown)

### 3. Printer Pairing Steps

1. **Turn on your thermal printer** and make sure it's in pairing mode
2. On your POS device, go to **Settings** → **Bluetooth**
3. Scan for devices and select your printer from the list
4. Complete the pairing process (usually no PIN needed)
5. Wait for the printer to show as "Connected" or "Paired"

### 4. In-App Connection Steps

1. Open Tera POS and complete a sale
2. In the receipt dialog, tap **"Connect Printer"**
3. Select your printer from the list
4. The app will attempt to connect (up to 3 tries)
5. Once connected, you'll see "Connected: [Printer Name]"

### 5. Troubleshooting

#### If connection fails:

1. **Check printer status**: Make sure the printer is on and ready
2. **Bluetooth conflicts**: Close other apps that might be using the printer
3. **Restart Bluetooth**: Turn Bluetooth off and on again
4. **Restart printer**: Power cycle the thermal printer
5. **Re-pair printer**: Delete the pairing and pair again

#### Common error messages and solutions:

- **"Bluetooth permission denied"**: 
  - Go to Settings → Apps → Tera POS → Permissions
  - Enable "Nearby devices" permission

- **"No paired printers found"**:
  - Make sure printer is on and in pairing mode
  - Go to Bluetooth settings and pair the printer first

- **"Failed to connect after 3 attempts"**:
  - Check if printer is connected to another device/app
  - Restart both Bluetooth and the printer
  - Try disconnecting other devices from the printer

### 6. Printer Compatibility

This app supports most ESC/POS compatible thermal printers including:
- Epson TM series
- Star Micronics mC/mPOP series
- Custom POS thermal printers
- Sunmi printers (via Bluetooth)

### 7. Testing the Connection

After connecting:
1. Tap the **"Print"** button to print a test receipt
2. If printing works, the connection is successful
3. If not, check the printer's status and try reconnecting

### 8. Best Practices

1. **Keep the printer close** to the POS device (within 10 meters)
2. **Keep the printer powered** during business hours
3. **Regularly check paper** and ink/ribbon levels
4. **Test print** daily before opening
5. **Have a backup printer** if possible

### 9. Debug Information

The app now provides detailed logging. To see connection details:
- Check the console output in Android Studio
- Look for messages like:
  - "Bluetooth permission check: true/false"
  - "Found X paired devices"
  - "Connection attempt X of 3"
  - "Successfully connected on attempt X"

### 10. Alternative Connection Methods

If Bluetooth continues to fail:
1. **USB Connection**: Some printers support USB (requires additional setup)
2. **Network/Wi-Fi**: If your printer has Wi-Fi capability
3. **Share PDF**: Use the "Share PDF" button to print from other apps

---

## Quick Setup Checklist

- [ ] Update app with new permissions (done)
- [ ] Grant "Nearby devices" permission on Android 12+
- [ ] Pair printer in Bluetooth settings
- [ ] Connect printer in app
- [ ] Test print receipt
- [ ] Verify print quality

## Support

If you continue to experience issues:
1. Check the printer's user manual
2. Verify printer compatibility with ESC/POS
3. Contact your printer supplier for Android-specific setup
4. Test with a different Android device if possible
