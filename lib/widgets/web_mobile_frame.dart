import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps the application layout in a mobile phone frame when running on Web desktop browsers.
/// On native Android/iOS or small screens (<= 600px width), it renders the app directly.
class WebMobileFrame extends StatefulWidget {
  final Widget child;

  const WebMobileFrame({super.key, required this.child});

  @override
  State<WebMobileFrame> createState() => _WebMobileFrameState();
}

class _WebMobileFrameState extends State<WebMobileFrame> {
  bool _forceFullScreenOnWeb = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return widget.child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // On narrow screens (e.g., mobile web browser) or when toggled to full screen
    if (screenWidth <= 600 || _forceFullScreenOnWeb) {
      return widget.child;
    }

    // Dynamic phone frame dimensions according to viewport height
    final phoneWidth = 390.0;
    final availableHeight = screenHeight - 80.0;
    final phoneHeight = availableHeight > 400 ? availableHeight.clamp(400.0, 844.0) : screenHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // Ambient glowing background graphics
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C5CE7).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7675).withOpacity(0.15),
              ),
            ),
          ),

          // Main Centered Phone Mockup Container
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Web Preview Bar
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Android App Web Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _forceFullScreenOnWeb = !_forceFullScreenOnWeb;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.fullscreen, color: Colors.white70, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Full Canvas',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Device Frame Outline
                    Container(
                      width: phoneWidth,
                      height: phoneHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(44),
                        border: Border.all(
                          color: const Color(0xFF2C2C3E),
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Stack(
                          children: [
                            // App Screen Content
                            Positioned.fill(child: widget.child),

                            // Dynamic Phone Speaker/Notch Overlay at Top
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    width: 140,
                                    height: 26,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF14141E),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 45,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
