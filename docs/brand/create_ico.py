"""
将 PNG 图标转换为 Windows ICO 格式
"""

from PIL import Image
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PNG_ICON = os.path.join(SCRIPT_DIR, "assets", "app-icons", "windows", "app_icon_256.png")
ICO_OUTPUT = os.path.join(SCRIPT_DIR, "assets", "app-icons", "windows", "app_icon.ico")

def create_ico():
    """创建 ICO 文件"""
    # 读取生成的 PNG 图标
    img = Image.open(PNG_ICON)

    # 保存为 ICO 文件（PIL 会自动处理多尺寸）
    img.save(ICO_OUTPUT, format='ICO')

    print(f"[OK] Created ICO file: {ICO_OUTPUT}")
    print(f"    Original size: {img.size}")

if __name__ == "__main__":
    create_ico()
