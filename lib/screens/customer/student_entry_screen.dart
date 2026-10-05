import "dart:convert";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "../../core/pizza_image_asset.dart";

class StudentEntryScreen extends StatelessWidget {
  const StudentEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Subtle Decorative Curves/Petals
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEE5430),
                  Color(0xFFE64A19),
                  Color(0xFFD84315),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _SubtlePetalWatermarkPainter(),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 480 : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header: Title & Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            "Flavor\nCrafted\nWith Love",
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: isDesktop ? 46 : 40,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Explore mouthwatering cuisines from around the world and find your favorite dishes in seconds.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Paging Dots Indicator (• ── •)
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 28,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Center Hero Image: Enlarge pizza prominently
                      Expanded(
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ambient glow matching enlarged size
                              Container(
                                width: isDesktop ? 370 : 330,
                                height: isDesktop ? 370 : 330,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.38),
                                      blurRadius: 48,
                                      spreadRadius: 10,
                                      offset: const Offset(0, 18),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFFBF360C).withValues(alpha: 0.35),
                                      blurRadius: 36,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              // Enervated & Much Bigger Pizza Image
                              SizedBox(
                                width: isDesktop ? 380 : 340,
                                height: isDesktop ? 380 : 340,
                                child: Image.memory(
                                  base64Decode(PizzaImageAsset.pizzaBase64),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      child: const Icon(
                                        Icons.local_pizza_rounded,
                                        size: 100,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Action CTA: White capsule with "Get Started" and circular arrow button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamedAndRemoveUntil(context, "/home", (route) => false);
                          },
                          borderRadius: BorderRadius.circular(36),
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                const Spacer(flex: 2),
                                Text(
                                  "Get Started",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Spacer(flex: 2),
                                // Circular arrow button on right
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEE5430),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x40EE5430),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.north_east_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for subtle organic petal curves in the background
class _SubtlePetalWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    // Top Right petal/circle arc
    final path1 = Path();
    path1.addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.95, size.height * 0.15),
        radius: size.width * 0.45,
      ),
    );
    canvas.drawPath(path1, fillPaint);
    canvas.drawPath(path1, paint);

    // Left middle petal/circle arc
    final path2 = Path();
    path2.addOval(
      Rect.fromCircle(
        center: Offset(size.width * -0.15, size.height * 0.52),
        radius: size.width * 0.55,
      ),
    );
    canvas.drawPath(path2, fillPaint);
    canvas.drawPath(path2, paint);

    // Bottom right decorative accent
    final path3 = Path();
    path3.addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.75),
        radius: size.width * 0.35,
      ),
    );
    canvas.drawPath(path3, fillPaint);
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
