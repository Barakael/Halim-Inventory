package com.teratech.tera_pos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var scanReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCANNER_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerScanReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScanReceiver()
                    eventSink = null
                }
            },
        )
    }

    override fun onDestroy() {
        unregisterScanReceiver()
        super.onDestroy()
    }

    private fun registerScanReceiver() {
        unregisterScanReceiver()
        scanReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val code = extractBarcode(intent) ?: return
                    eventSink?.success(code)
                }
            }

        val filter =
            IntentFilter().apply {
                priority = IntentFilter.SYSTEM_HIGH_PRIORITY
                addAction("android.intent.action.SCANRESULT")
                addAction("android.intent.action.DECODE_DATA")
                addAction("com.android.server.scannerservice.broadcast")
                addAction("scan.rcv.message")
                addAction("nlscan.action.SCANNER_RESULT")
                addAction("com.senraise.scanner.action")
                addAction("com.senraise.scanner.result")
                addAction("com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED")
            }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scanReceiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(scanReceiver, filter)
        }
    }

    private fun unregisterScanReceiver() {
        scanReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        scanReceiver = null
    }

    private fun extractBarcode(intent: Intent?): String? {
        if (intent == null) return null
        val keys =
            listOf(
                "scannerdata",
                "barcode",
                "barcode_string",
                "barcodeString",
                "data",
                "SCAN_BARCODE1",
                "code",
                "value",
                "scandata",
                "com.senraise.scanner.data",
                "decode_data",
            )
        for (key in keys) {
            intent.getStringExtra(key)?.let { value ->
                if (value.isNotBlank()) return value.trim()
            }
        }
        return null
    }

    companion object {
        private const val SCANNER_CHANNEL = "com.teratech.tera_pos/scanner"
    }
}
