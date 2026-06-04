import 'package:image/image.dart';

/// Utility class for color operations, such as blending colors through alpha channels.
class ColorUtils {
  ColorUtils._(); // Private constructor to prevent instantiation

  /// Blends a foreground color over a background color using the foreground's alpha
  /// channel (Porter-Duff "source-over"). When the background is opaque, the result
  /// is also opaque (alpha = 255).
  static ColorUint8 blendColorsThroughForegroundAlpha(
    ColorUint8 foreground,
    ColorUint8 background,
  ) {
    final alpha = foreground.a / 255.0;
    final r = (foreground.r * alpha + background.r * (1 - alpha)).round();
    final g = (foreground.g * alpha + background.g * (1 - alpha)).round();
    final b = (foreground.b * alpha + background.b * (1 - alpha)).round();
    final a = (foreground.a + background.a * (1 - alpha)).round().clamp(0, 255);
    return ColorUint8.rgba(r, g, b, a);
  }

  /// Blends a foreground color with a background color using the foreground's alpha channel, and returns an opaque color (alpha = 255).
  static ColorUint8 makeOpaque(ColorUint8 color, {ColorUint8? background}) {
    if (color.a == 255) {
      return color; // Already opaque
    }
    var backgroundColor = background ?? ColorUint8.rgb(255, 255, 255);
    if (backgroundColor.a != 255) {
      // Build a fresh opaque background instead of mutating the caller's color.
      backgroundColor = ColorUint8.rgba(
        backgroundColor.r.toInt(),
        backgroundColor.g.toInt(),
        backgroundColor.b.toInt(),
        255,
      );
    }
    return blendColorsThroughForegroundAlpha(color, backgroundColor);
  }
}
