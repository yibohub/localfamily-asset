"""
隐财 (Yincai) 高质量品牌图标生成器

使用 SVG 矢量图形生成高质量图标
"""

from PIL import Image, ImageDraw
import math
import os

# 获取脚本所在目录的绝对路径
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "assets", "app-icons")

# 品牌色
COLORS = {
    "deep_blue_start": (15, 45, 100),   # 浅蓝渐变起点
    "deep_blue_end": (10, 36, 99),      # 深海蓝
    "white": (255, 255, 255),
    "green": (5, 150, 105),             # 翡翠绿
    "green_light": (102, 187, 106),     # 浅绿高光
    "shadow": (0, 0, 0, 80),           # 阴影
}

def draw_smooth_ellipse(draw, bbox, color):
    """绘制平滑椭圆"""
    draw.ellipse(bbox, fill=color)

def draw_shield_path(draw, cx, cy, width, height, color):
    """绘制盾牌路径"""
    points = []
    half_w = width / 2
    top_y = cy - height / 2
    bottom_y = cy + height / 2

    # 上边缘
    for i in range(51):
        t = i / 50.0
        x = cx - half_w + width * t
        # 上边缘曲线
        y = top_y + 5 * math.sin(t * math.pi)
        points.append((x, y))

    # 右侧曲线
    for i in range(1, 31):
        t = i / 30.0
        x = cx + half_w * (1 - t * 0.3)
        y = top_y + 5 + height * 0.4 * t
        points.append((x, y))

    # 底部尖角
    points.append((cx, bottom_y))

    # 左侧曲线
    for i in range(1, 31):
        t = (30 - i) / 30.0
        x = cx - half_w * (1 - t * 0.3)
        y = top_y + 5 + height * 0.4 * t
        points.append((x, y))

    if len(points) > 2:
        draw.polygon(points, fill=color)

