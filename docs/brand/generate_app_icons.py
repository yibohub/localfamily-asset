"""
隐财 (Yincai) 品牌图标生成器

生成应用图标，包含：
- 六边形背景（象征稳定结构和安全防护）
- 内部盾牌（代表防御和保护）
- 锁图标（寓意加密安全）
- 底部绿点（表示验证通过和安全状态）
"""

from PIL import Image, ImageDraw
import math
import os

# 获取脚本所在目录的绝对路径
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "assets", "app-icons")

SIZES = {
    "ios": 1024,
    "android": 512,
    "windows": 256,
    "windows_128": 128,
    "favicon": 192,
    "favicon_large": 512,
}

# 品牌色（绿色系）
COLORS = {
    "green": (5, 150, 105),          # #059669 翡翠绿
    "green_dark": (3, 100, 70),      # 深绿变（渐变用）
    "green_light": (69, 187, 161),   # 浅绿变（高光用）
    "white": (255, 255, 255),
}

def draw_hexagon(draw, center, radius, color, rotation=30):
    """绘制六边形"""
    points = []
    for i in range(6):
        angle = math.radians(rotation + i * 60)
        x = center[0] + radius * math.cos(angle)
        y = center[1] + radius * math.sin(angle)
        points.append((x, y))

    # 绘制填充的六边形
    draw.polygon(points, fill=color)


def draw_shield(draw, center_x, center_y, width, height, color):
    """绘制盾牌"""
    half_w = width / 2
    top_y = center_y - height / 2
    bottom_y = center_y + height / 2

    points = []

    # 上边缘（稍微弯曲）
    for i in range(51):
        t = i / 50.0
        x = center_x - half_w + width * t
        y = top_y + 8 * math.sin(t * math.pi)
        points.append((x, y))

    # 右侧曲线
    for i in range(1, 31):
        t = i / 30.0
        x = center_x + half_w * (1 - t * 0.3)
        y = top_y + 8 + height * 0.4 * t
        points.append((x, y))

    # 底部尖角
    points.append((center_x, bottom_y))

    # 左侧曲线
    for i in range(1, 31):
        t = (30 - i) / 30.0
        x = center_x - half_w * (1 - t * 0.3)
        y = top_y + 8 + height * 0.4 * t
        points.append((x, y))

    if len(points) > 2:
        draw.polygon(points, fill=color)


def draw_lock(draw, center_x, center_y, width, height, color):
    """绘制锁图标"""
    half_w = width / 2
    lock_y = center_y - height / 2

    # 锁环参数
    shackle_width = width * 0.5
    shackle_height = height * 0.4
    shackle_thickness = width * 0.12

    # 绘制锁环（U形）
    shackle_y = lock_y
    draw.arc(
        [
            center_x - shackle_width / 2 - shackle_thickness / 2,
            shackle_y - shackle_height * 0.6,
            center_x + shackle_width / 2 + shackle_thickness / 2,
            shackle_y + shackle_height * 0.4,
        ],
        start=0,
        end=180,
        fill=color,
        width=int(shackle_thickness)
    )

    # 锁体
    body_height = height * 0.55
    body_y = lock_y + shackle_height * 0.2
    draw.rounded_rectangle(
        [
            center_x - half_w,
            body_y,
            center_x + half_w,
            body_y + body_height
        ],
        radius=int(shackle_thickness * 1.5),
        fill=color
    )

    # 钥匙孔
    hole_radius = width * 0.1
    hole_y = body_y + body_height * 0.35
    draw.ellipse(
        [
            center_x - hole_radius,
            hole_y - hole_radius,
            center_x + hole_radius,
            hole_y + hole_radius
        ],
        fill=COLORS["green_dark"]
    )

    # 钥匙孔下方线条
    draw.rectangle(
        [
            center_x - hole_radius * 0.4,
            hole_y,
            center_x + hole_radius * 0.4,
            hole_y + hole_radius * 2.5
        ],
        fill=COLORS["green_dark"]
    )


