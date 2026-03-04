import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/ambient_light_overlay.dart';

class CarPairingScreen extends StatefulWidget {
  const CarPairingScreen({super.key});

  @override
  State<CarPairingScreen> createState() => _CarPairingScreenState();
}

class _CarPairingScreenState extends State<CarPairingScreen> with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  
  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // 0 = Borrow (Scanner), 1 = Share (Show QR)
  int _selectedMode = 0; 
  late String _myVehicleToken;
  late String _displayId;

  @override
  void initState() {
    super.initState();
    
    // Generate unique ID from actual logged in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.length >= 6) {
      final shortUid = user.uid.substring(0, 6).toUpperCase();
      _displayId = "CAR_$shortUid";
    } else {
      _displayId = "CAR_10924"; // Fallback
    }
    _myVehicleToken = "velora://share/$_displayId";

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _selectedMode != 0) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.startsWith('velora://share/')) {
        setState(() => _isProcessing = true);
        
        // Vibrate/Feedback (simulate pairing sequence)
        _controller.stop();
        
        // Show success exactly matching our futuristic theme
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const _ConnectingDialog(),
          );
        }

        // Simulate 2 sec network sync 
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pop(); // close dialog
          
          // Extract ID from velora://share/CAR_XXXX
          final vehicleId = code.replaceFirst('velora://share/', '');
          
          Navigator.of(context).pop({
            'vehicleId': vehicleId, 
            'ownerName': 'John Smith (Verified Owner)',
          }); // return map to home
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully connected to borrowed vehicle!'),
              backgroundColor: Color(0xFF00C853),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Show invalid code warning
        setState(() => _isProcessing = true);
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('⚠️ Invalid Velora vehicle code'),
             backgroundColor: Colors.redAccent,
           ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightMode = AmbientLightProvider.of(context);
    final textPri = LightThemePalette.textPrimary(lightMode);
    final accent = LightThemePalette.accent(lightMode);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Scanner Background (Only when borrowing) ───
          if (_selectedMode == 0)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          if (_selectedMode == 0)
            CustomPaint(
              painter: _ScannerOverlayPainter(
                borderColor: accent,
                borderRadius: 30,
              ),
              child: Container(),
            ),

          // ─── Share Background (Dark abstract) ───
          if (_selectedMode == 1)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    accent.withValues(alpha: 0.15),
                    Colors.black,
                  ],
                ),
              ),
            ),

          // ─── Shared Foreground Content ───
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Vehicle Connectivity', 
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Flashlight mapping only for borrow mode
                      if (_selectedMode == 0)
                        IconButton(
                          icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                          onPressed: () => _controller.toggleTorch(),
                        )
                      else
                        const SizedBox(width: 48), // Padding equivalent to icon button
                    ],
                  ),
                ),
                
                // ─── Segmented Control ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F26).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildSegmentButton(
                          title: 'Borrow Car',
                          icon: Icons.qr_code_scanner_rounded,
                          index: 0,
                          accent: accent,
                          textPri: textPri,
                        ),
                        _buildSegmentButton(
                          title: 'Share Car',
                          icon: Icons.qr_code_2_rounded,
                          index: 1,
                          accent: accent,
                          textPri: textPri,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ─── Center Action View ───
                if (_selectedMode == 0 && !_isProcessing)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: accent.withValues(alpha: _pulseAnimation.value * 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: _pulseAnimation.value * 0.2),
                              blurRadius: 50 * _pulseAnimation.value,
                              spreadRadius: 10 * _pulseAnimation.value,
                            )
                          ],
                        ),
                      );
                    },
                  ),

                if (_selectedMode == 1)
                  _buildShareQRView(accent, textPri),

                const Spacer(),

                // ─── Instructional Bottom Panel ───
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F26).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _selectedMode == 0 ? Icons.directions_car_rounded : Icons.share_rounded, 
                              color: accent, 
                              size: 32
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedMode == 0 ? 'Scan to Borrow' : 'Let Someone Borrow',
                              style: TextStyle(color: textPri, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedMode == 0 
                                  ? 'Scan the owner\'s Velora Drive QR code to pair your profile temporarily to their vehicle.'
                                  : 'Show this QR code to the borrower. Once they scan it, their Velora app will pair to your car.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareQRView(Color accent, Color textPri) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 80,
            spreadRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: _myVehicleToken,
            version: QrVersions.auto,
            size: 200.0,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('ID: $_displayId', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required int index,
    required Color accent,
    required Color textPri,
  }) {
    final isSelected = _selectedMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMode = index;
            if (index == 0) {
              _controller.start();
            } else {
              _controller.stop();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Custom Darkening Overlay with Clear Target Hole ───
class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;

  _ScannerOverlayPainter({required this.borderColor, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    const double scanAreaSize = 250.0;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );
    final RRect scanRRect = RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius));

    final Paint paint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()..addRRect(scanRRect);
    final Path overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    
    canvas.drawPath(overlayPath, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double cornerRadius = borderRadius;
    const double cornerLength = 40.0;

    Path topLeftPath = Path()
      ..moveTo(scanRect.left, scanRect.top + cornerLength)
      ..arcToPoint(Offset(scanRect.left + cornerRadius, scanRect.top),
          radius: Radius.circular(cornerRadius), clockwise: true)
      ..lineTo(scanRect.left + cornerLength, scanRect.top);
    canvas.drawPath(topLeftPath, borderPaint);

    Path topRightPath = Path()
      ..moveTo(scanRect.right - cornerLength, scanRect.top)
      ..arcToPoint(Offset(scanRect.right, scanRect.top + cornerRadius),
          radius: Radius.circular(cornerRadius), clockwise: true)
      ..lineTo(scanRect.right, scanRect.top + cornerLength);
    canvas.drawPath(topRightPath, borderPaint);

    Path bottomLeftPath = Path()
      ..moveTo(scanRect.left, scanRect.bottom - cornerLength)
      ..arcToPoint(Offset(scanRect.left + cornerRadius, scanRect.bottom),
          radius: Radius.circular(cornerRadius), clockwise: false)
      ..lineTo(scanRect.left + cornerLength, scanRect.bottom);
    canvas.drawPath(bottomLeftPath, borderPaint);

    Path bottomRightPath = Path()
      ..moveTo(scanRect.right - cornerLength, scanRect.bottom)
      ..arcToPoint(Offset(scanRect.right, scanRect.bottom - cornerRadius),
          radius: Radius.circular(cornerRadius), clockwise: false)
      ..lineTo(scanRect.right, scanRect.bottom - cornerLength);
    canvas.drawPath(bottomRightPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Glowing Connection Dialog ───
class _ConnectingDialog extends StatelessWidget {
  const _ConnectingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F26).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00CFFF).withValues(alpha: 0.3), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3300CFFF),
                  blurRadius: 40,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 64, height: 64,
                  child: CircularProgressIndicator(
                    color: Color(0xFF00CFFF),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Authenticating Vehicle',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Establishing secure telemetry link via Bluetooth BLE...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
