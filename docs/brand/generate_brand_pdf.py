from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
import math

# 创建PDF
c = canvas.Canvas('LocalFamily_Asset_Brand_Design.pdf', pagesize=A4)
width, height = A4

# 品牌色彩
DEEP_BLUE = HexColor('#0A2463')
EMERALD_GREEN = HexColor('#059669')
AMBER_ORANGE = HexColor('#F59E0B')
MID_GRAY = HexColor('#B0AEA5')
DARK_BG = HexColor('#141413')
LIGHT_BG = HexColor('#FAF9F5')

# 页面边距
margin = 20 * mm

# ===== 封面区域 =====
# 背景渐变效果
for i in range(100):
    gray_val = int(10 + 10 * i/100)
    c.setFillColorRGB(gray_val/255, gray_val/255, gray_val/255 + 0.02)
    c.rect(0, height * (1 - i/100), width, height/100, stroke=0, fill=1)

# 主标题
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 46)
title_y = height - 75*mm
c.drawCentredString(width/2, title_y, 'LOCALFAMILY')

c.setFillColor(DEEP_BLUE)
c.setFont('Helvetica-Bold', 32)
c.drawCentredString(width/2, title_y - 32*mm, 'ASSET')

# 副标题
c.setFillColor(MID_GRAY)
c.setFont('Helvetica', 12)
c.drawCentredString(width/2, title_y - 50*mm, 'Cryptic Sanctuary')

# Slogan
c.setFillColor(EMERALD_GREEN)
c.setFont('Helvetica-Oblique', 11)
c.drawCentredString(width/2, title_y - 68*mm, 'Family Wealth. Secure Control.')

# ===== Logo 概念展示 =====
logo_y = title_y - 110*mm

# 外圈六边形
c.setFillColor(DEEP_BLUE)
c.setStrokeColor(DEEP_BLUE)
c.setLineWidth(2)

center_x = width/2
center_y = logo_y
hex_radius = 32*mm

# 绘制六边形
path = c.beginPath()
for i in range(7):
    angle = math.radians(30 + 60 * i)
    x = center_x + hex_radius * math.cos(angle)
    y = center_y + hex_radius * math.sin(angle)
    if i == 0:
        path.moveTo(x, y)
    else:
        path.lineTo(x, y)
path.close()
c.drawPath(path, fill=1, stroke=1)

# 内部盾牌形状
c.setFillColor(LIGHT_BG)
shield_y_offset = center_y
shield_path = c.beginPath()
shield_pts = [
    (center_x, shield_y_offset - 22*mm),
    (center_x - 13*mm, shield_y_offset - 18*mm),
    (center_x - 13*mm, shield_y_offset + 8*mm),
    (center_x, shield_y_offset + 18*mm),
    (center_x + 13*mm, shield_y_offset + 8*mm),
    (center_x + 13*mm, shield_y_offset - 18*mm),
]
for i, (x, y) in enumerate(shield_pts):
    if i == 0:
        shield_path.moveTo(x, y)
    else:
        shield_path.lineTo(x, y)
shield_path.close()
c.drawPath(shield_path, fill=1, stroke=0)

# 锁图标主体
c.setFillColor(DEEP_BLUE)
lock_body_x = center_x - 5*mm
lock_body_y = shield_y_offset
c.rect(lock_body_x, lock_body_y, 10*mm, 9*mm, stroke=0, fill=1)

# 锁环（使用 arc 方法）
c.setStrokeColor(DEEP_BLUE)
c.setLineWidth(1.8*mm)
from reportlab.lib.utils import simpleSplit
c.arc(center_x, lock_body_y + 4.5*mm, 4.5*mm, 0, 180)

# 验证点
c.setFillColor(EMERALD_GREEN)
c.circle(center_x, shield_y_offset - 26*mm, 3.5*mm, stroke=0, fill=1)

# ===== 色彩系统展示 =====
color_y = logo_y - 75*mm

c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 14)
c.drawString(margin, color_y, 'COLOR SYSTEM')

color_block_width = (width - 2*margin - 20*mm) / 3
color_start_x = margin
color_block_y = color_y - 12*mm
color_height = 45*mm

