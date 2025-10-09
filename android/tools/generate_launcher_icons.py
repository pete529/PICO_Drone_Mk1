#### filepath: c:\Users\pete5\pico_code_projects\Drone_mk1\android\tools\generate_launcher_icons.py
from pathlib import Path

from PIL import Image

SOURCE = Path("app/src/main/res/mipmap-anydpi-v26/pete_drone_image.png")
OUTPUTS = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

def main():
    if not SOURCE.exists():
        raise FileNotFoundError(f"Base icon not found: {SOURCE}")
    base = Image.open(SOURCE).convert("RGBA")

    for folder, size in OUTPUTS.items():
        path = Path("app/src/main/res") / folder
        path.mkdir(parents=True, exist_ok=True)
        resized = base.resize((size, size), Image.LANCZOS)

        background = Image.new("RGBA", (size, size), (0, 0, 0, 255))
        background.paste(resized, (0, 0), resized)
        background.save(path / "ic_launcher.png")

        background.save(path / "ic_launcher_round.png")

        print(f"Wrote {path}/ic_launcher*.png ({size}x{size})")

if __name__ == "__main__":
    main()