import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterDebugDialog extends StatefulWidget {
  const PrinterDebugDialog({super.key});

  @override
  State<PrinterDebugDialog> createState() => _PrinterDebugDialogState();
}

class _PrinterDebugDialogState extends State<PrinterDebugDialog> {
  bool _isChecking = false;
  String _debugInfo = '';

  Future<void> _runDiagnostics() async {
    setState(() {
      _isChecking = true;
      _debugInfo = 'Running diagnostics...\n\n';
    });

    try {
      // Check Bluetooth permissions
      final hasPermission = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      _addDebugInfo('Bluetooth Permission: $hasPermission');
      
      if (!hasPermission) {
        _addDebugInfo('Permission denied - please enable in app settings');
      }

      // Check if Bluetooth is enabled
      final bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      _addDebugInfo('Bluetooth Enabled: $bluetoothEnabled');

      // Check connection status
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      _addDebugInfo('Printer Connected: $isConnected');

      // Get paired devices
      final pairedDevices = await PrintBluetoothThermal.pairedBluetooths;
      _addDebugInfo('Paired Devices: ${pairedDevices.length}');
      
      for (final device in pairedDevices) {
        _addDebugInfo('- ${device.name} (${device.macAdress})');
      }

      // Test basic ESC/POS generation
      _addDebugInfo('\nTesting ESC/POS generation...');
      try {
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm80, profile);
        final testBytes = generator.reset();
        testBytes.addAll(generator.text('TEST PRINT'));
        testBytes.addAll(generator.feed(2));
        testBytes.addAll(generator.cut());
        
        _addDebugInfo('ESC/POS bytes generated: ${testBytes.length}');
        
        // Try to print if connected
        if (isConnected && pairedDevices.isNotEmpty) {
          _addDebugInfo('Attempting test print...');
          final printResult = await PrintBluetoothThermal.writeBytes(testBytes);
          _addDebugInfo('Test print result: $printResult');
        }
      } catch (e) {
        _addDebugInfo('ESC/POS generation error: $e');
      }

    } catch (e) {
      _addDebugInfo('Diagnostic error: $e');
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _addDebugInfo(String info) {
    setState(() {
      _debugInfo += '$info\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Printer Debug Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _runDiagnostics,
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report),
              label: Text(_isChecking ? 'Running...' : 'Run Diagnostics'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _debugInfo.isEmpty ? 'Press "Run Diagnostics" to start...' : _debugInfo,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
