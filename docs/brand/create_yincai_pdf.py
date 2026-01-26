from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
import math

c = canvas.Canvas('Yincai_Brand_Design.pdf', pagesize=A4)
width, height = A4

DEEP_BLUE = HexColor('#0A2463')
EMERALD_GREEN = HexColor('#059669')
AMBER_ORANGE = HexColor('#F59E0B')
DARK_BG = HexColor('#141413')
LIGHT_BG = HexColor('#FAF9F5')

margin = 20 * mm

# === PAGE 1: COVER ===
# Background gradient
for i in range(100):
    gray_val = int(8 + 15 * (i/100)**0.7)
    c.setFillColorRGB(gray_val/255, gray_val/255, gray_val/255 + 0.03)
    c.rect(0, height * (1 - i/100), width, height/100, stroke=0, fill=1)

# Title - Chinese
title_y = height - 80*mm
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 64)
c.drawCentredString(width/2, title_y, u'\u9690\u8d22')

c.setFillColor(DEEP_BLUE)
c.setFont('Helvetica-Bold', 36)
c.drawCentredString(width/2, title_y - 42*mm, 'LocalFamily Asset')

c.setFillColorRGB(0.4, 0.4, 0.4)
c.setFont('Helvetica', 12)
c.drawCentredString(width/2, title_y - 65*mm, 'Cryptic Sanctuary Design System')

c.setFillColor(EMERALD_GREEN)
c.setFont('Helvetica-Oblique', 11)
c.drawCentredString(width/2, title_y - 85*mm, u'\u9690\u4e8e\u672c\u673a\uff0c\u8d22\u5728\u638c\u63e1')

# Large Logo
center_x = width/2
center_y = height/2 - 30*mm
radius = 45*mm

# Decorative circles
c.setStrokeColorRGB(0.85, 0.85, 0.85)
c.setLineWidth(0.3*mm)
for r in [radius + 8*mm, radius + 6*mm, radius + 4*mm]:
    c.circle(center_x, center_y, r, stroke=1, fill=0)

# Main hexagon
c.setFillColor(DEEP_BLUE)
c.setStrokeColor(DEEP_BLUE)
c.setLineWidth(2*mm)
hex_path = c.beginPath()
for i in range(7):
    angle = math.radians(30 + 60 * i)
    x = center_x + radius * math.cos(angle)
    y = center_y + radius * math.sin(angle)
    if i == 0:
        hex_path.moveTo(x, y)
    else:
        hex_path.lineTo(x, y)
hex_path.close()
c.drawPath(hex_path, fill=1, stroke=1)

# Inner shield
c.setFillColor(LIGHT_BG)
shield_path = c.beginPath()
scale = radius / (30*mm)
shield_pts = [
    (center_x, center_y - 20*mm*scale),
    (center_x - 12*mm*scale, center_y - 16*mm*scale),
    (center_x - 12*mm*scale, center_y + 7*mm*scale),
    (center_x, center_y + 16*mm*scale),
    (center_x + 12*mm*scale, center_y + 7*mm*scale),
    (center_x + 12*mm*scale, center_y - 16*mm*scale),
]
for i, (x, y) in enumerate(shield_pts):
    if i == 0:
        shield_path.moveTo(x, y)
    else:
        shield_path.lineTo(x, y)
shield_path.close()
c.drawPath(shield_path, fill=1, stroke=0)

# Lock
c.setFillColor(DEEP_BLUE)
lock_w = 9*mm * scale
lock_h = 8*mm * scale
c.rect(center_x - lock_w/2, center_y - lock_h/2, lock_w, lock_h, stroke=0, fill=1)

c.setStrokeColor(DEEP_BLUE)
c.setLineWidth(1.5*mm * scale)
c.arc(center_x, center_y, 4*mm * scale, 0, 180)

# Verification dot
c.setFillColor(EMERALD_GREEN)
c.circle(center_x, center_y - 24*mm*scale, 3*mm * scale, stroke=0, fill=1)

# Footer
c.setFillColorRGB(0.5, 0.5, 0.5)
c.setFont('Helvetica', 7)
c.drawCentredString(width/2, 40*mm, 'VERSION 1.0')
c.drawCentredString(width/2, 35*mm, u'\u9690\u8d1d (YINCAI) 2025')

c.showPage()

# === PAGE 2: COLOR SYSTEM ===
c.setFillColorRGB(0.98, 0.98, 0.96)
c.rect(0, 0, width, height, stroke=0, fill=1)

# Header
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 32)
c.drawString(margin, height - 55*mm, 'COLOR')
c.drawString(margin, height - 92*mm, 'SYSTEM')

