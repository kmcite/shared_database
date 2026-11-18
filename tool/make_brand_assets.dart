// Generates brand assets: duotone black/white line-art database glyph.
// Run: dart run tool/make_brand_assets.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// ————— PNG encoder —————
final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  final typeBytes = ascii.encode(type);
  out.add(typeBytes);
  out.add(data);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  out.add(crc.buffer.asUint8List());
}

Uint8List encodePng(int w, int h, Uint8List rgba) {
  final out = BytesBuilder();
  // Signature
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  // IHDR
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());
  // IDAT: filter byte 0 per scanline
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  _chunk(out, 'IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes()));
  _chunk(out, 'IEND', const []);
  return out.takeBytes();
}

// ————— raster helpers —————
class Canvas {
  Canvas(this.w, this.h) : px = Uint8List(w * h * 4);
  final int w, h;
  final Uint8List px;

  void set(int x, int y, int r, int g, int b, [int a = 255]) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = (y * w + x) * 4;
    final sa = a / 255.0;
    final da = px[i + 3] / 255.0;
    final oa = sa + da * (1 - sa);
    if (oa <= 0) return;
    px[i] = ((r * sa + px[i] * da * (1 - sa)) / oa).round();
    px[i + 1] = ((g * sa + px[i + 1] * da * (1 - sa)) / oa).round();
    px[i + 2] = ((b * sa + px[i + 2] * da * (1 - sa)) / oa).round();
    px[i + 3] = (oa * 255).round();
  }

  void fillRect(int x0, int y0, int x1, int y1, List<int> c) {
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        set(x, y, c[0], c[1], c[2], c.length > 3 ? c[3] : 255);
      }
    }
  }

  /// Stroke an axis-aligned rectangle border of [thickness].
  void strokeRect(
      int x0, int y0, int x1, int y1, int t, List<int> c) {
    fillRect(x0, y0, x1, y0 + t - 1, c);
    fillRect(x0, y1 - t + 1, x1, y1, c);
    fillRect(x0, y0, x0 + t - 1, y1, c);
    fillRect(x1 - t + 1, y0, x1, y1, c);
  }

  /// Stroke an ellipse outline.
  void strokeEllipse(double cx, double cy, double rx, double ry,
      double thickness, List<int> c) {
    final x0 = (cx - rx - thickness).floor(), x1 = (cx + rx + thickness).ceil();
    final y0 = (cy - ry - thickness).floor(), y1 = (cy + ry + thickness).ceil();
    final inner = math.min(rx, ry);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        final d = (math.sqrt(dx * dx + dy * dy) - 1).abs() * inner;
        if (d <= thickness / 2) set(x, y, c[0], c[1], c[2], c[3]);
      }
    }
  }

  /// Vertical line segment.
  void vline(double x, double y0, double y1, double t, List<int> c) {
    final half = t / 2;
    for (var y = y0.floor(); y <= y1.ceil(); y++) {
      for (var xx = (x - half).floor(); xx <= (x + half).ceil(); xx++) {
        set(xx, y, c[0], c[1], c[2], c[3]);
      }
    }
  }

  /// Horizontal line segment.
  void hline(double y, double x0, double x1, double t, List<int> c) {
    final half = t / 2;
    for (var x = x0.floor(); x <= x1.ceil(); x++) {
      for (var yy = (y - half).floor(); yy <= (y + half).ceil(); yy++) {
        set(x, yy, c[0], c[1], c[2], c[3]);
      }
    }
  }
}

// ————— glyph —————
/// White line-art database cylinder, centered in a [size]² canvas.
void drawGlyph(Canvas cv, double cx, double cy, double scale) {
  const white = [255, 255, 255, 255];
  final rx = 230.0 * scale, ry = 58.0 * scale;
  final top = cy - 130.0 * scale, bottom = cy + 130.0 * scale;
  final t = 15.0 * scale;
  // Top + bottom ellipse rims
  cv.strokeEllipse(cx, top, rx, ry, t, white);
  cv.strokeEllipse(cx, bottom, rx, ry, t, white);
  // Side lines tangent to ellipse extremes
  cv.vline(cx - rx, top, bottom, t, white);
  cv.vline(cx + rx, top, bottom, t, white);
  // Inner detail: three short horizontal lines (database rows)
  final iw = rx * 0.52;
  for (var i = -1; i <= 1; i++) {
    cv.hline(cy + i * 52.0 * scale, cx - iw, cx + iw, t * 0.7, white);
  }
}

void main() {
  const size = 1024;
  const black = [5, 5, 5, 255];
  const splashBg = [15, 23, 42, 255]; // Brand.splashBackground #0F172A

  // 1) Launcher icon: black bg + white glyph
  final icon = Canvas(size, size);
  icon.fillRect(0, 0, size - 1, size - 1, black);
  drawGlyph(icon, size / 2, size / 2 + 10, 1.0);
  File('assets/app_icon.png')
      .writeAsBytesSync(encodePng(size, size, icon.px));

  // 2) Adaptive-icon foreground: transparent + glyph with padding
  final fg = Canvas(size, size);
  drawGlyph(fg, size / 2, size / 2 + 10, 0.72);
  File('assets/app_icon_fg.png')
      .writeAsBytesSync(encodePng(size, size, fg.px));

  // 3) Splash: brand navy bg + larger glyph
  final splash = Canvas(size, size);
  splash.fillRect(0, 0, size - 1, size - 1, splashBg);
  drawGlyph(splash, size / 2, size / 2 - 20, 0.95);
  File('assets/splash.png')
      .writeAsBytesSync(encodePng(size, size, splash.px));

  stdout.writeln('Wrote assets/app_icon.png, app_icon_fg.png, splash.png');
}