def create_quality_icon(size):
    """创建高质量图标"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size // 2
    scale = size / 1024.0

    # 1. 绘制渐变背景
    for y in range(size):
        t = y / size
        # 垂直渐变：从上到下
        r = int(COLORS["deep_blue_start"][0] * (1 - t * 0.3) + COLORS["deep_blue_end"][0] * t * 0.3)
        g = int(COLORS["deep_blue_start"][1] * (1 - t * 0.3) + COLORS["deep_blue_end"][1] * t * 0.3)
        b = int(COLORS["deep_blue_start"][2] * (1 - t * 0.3) + COLORS["deep_blue_end"][2] * t * 0.3)
        draw.rectangle([(0, y), (size - 1, y)], fill=(r, g, b))

    # 圆角裁剪
    from PIL import ImageFilter
    corner = size * 0.22

    # 创建圆角遮罩
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(2, 2), (size - 3, size - 3)], radius=int(corner), fill=255)

    # 应用遮罩
    img_rgba = img.convert('RGBA')
    r, g, b, a = img_rgba.split()

    # 将遮罩作为 alpha 通道
    a_new = mask.point(lambda p: p)
    img = Image.merge('RGBA', (r, g, b, a_new))
    draw = ImageDraw.Draw(img)

    # 2. 绘制盾牌（简化版，使用多边形）
    shield_w = int(380 * scale)
    shield_h = int(460 * scale)
    shield_y = center - shield_h // 2 - int(20 * scale)

    # 绘制盾牌轮廓
    shield_points = []
    half_w = shield_w // 2
    top_y = shield_y
    bottom_y = shield_y + shield_h

    # 上边缘
    for i in range(21):
        x = (center - half_w) + int(shield_w * i / 20.0)
        y = top_y + int(8 * math.sin(i / 20.0 * math.pi))
        shield_points.append((x, y))

    # 右侧
    shield_points.append((center + half_w, top_y + int(shield_h * 0.35)))
    shield_points.append((center, bottom_y))
    shield_points.append((center - half_w, top_y + int(shield_h * 0.35)))

    draw.polygon(shield_points, fill=COLORS["white"])

    # 3. 绘制锁图标
    lock_w = int(180 * scale)
    lock_h = int(160 * scale)
    lock_x = center - lock_w // 2
    lock_y = center - lock_h // 2 + int(30 * scale)

    # 锁环
    shackle_w = int(90 * scale)
    shackle_h = int(70 * scale)
    shackle_thick = int(16 * scale)

    shackle_x = center - shackle_w // 2
    shackle_y = lock_y - int(shackle_h * 0.4)

    # 锁环（U形，用椭圆模拟）
    draw.ellipse(
        [center - shackle_w // 2 - shackle_thick // 2,
         shackle_y,
         center + shackle_w // 2 + shackle_thick // 2,
         shackle_y + shackle_h],
        outline=COLORS["white"],
        width=shackle_thick
    )

    # 锁体
    body_h = int(100 * scale)
    body_y = lock_y + int(shackle_h * 0.25)
    draw.rounded_rectangle(
        [lock_x, body_y, lock_x + lock_w, body_y + body_h],
        radius=int(shackle_thick * 1.5),
        fill=COLORS["white"]
    )

    # 钥匙孔
    hole_r = int(18 * scale)
    hole_y = body_y + body_h // 3
    draw.ellipse(
        [center - hole_r, hole_y - hole_r,
         center + hole_r, hole_y + hole_r],
        fill=COLORS["deep_blue_end"]
    )
    draw.rectangle(
        [center - hole_r // 2, hole_y,
         center + hole_r // 2, hole_y + int(hole_r * 2)],
        fill=COLORS["deep_blue_end"]
    )

    # 4. 绘制底部绿点
    dot_r = int(32 * scale)
    dot_y = shield_y + shield_h + int(25 * scale)

    # 外圈光晕
    for i in range(5, 0, -1):
        alpha = 30 - i * 5
        r_glow = dot_r + i * 4
        draw.ellipse(
            [center - r_glow, dot_y - r_glow // 2,
             center + r_glow, dot_y + r_glow // 2],
            fill=(*COLORS["green"], alpha)
        )

    # 主圆
    draw.ellipse(
        [center - dot_r, dot_y - dot_r // 2,
         center + dot_r, dot_y + dot_r // 2],
        fill=COLORS["green"]
    )

    # 高光
    highlight_r = dot_r // 3
    draw.ellipse(
        [center - dot_r + highlight_r // 2, dot_y - highlight_r // 2,
         center - dot_r + highlight_r * 1.5, dot_y + highlight_r // 2],
        fill=(255, 255, 255, 200)
    )

    return img

def generate_icons():
    """生成所有尺寸图标"""
    sizes = {
        "ios": 1024,
        "android": 512,
        "windows": 256,
        "windows_ico": 128,  # ICO 格式用
        "favicon": 192,
        "favicon_large": 512,
    }

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(os.path.join(OUTPUT_DIR, "ios"), exist_ok=True)
    os.makedirs(os.path.join(OUTPUT_DIR, "android"), exist_ok=True)
    os.makedirs(os.path.join(OUTPUT_DIR, "windows"), exist_ok=True)
    os.makedirs(os.path.join(OUTPUT_DIR, "favicon"), exist_ok=True)

    print("[Yincai] Generating high-quality brand icons...")

    for name, size in sizes.items():
        print(f"[{name.upper()}] Creating {size}x{size} icon...")
        icon = create_quality_icon(size)

        if name == "ios":
            path = os.path.join(OUTPUT_DIR, "ios", "app_icon_1024.png")
        elif name == "android":
            path = os.path.join(OUTPUT_DIR, "android", "app_icon_512.png")
        elif name.startswith("windows"):
            basename = f"app_icon_{size}.png"
            path = os.path.join(OUTPUT_DIR, "windows", basename)
        elif name == "favicon":
            path = os.path.join(OUTPUT_DIR, "favicon", "favicon_192.png")
        else:
            path = os.path.join(OUTPUT_DIR, "favicon", "favicon_512.png")

        icon.save(path)
        print(f"  [OK] {os.path.basename(path)}")

    print("\n[Done] All icons generated!")
    print(f"[Dir] {OUTPUT_DIR}")

if __name__ == "__main__":
    generate_icons()