c.setFillColorRGB(0.5, 0.5, 0.5)
c.setFont('Helvetica-Oblique', 11)
c.drawString(margin, height - 125*mm, 'The palette of trust and security')

# Color blocks
block_h = 80*mm
block_w = (width - 3*margin - 20*mm) / 3
start_y = height - 175*mm

# Deep Blue
c.setFillColor(DEEP_BLUE)
c.rect(margin, start_y - block_h, block_w, block_h, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica-Bold', 12)
c.drawCentredString(margin + block_w/2, start_y - block_h + 12*mm, 'DEEP BLUE')
c.setFont('Helvetica-Oblique', 9)
c.drawCentredString(margin + block_w/2, start_y - block_h + 26*mm, '#0A2463')
c.setFont('Helvetica', 8)
c.drawCentredString(margin + block_w/2, start_y - block_h + 45*mm, 'Primary')
c.drawCentredString(margin + block_w/2, start_y - block_h + 56*mm, 'Trust, Security')

# Emerald Green
c.setFillColor(EMERALD_GREEN)
c.rect(margin + block_w + 10*mm, start_y - block_h, block_w, block_h, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica-Bold', 12)
c.drawCentredString(margin + block_w + 10*mm + block_w/2, start_y - block_h + 12*mm, 'EMERALD')
c.setFont('Helvetica-Oblique', 9)
c.drawCentredString(margin + block_w + 10*mm + block_w/2, start_y - block_h + 26*mm, '#059669')
c.setFont('Helvetica', 8)
c.drawCentredString(margin + block_w + 10*mm + block_w/2, start_y - block_h + 45*mm, 'Accent')
c.drawCentredString(margin + block_w + 10*mm + block_w/2, start_y - block_h + 56*mm, 'Success, Growth')

# Amber Orange
c.setFillColor(AMBER_ORANGE)
c.rect(margin + (block_w + 10*mm) * 2, start_y - block_h, block_w, block_h, stroke=0, fill=1)
c.setFillColor(LIGHT_BG)
c.setFont('Helvetica-Bold', 12)
c.drawCentredString(margin + (block_w + 10*mm) * 2 + block_w/2, start_y - block_h + 12*mm, 'AMBER')
c.setFont('Helvetica-Oblique', 9)
c.drawCentredString(margin + (block_w + 10*mm) * 2 + block_w/2, start_y - block_h + 26*mm, '#F59E0B')
c.setFont('Helvetica', 8)
c.drawCentredString(margin + (block_w + 10*mm) * 2 + block_w/2, start_y - block_h + 45*mm, 'Warning')
c.drawCentredString(margin + (block_w + 10*mm) * 2 + block_w/2, start_y - block_h + 56*mm, 'Caution, Alert')

# Neutrals
gray_y = start_y - block_h - 35*mm
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 11)
c.drawString(margin, gray_y, 'NEUTRALS')

gray_block_w = (width - 2*margin - 12*mm) / 4
gray_block_h = 40*mm

grays = [('#141413', 'Dark'), ('#B0AEA5', 'Mid'), ('#E8E6DC', 'Light'), ('#FAF9F5', 'White')]

for i, (hex_val, name) in enumerate(grays):
    x = margin + i * (gray_block_w + 4*mm)
    color = HexColor(hex_val)
    c.setFillColor(color)
    c.rect(x, gray_y - 10*mm - gray_block_h, gray_block_w, gray_block_h, stroke=0, fill=1)
    c.setFillColor(DARK_BG if i < 2 else HexColor('#141413'))
    c.setFont('Helvetica', 7)
    c.drawCentredString(x + gray_block_w/2, gray_y - 10*mm - gray_block_h + 6*mm, name)
    c.setFont('Helvetica-Oblique', 6)
    c.drawCentredString(x + gray_block_w/2, gray_y - 10*mm - gray_block_h + 15*mm, hex_val)

c.setFillColorRGB(0.6, 0.6, 0.6)
c.setFont('Helvetica', 6)
c.drawCentredString(width/2, 30*mm, 'PAGE 02')

c.showPage()

# === PAGE 3: VISUAL ELEMENTS ===
c.setFillColorRGB(0.98, 0.98, 0.96)
c.rect(0, 0, width, height, stroke=0, fill=1)

# Header
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 32)
c.drawString(margin, height - 55*mm, 'VISUAL')
c.drawString(margin, height - 92*mm, 'ELEMENTS')

# Typography
type_y = height - 150*mm
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 15)
c.drawString(margin, type_y, 'TYPOGRAPHY')

c.setFont('Helvetica', 52)
c.drawString(margin, type_y - 28*mm, 'Aa')