def create_app_icon(size):
    """
    创建应用图标

    设计：
    - 背景：翡翠绿渐变六边形
    - 主体：白色盾牌 + 锁图标
    - 底部：浅绿验证点
    """
    # 创建图像（透明背景）
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size // 2
    scale = size / 1024.0

    # 1. 绘制六边形背景（翡翠绿渐变）
    hex_radius = int(450 * scale)

    # 创建渐变效果的临时层
    hex_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hex_draw = ImageDraw.Draw(hex_img)

    # 绘制多层六边形模拟渐变
    layers = 30
    for i in range(layers):
        factor = i / layers
        radius = hex_radius * (1 - factor * 0.15)

        # 渐变色：从翡翠绿到深绿
        r = int(COLORS["green"][0] * (1 - factor * 0.4) + COLORS["green_dark"][0] * factor * 0.4)
        g = int(COLORS["green"][1] * (1 - factor * 0.4) + COLORS["green_dark"][1] * factor * 0.4)
        b = int(COLORS["green"][2] * (1 - factor * 0.4) + COLORS["green_dark"][2] * factor * 0.4)

        draw_hexagon(hex_draw, (center, center), radius, (r, g, b, 255))

    # 合并到主图像
    img = Image.alpha_composite(img, hex_img)
    draw = ImageDraw.Draw(img)

    # 添加内发光效果
    for i in range(10):
        alpha = int(15 * (1 - i / 10))
        glow_radius = hex_radius * (0.85 + i * 0.015)
        draw_hexagon(draw, (center, center), int(glow_radius), (*COLORS["green_light"], alpha))

    # 2. 绘制白色盾牌
    shield_width = int(380 * scale)
    shield_height = int(440 * scale)
    shield_y = center - int(40 * scale)

    draw_shield(draw, center, shield_y, shield_width, shield_height, COLORS["white"])

    # 3. 绘制锁图标
    lock_width = int(160 * scale)
    lock_height = int(140 * scale)
    lock_y = center + int(20 * scale)

    draw_lock(draw, center, lock_y, lock_width, lock_height, COLORS["white"])

    # 4. 绘制底部绿色验证点
    dot_radius = int(35 * scale)
    dot_y = shield_y + shield_height // 2 + int(80 * scale)

    # 外圈光晕
    for i in range(8, 0, -1):
        alpha = int(40 * (1 - i / 8))
        glow_radius = dot_radius + i * 6
        draw.ellipse(
            [
                center - glow_radius,
                dot_y - glow_radius * 0.6,
                center + glow_radius,
                dot_y + glow_radius * 0.6
            ],
            fill=(*COLORS["green_light"], alpha)
        )

    # 主圆点
    draw.ellipse(
        [
            center - dot_radius,
            dot_y - dot_radius * 0.6,
            center + dot_radius,
            dot_y + dot_radius * 0.6
        ],
        fill=COLORS["green_light"]
    )

    # 高光
    highlight_radius = dot_radius // 3
    draw.ellipse(
        [
            center - dot_radius * 0.5,
            dot_y - highlight_radius * 0.5,
            center - dot_radius * 0.2,
            dot_y + highlight_radius * 0.5
        ],
        fill=(255, 255, 255, 220)
    )

    return img


def generate_icons():
    """生成所有尺寸的图标"""
    # 创建输出目录
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(f"{OUTPUT_DIR}/ios", exist_ok=True)
    os.makedirs(f"{OUTPUT_DIR}/android", exist_ok=True)
    os.makedirs(f"{OUTPUT_DIR}/windows", exist_ok=True)
    os.makedirs(f"{OUTPUT_DIR}/favicon", exist_ok=True)

    print("[Yincai] Starting to generate brand icons...")

    # iOS
    print("[iOS] Generating icon (1024x1024)...")
    ios_icon = create_app_icon(SIZES["ios"])
    ios_icon.save(f"{OUTPUT_DIR}/ios/app_icon_1024.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/ios/app_icon_1024.png")

    # Android
    print("[Android] Generating icon (512x512)...")
    android_icon = create_app_icon(SIZES["android"])
    android_icon.save(f"{OUTPUT_DIR}/android/app_icon_512.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/android/app_icon_512.png")

    # Windows
    print("[Windows] Generating icon (256x256)...")
    windows_icon = create_app_icon(SIZES["windows"])
    windows_icon.save(f"{OUTPUT_DIR}/windows/app_icon_256.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/windows/app_icon_256.png")

    # Windows 128
    print("[Windows] Generating icon (128x128)...")
    windows_128_icon = create_app_icon(SIZES["windows_128"])
    windows_128_icon.save(f"{OUTPUT_DIR}/windows/app_icon_128.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/windows/app_icon_128.png")

    # Favicon
    print("[Favicon] Generating icon (192x192)...")
    favicon = create_app_icon(SIZES["favicon"])
    favicon.save(f"{OUTPUT_DIR}/favicon/favicon_192.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/favicon/favicon_192.png")

    # Favicon Large
    print("[Favicon] Generating large icon (512x512)...")
    favicon_large = create_app_icon(SIZES["favicon_large"])
    favicon_large.save(f"{OUTPUT_DIR}/favicon/favicon_512.png")
    print(f"  [OK] Saved: {OUTPUT_DIR}/favicon/favicon_512.png")

    print("\n[Done] All icons generated successfully!")
    print(f"[Dir] Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    generate_icons()
