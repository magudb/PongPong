import io
import unittest
from PIL import Image
from crop_guide_refs import same_pixels


def png(image, compression):
    output = io.BytesIO()
    image.save(output, format="PNG", compress_level=compression)
    return output.getvalue()


class CropTests(unittest.TestCase):
    def test_recompression_preserves_the_reference(self):
        image = Image.new("RGB", (16, 16), (40, 80, 120))
        a, b = png(image, 0), png(image, 9)
        self.assertNotEqual(a, b)
        self.assertTrue(same_pixels(a, b))

    def test_changed_pixel_is_drift(self):
        image = Image.new("RGB", (16, 16), (40, 80, 120))
        original = png(image, 9)
        image.putpixel((8, 8), (41, 80, 120))
        self.assertFalse(same_pixels(original, png(image, 9)))

    def test_changed_dimensions_are_drift(self):
        self.assertFalse(same_pixels(png(Image.new("RGB", (16, 16)), 9), png(Image.new("RGB", (8, 32)), 9)))


if __name__ == "__main__":
    unittest.main()