c.setFont('Helvetica-Oblique', 10)
c.drawString(margin + 40*mm, type_y - 28*mm, 'Helvetica / Inter')
c.drawString(margin + 40*mm, type_y - 36*mm, 'Primary typeface for clarity')
c.drawString(margin + 40*mm, type_y - 44*mm, 'and professionalism')

# Chinese Typography
c.setFont('Helvetica-Bold', 15)
c.drawString(margin + 140*mm, type_y, u'\u4e2d\u6587')
c.setFont('Helvetica', 52)
c.drawString(margin + 140*mm, type_y - 28*mm, u'\u9690\u8d22')
c.setFont('Helvetica-Oblique', 10)
c.drawString(margin + 190*mm, type_y - 28*mm, 'Noto Sans CJK')

# Weights
weight_y = type_y - 65*mm
c.setFont('Helvetica-Bold', 11)
c.drawString(margin, weight_y, 'Bold 700      The quick brown fox')
c.setFont('Helvetica', 11)
c.drawString(margin, weight_y - 12*mm, 'Regular 400   The quick brown fox')

# Slogan section
slogan_y = weight_y - 45*mm
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 15)
c.drawString(margin, slogan_y, 'SLOGAN')

c.setFont('Helvetica-Bold', 14)
c.drawString(margin, slogan_y - 18*mm, u'\u9690\u4e8e\u672c\u673a\uff0c\u8d22\u5728\u638c\u63e1')
c.setFont('Helvetica-Oblique', 10)
c.drawString(margin, slogan_y - 32*mm, 'Hidden Local. Wealth in Control.')

# App Icon Sizes
icon_y = slogan_y - 55*mm
c.setFillColor(DARK_BG)
c.setFont('Helvetica-Bold', 15)
c.drawString(margin, icon_y, 'APP ICON')

icon_sizes = [(60*mm, 1.0), (48*mm, 0.8), (36*mm, 0.6), (24*mm, 0.4)]
icon_x = margin

for icon_sz, scale in icon_sizes:
    icon_bg_y = icon_y - 8*mm

    # Gradient background
    for j in range(25):
        factor = j / 25
        c.setFillColorRGB(
            DEEP_BLUE.red + (0.05 * factor),
            DEEP_BLUE.green + (0.03 * factor),
            DEEP_BLUE.blue + (0.08 * factor)
        )
        c.rect(icon_x, icon_bg_y - icon_sz + (icon_sz * j/25), icon_sz, icon_sz/25, stroke=0, fill=1)

    # Shield
    c.setFillColor(LIGHT_BG)
    shield_scale = 0.45 * scale
    shield_center_y = icon_bg_y - icon_sz/2
    shield_path = c.beginPath()
    shield_pts = [
        (icon_x + icon_sz/2, shield_center_y - 10*mm*shield_scale),
        (icon_x + icon_sz/2 - 7*mm*shield_scale, shield_center_y - 7*mm*shield_scale),
        (icon_x + icon_sz/2 - 7*mm*shield_scale, shield_center_y + 2*mm*shield_scale),
        (icon_x + icon_sz/2, shield_center_y + 6*mm*shield_scale),
        (icon_x + icon_sz/2 + 7*mm*shield_scale, shield_center_y + 2*mm*shield_scale),
        (icon_x + icon_sz/2 + 7*mm*shield_scale, shield_center_y - 7*mm*shield_scale),
    ]
    for j, (px, py) in enumerate(shield_pts):
        if j == 0:
            shield_path.moveTo(px, py)
        else:
            shield_path.lineTo(px, py)
    shield_path.close()
    c.drawPath(shield_path, fill=1, stroke=0)

    # Lock
    c.setFillColor(DEEP_BLUE)
    c.rect(icon_x + icon_sz/2 - 2.5*mm*shield_scale, shield_center_y - 1.5*mm*shield_scale,
           5*mm*shield_scale, 3*mm*shield_scale, stroke=0, fill=1)

    # Size label
    c.setFillColorRGB(0.5, 0.5, 0.5)
    c.setFont('Helvetica', 7)
    size_label = f'{int(icon_sz/mm*16)}px'
    c.drawCentredString(icon_x + icon_sz/2, icon_bg_y - icon_sz - 5*mm, size_label)

    icon_x += icon_sz + 12*mm

c.setFillColorRGB(0.6, 0.6, 0.6)
c.setFont('Helvetica', 6)
c.drawCentredString(width/2, 30*mm, 'PAGE 03')

c.save()
print('Yincai brand design PDF created: Yincai_Brand_Design.pdf')
