import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final VoidCallback onClose;

  const BarcodeScannerWidget({
    super.key,
    required this.onBarcodeDetected,
    required this.onClose,
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    if (capture.barcodes.isEmpty) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() {
        _isProcessing = true;
      });
      
      widget.onBarcodeDetected(barcode.rawValue!);
      
      // Give feedback and close
      _controller.stop();
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onClose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: AppColors.white),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: AppColors.white,
            ),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                setState(() {
                  _torchOn = !_torchOn;
                });
              } catch (e) {
                // Handle torch toggle error
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeCapture,
            errorBuilder: (context, error, child) {
              return Center(
                child: Text(
                  'Camera error: $error',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
          
          // Overlay
          CustomPaint(
            size: Size.infinite,
            painter: _ScannerOverlayPainter(),
          ),
          
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Align barcode within the frame to scan',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // Close Button
          Positioned(
            top: 100,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.black.withAlpha(150),
              onPressed: widget.onClose,
              child: const Icon(Icons.close, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withAlpha(100)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.3,
    );
    
    // Draw overlay corners
    final cornerLength = 24.0;
    final cornerWidth = 4.0;
    
    // Top-left corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.left,
          scanRect.top,
          cornerLength,
          cornerWidth,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.left,
          scanRect.top,
          cornerWidth,
          cornerLength,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    // Top-right corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.right - cornerLength,
          scanRect.top,
          cornerLength,
          cornerWidth,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.right - cornerWidth,
          scanRect.top,
          cornerWidth,
          cornerLength,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    // Bottom-left corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.left,
          scanRect.bottom - cornerWidth,
          cornerLength,
          cornerWidth,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.left,
          scanRect.bottom - cornerLength,
          cornerWidth,
          cornerLength,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    // Bottom-right corner
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.right - cornerLength,
          scanRect.bottom - cornerWidth,
          cornerLength,
          cornerWidth,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          scanRect.right - cornerWidth,
          scanRect.bottom - cornerLength,
          cornerWidth,
          cornerLength,
        ),
        const Radius.circular(2),
      ),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
