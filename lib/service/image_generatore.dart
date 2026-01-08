import 'package:image/image.dart' as img;

class ImageGenerator {
  static img.Image generateTakeAwayStrip() {
    // Standard thermal printer width is about 576 pixels for 80mm paper
    const width = 576;
    const height = 80;

    // Create a black background image 
    // In image 3.x, constructor is Image(width, height)
    final strip = img.Image(width, height);
    
    // In image 3.x, colors are ints. img.getColor(r, g, b, [a])
    final black = img.getColor(0, 0, 0);
    final white = img.getColor(255, 255, 255);

    // img.fill(image, color)
    img.fill(strip, black);

    // In image 3.x, drawString(image, font, x, y, string, {color})
    // Fonts are usually img.arial_24 etc.
    img.drawString(
      strip,
      img.arial_24,
      (width - (9 * 14)) ~/ 2, // Centered (approximate width calculation)
      (height - 24) ~/ 2,
      'TAKE AWAY',
      color: white,
    );

    return strip;
  }
}
