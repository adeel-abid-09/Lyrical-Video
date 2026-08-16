import 'package:flutter/material.dart';

class CustomHsvColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const CustomHsvColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  static void show(BuildContext context, {required Color initialColor, required ValueChanged<Color> onColorChanged}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CustomHsvColorPickerSheet(
        initialColor: initialColor,
        onColorChanged: onColorChanged,
      ),
    );
  }

  @override
  State<CustomHsvColorPickerSheet> createState() => _CustomHsvColorPickerSheetState();
}

class _CustomHsvColorPickerSheetState extends State<CustomHsvColorPickerSheet> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  void _notifyColor() {
    widget.onColorChanged(_currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title, Color preview, Done
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(color: currentColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Color Palette',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. 2D Saturation / Value Gradient Box
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = 180.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => _updateSV(details.localPosition, width, height),
                  onPanUpdate: (details) => _updateSV(details.localPosition, width, height),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          // Base pure hue color
                          Container(
                            color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                          ),
                          // Horizontal white-to-transparent gradient (Saturation)
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.white, Colors.transparent],
                              ),
                            ),
                          ),
                          // Vertical transparent-to-black gradient (Value / Brightness)
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                          ),
                          // Selector Thumb
                          Positioned(
                            left: (_saturation * width - 12).clamp(0.0, width - 24.0),
                            top: ((1.0 - _value) * height - 12).clamp(0.0, height - 24.0),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentColor,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4, spreadRadius: 1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // 2. Rainbow Hue Spectrum Slider Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const height = 24.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => _updateHue(details.localPosition.dx, width),
                  onPanUpdate: (details) => _updateHue(details.localPosition.dx, width),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Rainbow Bar
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0000), // Red
                                Color(0xFFFFFF00), // Yellow
                                Color(0xFF00FF00), // Green
                                Color(0xFF00FFFF), // Cyan
                                Color(0xFF0000FF), // Blue
                                Color(0xFFFF00FF), // Magenta
                                Color(0xFFFF0000), // Red
                              ],
                            ),
                          ),
                        ),
                        // Hue Draggable Thumb
                        Positioned(
                          left: ((_hue / 360.0) * width - 12).clamp(0.0, width - 24.0),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4, spreadRadius: 1),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _updateSV(Offset localPosition, double width, double height) {
    final newSat = (localPosition.dx / width).clamp(0.0, 1.0);
    final newVal = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
    setState(() {
      _saturation = newSat;
      _value = newVal;
    });
    _notifyColor();
  }

  void _updateHue(double dx, double width) {
    final newHue = ((dx / width) * 360.0).clamp(0.0, 360.0);
    setState(() {
      _hue = newHue;
    });
    _notifyColor();
  }
}