# 深海蓝
c.setFillColor(DEEP_BLUE)
c.rect(color_start_x, color_block_y - color_height, color_block_width, color_height, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica', 9)
c.drawCentredString(color_start_x + color_block_width/2, color_block_y - color_height + 4*mm, 'DEEP BLUE')
c.setFont('Helvetica-Oblique', 7)
c.drawCentredString(color_start_x + color_block_width/2, color_block_y - color_height + 13*mm, '#0A2463')

# 翡翠绿
c.setFillColor(EMERALD_GREEN)
c.rect(color_start_x + color_block_width + 10*mm, color_block_y - color_height, color_block_width, color_height, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica', 9)
c.drawCentredString(color_start_x + color_block_width + 10*mm + color_block_width/2, color_block_y - color_height + 4*mm, 'EMERALD')
c.setFont('Helvetica-Oblique', 7)
c.drawCentredString(color_start_x + color_block_width + 10*mm + color_block_width/2, color_block_y - color_height + 13*mm, '#059669')

# 琥珀橙
c.setFillColor(AMBER_ORANGE)
c.rect(color_start_x + (color_block_width + 10*mm) * 2, color_block_y - color_height, color_block_width, color_height, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica', 9)
c.drawCentredString(color_start_x + (color_block_width + 10*mm) * 2 + color_block_width/2, color_block_y - color_height + 4*mm, 'AMBER')
c.setFont('Helvetica-Oblique', 7)
c.drawCentredString(color_start_x + (color_block_width + 10*mm) * 2 + color_block_width/2, color_block_y - color_height + 13*mm, '#F59E0B')

# ===== 应用图标概念 =====
icon_y = color_block_y - color_height - 25*mm

c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 14)
c.drawString(margin, icon_y, 'APP ICON')

# iOS 风格图标
icon_size = 55*mm
icon_x = (width - icon_size) / 2
icon_bg_y = icon_y - 8*mm

# 背景
c.setFillColor(DEEP_BLUE)
c.roundRect(icon_x, icon_bg_y - icon_size, icon_size, icon_size, 11*mm, stroke=0, fill=1)

# 内部盾牌
c.setFillColor(LIGHT_BG)
shield_scale = 0.65
shield_inner_y = icon_bg_y - icon_size/2
shield_inner_path = c.beginPath()
shield_inner_pts = [
    (width/2, shield_inner_y - 16*mm * shield_scale),
    (width/2 - 11*mm * shield_scale, shield_inner_y - 13*mm * shield_scale),
    (width/2 - 11*mm * shield_scale, shield_inner_y + 5*mm * shield_scale),
    (width/2, shield_inner_y + 12*mm * shield_scale),
    (width/2 + 11*mm * shield_scale, shield_inner_y + 5*mm * shield_scale),
    (width/2 + 11*mm * shield_scale, shield_inner_y - 13*mm * shield_scale),
]
for i, (x, y) in enumerate(shield_inner_pts):
    if i == 0:
        shield_inner_path.moveTo(x, y)
    else:
        shield_inner_path.lineTo(x, y)
shield_inner_path.close()
c.drawPath(shield_inner_path, fill=1, stroke=0)

# 锁
c.setFillColor(DEEP_BLUE)
inner_lock_x = width/2 - 4.5*mm * shield_scale
inner_lock_y = shield_inner_y
c.rect(inner_lock_x, inner_lock_y, 9*mm * shield_scale, 7*mm * shield_scale, stroke=0, fill=1)
c.setStrokeColor(DEEP_BLUE)
c.setLineWidth(1.3*mm * shield_scale)
c.arc(width/2, inner_lock_y + 3.5*mm * shield_scale, 3.5*mm * shield_scale, 0, 180)

# ===== 字体系统 =====
font_y = icon_bg_y - icon_size - 25*mm

c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 14)
c.drawString(margin, font_y, 'TYPOGRAPHY')

c.setFont('Helvetica', 22)
c.drawString(margin, font_y - 18*mm, 'Aa')
c.setFont('Helvetica-Oblique', 9)
c.drawString(margin + 18*mm, font_y - 18*mm, 'Primary: Inter / Helvetica')
c.drawString(margin + 18*mm, font_y - 23*mm, 'Weights: Regular 400, Medium 500, Bold 700')

# ===== 底部信息 =====
footer_y = 35*mm
c.setFillColor(MID_GRAY)
c.setFont('Helvetica', 7)
c.drawCentredString(width/2, footer_y, 'DESIGN SYSTEM V1.0')
c.drawCentredString(width/2, footer_y - 4*mm, 'LOCALFAMILY ASSET © 2025')

c.save()
print('品牌设计 PDF 已生成: LocalFamily_Asset_Brand_Design.pdf')
