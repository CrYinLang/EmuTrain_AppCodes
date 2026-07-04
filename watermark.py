#!/usr/bin/env python3
"""
批量图片水印工具
支持文字水印和图片水印，可自定义位置、透明度、大小等参数。
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


def get_images(input_dir: str, recursive: bool = False) -> list[Path]:
    """获取目录下所有图片文件"""
    extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.webp', '.tiff'}
    input_path = Path(input_dir)
    
    if not input_path.exists():
        print(f"❌ 输入目录不存在: {input_dir}")
        sys.exit(1)
    
    pattern = '**/*' if recursive else '*'
    images = [
        p for p in input_path.glob(pattern)
        if p.is_file() and p.suffix.lower() in extensions
    ]
    
    return sorted(images)


def get_position(image_size: tuple, wm_size: tuple, position: str, margin: int = 10) -> tuple:
    """根据位置名称计算水印坐标"""
    img_w, img_h = image_size
    wm_w, wm_h = wm_size
    
    positions = {
        'top-left':     (margin, margin),
        'top-right':    (img_w - wm_w - margin, margin),
        'bottom-left':  (margin, img_h - wm_h - margin),
        'bottom-right': (img_w - wm_w - margin, img_h - wm_h - margin),
        'center':       ((img_w - wm_w) // 2, (img_h - wm_h) // 2),
    }
    
    return positions.get(position, positions['bottom-right'])


def add_text_watermark(
    image: Image.Image,
    text: str,
    font_size: int = 36,
    color: tuple = (255, 255, 255),
    opacity: int = 128,
    position: str = 'bottom-right',
    margin: int = 10,
    font_path: str | None = None,
) -> Image.Image:
    """添加文字水印"""
    # 转换为 RGBA
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    
    # 创建水印层
    watermark = Image.new('RGBA', image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(watermark)
    
    # 加载字体
    try:
        if font_path and os.path.exists(font_path):
            font = ImageFont.truetype(font_path, font_size)
        else:
            # 尝试常见中文字体路径
            common_fonts = [
                'C:/Windows/Fonts/msyh.ttc',      # 微软雅黑
                'C:/Windows/Fonts/simhei.ttf',      # 黑体
                'C:/Windows/Fonts/simsun.ttc',      # 宋体
                '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
                '/System/Library/Fonts/PingFang.ttc',
            ]
            font = None
            for fp in common_fonts:
                if os.path.exists(fp):
                    font = ImageFont.truetype(fp, font_size)
                    break
            if font is None:
                font = ImageFont.load_default()
    except Exception:
        font = ImageFont.load_default()
    
    # 计算文字尺寸
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    
    # 计算位置
    pos = get_position(image.size, (text_w, text_h), position, margin)
    
    # 绘制文字（带透明度）
    fill = (*color[:3], opacity)
    draw.text(pos, text, font=font, fill=fill)
    
    # 合成
    return Image.alpha_composite(image, watermark)


def add_image_watermark(
    image: Image.Image,
    watermark_path: str,
    scale: float = 0.15,
    opacity: int = 128,
    position: str = 'bottom-right',
    margin: int = 10,
) -> Image.Image:
    """添加图片水印"""
    if image.mode != 'RGBA':
        image = image.convert('RGBA')
    
    # 加载水印图片
    wm = Image.open(watermark_path).convert('RGBA')
    
    # 缩放水印
    wm_width = int(image.width * scale)
    wm_height = int(wm.height * (wm_width / wm.width))
    wm = wm.resize((wm_width, wm_height), Image.Resampling.LANCZOS)
    
    # 调整透明度
    if opacity < 255:
        alpha = wm.split()[3]
        alpha = alpha.point(lambda p: int(p * opacity / 255))
        wm.putalpha(alpha)
    
    # 创建水印层
    watermark_layer = Image.new('RGBA', image.size, (0, 0, 0, 0))
    pos = get_position(image.size, wm.size, position, margin)
    watermark_layer.paste(wm, pos)
    
    return Image.alpha_composite(image, watermark_layer)


def process_images(
    input_dir: str,
    output_dir: str,
    text: str | None = None,
    watermark_image: str | None = None,
    font_size: int = 36,
    color: tuple = (255, 255, 255),
    opacity: int = 128,
    position: str = 'bottom-right',
    margin: int = 10,
    scale: float = 0.15,
    font_path: str | None = None,
    quality: int = 90,
    recursive: bool = False,
    suffix: str = '_wm',
) -> dict:
    """批量处理图片"""
    images = get_images(input_dir, recursive)
    
    if not images:
        print(f"⚠️  在 {input_dir} 中未找到图片文件")
        return {'total': 0, 'success': 0, 'failed': 0}
    
    # 创建输出目录
    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    
    print(f"📁 找到 {len(images)} 张图片")
    print(f"📂 输出目录: {output_dir}")
    print(f"{'=' * 50}")
    
    stats = {'total': len(images), 'success': 0, 'failed': 0, 'errors': []}
    
    for i, img_path in enumerate(images, 1):
        try:
            # 构建输出路径
            if recursive:
                rel = img_path.relative_to(input_dir)
                out_file = out_path / rel.parent / f"{rel.stem}{suffix}{rel.suffix}"
            else:
                out_file = out_path / f"{img_path.stem}{suffix}{img_path.suffix}"
            
            out_file.parent.mkdir(parents=True, exist_ok=True)
            
            # 打开图片
            img = Image.open(img_path)
            
            # 添加水印
            if text:
                img = add_text_watermark(
                    img, text, font_size, color, opacity, position, margin, font_path
                )
            
            if watermark_image:
                img = add_image_watermark(
                    img, watermark_image, scale, opacity, position, margin
                )
            
            # 保存（转回 RGB 以保存为 JPEG）
            save_kwargs = {}
            if img_path.suffix.lower() in ('.jpg', '.jpeg'):
                if img.mode == 'RGBA':
                    img = img.convert('RGB')
                save_kwargs['quality'] = quality
                save_kwargs['optimize'] = True
            elif img_path.suffix.lower() == '.png':
                save_kwargs['optimize'] = True
            elif img_path.suffix.lower() == '.webp':
                save_kwargs['quality'] = quality
            
            img.save(out_file, **save_kwargs)
            
            stats['success'] += 1
            size_kb = out_file.stat().st_size / 1024
            print(f"  ✅ [{i}/{len(images)}] {img_path.name} → {out_file.name} ({size_kb:.1f} KB)")
            
        except Exception as e:
            stats['failed'] += 1
            stats['errors'].append((str(img_path), str(e)))
            print(f"  ❌ [{i}/{len(images)}] {img_path.name}: {e}")
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description='批量图片水印工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 文字水印
  python watermark.py -i ./photos -o ./output -t "(c) 2026 MySite"
  
  # 图片水印
  python watermark.py -i ./photos -o ./output --logo logo.png
  
  # 自定义位置和透明度
  python watermark.py -i ./photos -o ./output -t "WATERMARK" --position center --opacity 80
  
  # 递归处理子目录
  python watermark.py -i ./photos -o ./output -t "(c) MySite" -r
        """
    )
    
    parser.add_argument('-i', '--input', required=True, help='输入图片目录')
    parser.add_argument('-o', '--output', required=True, help='输出目录')
    parser.add_argument('-t', '--text', help='文字水印内容')
    parser.add_argument('--logo', help='水印图片路径')
    parser.add_argument('--font-size', type=int, default=36, help='字体大小 (默认: 36)')
    parser.add_argument('--font-path', help='自定义字体文件路径')
    parser.add_argument('--color', default='255,255,255', help='文字颜色 R,G,B (默认: 255,255,255)')
    parser.add_argument('--opacity', type=int, default=128, help='透明度 0-255 (默认: 128)')
    parser.add_argument('--position', choices=['top-left', 'top-right', 'bottom-left', 'bottom-right', 'center'],
                        default='bottom-right', help='水印位置 (默认: bottom-right)')
    parser.add_argument('--margin', type=int, default=10, help='边距像素 (默认: 10)')
    parser.add_argument('--scale', type=float, default=0.15, help='图片水印缩放比例 (默认: 0.15)')
    parser.add_argument('--quality', type=int, default=90, help='输出图片质量 1-100 (默认: 90)')
    parser.add_argument('--suffix', default='_wm', help='输出文件名后缀 (默认: _wm)')
    parser.add_argument('-r', '--recursive', action='store_true', help='递归处理子目录')
    
    args = parser.parse_args()
    
    # 验证参数
    if not args.text and not args.logo:
        parser.error("请至少指定 --text 或 --logo 之一")
    
    if args.logo and not os.path.exists(args.logo):
        parser.error(f"水印图片不存在: {args.logo}")
    
    # 解析颜色
    try:
        color = tuple(int(c.strip()) for c in args.color.split(','))
        assert len(color) == 3 and all(0 <= c <= 255 for c in color)
    except (ValueError, AssertionError):
        parser.error("颜色格式错误，应为 R,G,B (0-255)")
    
    # 运行
    print("🖼️  批量图片水印工具")
    print(f"{'=' * 50}")
    
    stats = process_images(
        input_dir=args.input,
        output_dir=args.output,
        text=args.text,
        watermark_image=args.logo,
        font_size=args.font_size,
        color=color,
        opacity=args.opacity,
        position=args.position,
        margin=args.margin,
        scale=args.scale,
        font_path=args.font_path,
        quality=args.quality,
        recursive=args.recursive,
        suffix=args.suffix,
    )
    
    # 输出统计
    print(f"\n{'=' * 50}")
    print(f"📊 处理完成: 总计 {stats['total']} | 成功 {stats['success']} | 失败 {stats['failed']}")
    
    if stats['errors']:
        print("\n⚠️  失败详情:")
        for path, err in stats['errors']:
            print(f"   {path}: {err}")
    
    return 0 if stats['failed'] == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
