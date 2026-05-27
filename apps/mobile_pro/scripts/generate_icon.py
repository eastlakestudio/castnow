import os
from PIL import Image, ImageDraw

def create_app_icon():
    # 1. Create a 1024x1024 canvas
    width, height = 1024, 1024
    image = Image.new("RGBA", (width, height))
    draw = ImageDraw.Draw(image)

    # 2. Draw Background Gradient from #1E293B (top) to #020617 (bottom)
    # Slate 800: (30, 41, 59) -> Slate 950: (2, 6, 23)
    start_color = (30, 41, 59)
    end_color = (2, 6, 23)
    
    for y in range(height):
        ratio = y / float(height)
        r = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
        g = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
        b = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # 3. Draw faint border (faint white outline)
    # In SVG: x="10" y="10" width="492" height="492" rx="110" stroke-width="4"
    # Scaling to 1024x1024 (factor 2): x="20" y="20" width="984" height="984" rx="220" stroke-width="8"
    # Stroke opacity 0.1 -> rgba(255, 255, 255, 25)
    border_box = [20, 20, 1004, 1004]  # left, top, right, bottom
    draw.rounded_rectangle(border_box, radius=220, outline=(255, 255, 255, 25), width=8)

    # 4. Draw Bolt Gradient
    # In SVG: translate(128, 110)
    # Bolt Path: M 160 0 L 30 250 L 140 250 L 110 430 L 290 140 L 170 140 L 220 0 Z
    # Scaling factor is 2.
    # Let's adjust the bolt coordinates to be perfectly centered in the 1024x1024 box.
    # Original bolt bounding box: X: [30, 290] (width 260), Y: [0, 430] (height 430)
    # Under scale 2: X width is 520, Y height is 860.
    # To center:
    # X center: 1024/2 = 512. Since width is 520, X ranges from 512 - 260 = 252 to 512 + 260 = 772.
    # Original X relative to min X(30): (x - 30) * 2 + 252 = 2 * x + 192.
    # Y center: 1024/2 = 512. Since height is 860, Y ranges from 512 - 430 = 82 to 512 + 430 = 942.
    # Original Y relative to min Y(0): (y - 0) * 2 + 82 = 2 * y + 82.
    
    original_points = [
        (160, 0),
        (30, 250),
        (140, 250),
        (110, 430),
        (290, 140),
        (170, 140),
        (220, 0)
    ]
    
    scaled_points = []
    for x, y in original_points:
        scaled_x = int(2 * x + 192)
        scaled_y = int(2 * y + 82)
        scaled_points.append((scaled_x, scaled_y))

    # Let's create a separate mask image to draw the gradient onto the bolt polygon
    mask = Image.new("L", (width, height), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(scaled_points, fill=255)

    # Bolt gradient: #fbbf24 (251, 191, 36) to #d97706 (217, 119, 6)
    bolt_start_color = (251, 191, 36)
    bolt_end_color = (217, 119, 6)
    
    bolt_gradient = Image.new("RGBA", (width, height))
    bolt_gradient_draw = ImageDraw.Draw(bolt_gradient)
    
    for y in range(height):
        ratio = y / float(height)
        r = int(bolt_start_color[0] * (1 - ratio) + bolt_end_color[0] * ratio)
        g = int(bolt_start_color[1] * (1 - ratio) + bolt_end_color[1] * ratio)
        b = int(bolt_start_color[2] * (1 - ratio) + bolt_end_color[2] * ratio)
        bolt_gradient_draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

    # Paste the gradient bolt onto our main image using the mask
    image.paste(bolt_gradient, (0, 0), mask)

    # Save to the target path
    target_path = "/Users/minghualiu/personal/EastlakeStudio/castnow/apps/mobile_pro/assets/icon/icon_source_pro.png"
    # Ensure directory exists
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    image.save(target_path, "PNG")
    print(f"Successfully generated pixel-perfect premium icon at {target_path}")

if __name__ == "__main__":
    create_app_icon()
