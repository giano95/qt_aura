"""Make the app's exercise images from Open Exercise Art drawings.

For each drawing id (a file name in third_party/open-exercise-art/svg, without
.svg) this writes two 512x512 PNGs that the app ships:
    assets/exercises/light/<id>.png   dark lines, for the light theme
    assets/exercises/dark/<id>.png    light lines, for the dark theme
The source PNGs (white lines on transparent, 1254 px) are downloaded from the
project on GitHub, or read from --from <folder> (e.g. a clone's png/ folder).

Usage (needs Pillow):
    python tools/exercise_images.py bench-press push-up ...
    python tools/exercise_images.py --from ../Open-Exercise-Art/png bench-press

After adding an image, set exercises.image to its id with a migration and add
nothing to CMakeLists.txt (it picks up every PNG in assets/exercises).
"""
import io
import os
import sys
import urllib.request

from PIL import Image

SIZE = 512
RAW = 'https://raw.githubusercontent.com/AlexMollard/Open-Exercise-Art/main/png/{}.png'
# Theme.text in light and dark mode (qml/theme/Theme.qml)
COLORS = {'light': (0x19, 0x1C, 0x1A), 'dark': (0xEB, 0xEF, 0xED)}
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'exercises')


def load(drawing, folder):
    if folder:
        return Image.open(os.path.join(folder, drawing + '.png'))
    with urllib.request.urlopen(RAW.format(drawing)) as r:
        return Image.open(io.BytesIO(r.read()))


def main(args):
    folder = None
    if args[:1] == ['--from']:
        folder, args = args[1], args[2:]
    if not args:
        sys.exit(__doc__)
    for drawing in args:
        alpha = load(drawing, folder).convert('RGBA').getchannel('A')
        alpha = alpha.resize((SIZE, SIZE), Image.LANCZOS)
        for theme, color in COLORS.items():
            out = Image.new('RGBA', (SIZE, SIZE), color + (0,))
            out.putalpha(alpha)
            os.makedirs(os.path.join(ROOT, theme), exist_ok=True)
            out.save(os.path.join(ROOT, theme, drawing + '.png'), optimize=True)
        print('ok', drawing)


if __name__ == '__main__':
    main(sys.argv[1:])
