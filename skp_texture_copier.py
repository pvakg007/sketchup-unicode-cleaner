#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SketchUp .skp 材质贴图复制工具
功能：
1. 解析 .skp 文件内部的 material.xml 数据
2. 提取所有贴图文件路径
3. 复制贴图到 textures 目录
4. 重命名非 UTF-8 字符的文件名
5. 更新 .skp 文件中的贴图路径

使用方法：python skp_texture_copier.py <skp文件路径>
"""

import os
import re
import shutil
import struct
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict
import unicodedata


# 拼音转换表（常用汉字）
PINYIN_TABLE = {
    # 材质相关
    '贴': 'tie', '图': 'tu', '材': 'cai', '质': 'zhi',
    '木': 'mu', '石': 'shi', '砖': 'zhuan', '瓦': 'wa',
    '板': 'ban', '块': 'kuai', '片': 'pian', '层': 'ceng',
    '面': 'mian', '纹': 'wen', '理': 'li', '漆': 'qi',
    # 颜色
    '红': 'hong', '橙': 'cheng', '黄': 'huang', '绿': 'lv',
    '青': 'qing', '蓝': 'lan', '紫': 'zi', '白': 'bai',
    '黑': 'hei', '灰': 'hui', '褐': 'he', '棕': 'zong',
    '金': 'jin', '银': 'yin', '铜': 'tong',
    # 建筑
    '地': 'di', '墙': 'qiang', '顶': 'ding', '门': 'men',
    '窗': 'chuang', '柱': 'zhu', '梁': 'liang',
    # 常用字
    '大': 'da', '小': 'xiao', '新': 'xin', '旧': 'jiu',
    '上': 'shang', '下': 'xia', '左': 'zuo', '右': 'you',
    '前': 'qian', '后': 'hou', '中': 'zhong', '外': 'wai',
}

# 支持的贴图文件扩展名
TEXTURE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.hdr', '.exr']


def convert_to_ascii(filename):
    """将文件名中的非ASCII字符转换为拼音或hex编码"""
    name, ext = os.path.splitext(filename)

    result = []
    for char in name:
        if char.isascii():
            result.append(char)
        elif char in PINYIN_TABLE:
            result.append(PINYIN_TABLE[char])
        else:
            # 使用 hex 编码
            result.append(f'u{ord(char):04x}')

    converted = '_'.join(result).lower()
    # 清理多余下划线
    converted = re.sub(r'_+', '_', converted).strip('_')

    return converted + ext.lower()


def needs_conversion(filename):
    """检查文件名是否需要转换"""
    try:
        filename.encode('utf-8')
        # 检查是否包含非ASCII字符
        for char in filename:
            if not char.isascii():
                return True
        return False
    except UnicodeEncodeError:
        return True


def find_texture_files_in_string(content):
    """在字符串内容中查找所有贴图文件路径"""
    texture_paths = []

    # 构建正则表达式匹配贴图文件
    ext_pattern = '|'.join(TEXTURE_EXTENSIONS)
    # 匹配各种路径格式
    patterns = [
        # Windows 路径: C:\path\file.jpg 或 D:/path/file.png
        r'[A-Za-z]:[\\/][^<>"\n\r]*?(' + ext_pattern + ')',
        # 相对路径: path/file.jpg 或 ./path/file.png
        r'[^\s<>"\n\r]+[\\/][^\s<>"\n\r]*?(' + ext_pattern + ')',
        # 文件名: filename.jpg (不带路径但可能是嵌入的)
        r'[^\s<>"\n\r\\/]+(' + ext_pattern + ')',
    ]

    for pattern in patterns:
        matches = re.findall(pattern, content, re.IGNORECASE)
        for match in matches:
            # match 可能是完整路径或者只是扩展名
            if isinstance(match, tuple):
                full_path = match[0] if match[0] else match[1]
            else:
                full_path = match

            # 清理路径
            full_path = full_path.strip()
            if full_path and len(full_path) > 3:
                texture_paths.append(full_path)

    return texture_paths


def extract_material_xml_content(skp_path):
    """
    从 .skp 文件中提取所有 MaterialXML 内容
    返回包含 MaterialXML 数据的列表，每个元素包含：
    - 原始位置（偏移量）
    - XML 内容
    """
    material_xmls = []

    with open(skp_path, 'rb') as f:
        content = f.read()

    # 尝试解码为 UTF-8
    try:
        text_content = content.decode('utf-8', errors='ignore')
    except:
        text_content = content.decode('latin-1', errors='ignore')

    # 查找所有 MaterialXML 属性块
    # Pattern: <n0:Attribute key="MaterialXML" type="10">...content...</n0:Attribute>
    pattern = r'<n0:Attribute\s+key="MaterialXML"\s+type="10">(.*?)</n0:Attribute>'
    matches = re.finditer(pattern, text_content, re.DOTALL | re.IGNORECASE)

    for match in matches:
        start_pos = match.start()
        end_pos = match.end()
        xml_content = match.group(1)

        material_xmls.append({
            'start': start_pos,
            'end': end_pos,
            'content': xml_content,
            'full_match': match.group(0)
        })

    print(f"找到 {len(material_xmls)} 个 MaterialXML 属性块")

    return material_xmls, text_content, content


def parse_texture_paths_from_xml(xml_content):
    """从 MaterialXML 内容中解析贴图路径"""
    texture_info = []

    # 在 XML 内容中查找贴图文件引用
    # 可能的格式：
    # - 直接路径引用
    # - XML 属性中的路径
    # - 嵌入的材质定义

    # 查找贴图文件路径
    texture_paths = find_texture_files_in_string(xml_content)

    for path in texture_paths:
        filename = os.path.basename(path)
        texture_info.append({
            'original_path': path,
            'filename': filename,
            'needs_rename': needs_conversion(filename)
        })

    return texture_info


def find_texture_file_on_disk(original_path, search_dirs):
    """在磁盘上查找贴图文件"""
    # 首先尝试原始路径
    if os.path.exists(original_path):
        return original_path

    # 获取文件名
    filename = os.path.basename(original_path)

    # 在搜索目录中查找
    for search_dir in search_dirs:
        # 检查直接路径
        candidate = os.path.join(search_dir, filename)
        if os.path.exists(candidate):
            return candidate

        # 递归搜索
        for root, dirs, files in os.walk(search_dir):
            for file in files:
                if file.lower() == filename.lower():
                    return os.path.join(root, file)

    return None


def copy_texture_with_rename(src_path, textures_dir, used_names):
    """复制贴图文件并根据需要重命名"""
    filename = os.path.basename(src_path)

    # 检查是否需要重命名
    if needs_conversion(filename):
        new_filename = convert_to_ascii(filename)
    else:
        new_filename = filename

    # 处理同名冲突
    base_name, ext = os.path.splitext(new_filename)
    counter = 1
    while new_filename in used_names:
        new_filename = f"{base_name}_{counter}{ext}"
        counter += 1

    used_names[new_filename] = True

    # 目标路径
    dst_path = os.path.join(textures_dir, new_filename)

    # 复制文件
    shutil.copy2(src_path, dst_path)

    return new_filename, dst_path


def update_skp_file(skp_path, replacements, original_content, original_binary):
    """
    更新 .skp 文件中的贴图路径
    replacements: list of {old_path, new_path, old_filename, new_filename}
    """
    # 创建新内容
    new_content = original_content

    for repl in replacements:
        old_path = repl['old_path']
        new_path = repl['new_path']
        old_filename = repl['old_filename']
        new_filename = repl['new_filename']

        # 替换完整路径
        if old_path in new_content:
            new_content = new_content.replace(old_path, new_path)

        # 替换文件名
        if old_filename in new_content and old_filename != new_filename:
            new_content = new_content.replace(old_filename, new_filename)

    # 编码回二进制
    try:
        new_binary = new_content.encode('utf-8')
    except:
        new_binary = new_content.encode('latin-1', errors='replace')

    # 保存文件
    base, ext = os.path.splitext(skp_path)
    backup_path = base + '_backup' + ext
    if not os.path.exists(backup_path):
        shutil.copy2(skp_path, backup_path)
        print(f"已创建备份: {backup_path}")

    with open(skp_path, 'wb') as f:
        f.write(new_binary)

    print(f"已更新 .skp 文件: {skp_path}")


def process_skp_file(skp_path, search_dirs=None):
    """处理 .skp 文件，复制并重命名贴图"""
    print(f"\n处理文件: {skp_path}")
    print("=" * 60)

    skp_dir = os.path.dirname(os.path.abspath(skp_path))
    textures_dir = os.path.join(skp_dir, 'textures')

    # 创建 textures 目录
    if not os.path.exists(textures_dir):
        os.makedirs(textures_dir)
        print(f"创建目录: {textures_dir}")

    # 确定搜索目录
    if search_dirs is None:
        search_dirs = [
            skp_dir,  # skp 文件所在目录
            os.path.dirname(skp_dir),  # 上级目录
        ]
        # 添加常见贴图目录
        common_dirs = [
            os.path.expanduser('~'),
            os.path.join(os.path.expanduser('~'), 'Documents'),
            os.path.join(os.path.expanduser('~'), 'Downloads'),
        ]
        search_dirs.extend([d for d in common_dirs if os.path.exists(d)])

    # 提取 MaterialXML 内容
    material_xmls, text_content, binary_content = extract_material_xml_content(skp_path)

    if not material_xmls:
        print("未找到 MaterialXML 内容，尝试搜索整个文件中的贴图引用...")
        # 直接在文件内容中搜索贴图路径
        all_texture_paths = find_texture_files_in_string(text_content)
        texture_info = []
        for path in all_texture_paths:
            filename = os.path.basename(path)
            texture_info.append({
                'original_path': path,
                'filename': filename,
                'needs_rename': needs_conversion(filename)
            })
    else:
        # 从所有 MaterialXML 块中提取贴图信息
        texture_info = []
        for xml_block in material_xmls:
            paths = parse_texture_paths_from_xml(xml_block['content'])
            texture_info.extend(paths)

    # 去重
    unique_textures = {}
    for info in texture_info:
        key = info['original_path']
        if key not in unique_textures:
            unique_textures[key] = info

    print(f"\n发现 {len(unique_textures)} 个贴图引用")

    # 复制贴图文件
    used_names = {}
    replacements = []
    results = {
        'copied': [],
        'renamed': [],
        'not_found': [],
        'errors': []
    }

    for path, info in unique_textures.items():
        filename = info['filename']

        # 查找源文件
        src_path = find_texture_file_on_disk(path, search_dirs)

        if src_path:
            try:
                # 复制并重命名
                new_filename, dst_path = copy_texture_with_rename(
                    src_path, textures_dir, used_names
                )

                rel_path = os.path.relpath(dst_path, skp_dir)
                # 使用相对路径或统一路径格式
                new_path = f"textures/{new_filename}"

                replacements.append({
                    'old_path': path,
                    'new_path': new_path,
                    'old_filename': filename,
                    'new_filename': new_filename
                })

                if info['needs_rename']:
                    results['renamed'].append({
                        'original': filename,
                        'converted': new_filename
                    })
                else:
                    results['copied'].append(filename)

                print(f"  ✓ {filename} -> {new_filename}")

            except Exception as e:
                results['errors'].append({
                    'filename': filename,
                    'error': str(e)
                })
                print(f"  ✗ {filename}: {e}")
        else:
            results['not_found'].append({
                'path': path,
                'filename': filename
            })
            print(f"  ⚠ 未找到: {filename} ({path})")

    # 更新 .skp 文件
    if replacements:
        update_skp_file(skp_path, replacements, text_content, binary_content)

    # 输出结果摘要
    print("\n" + "=" * 60)
    print("处理结果:")
    print(f"  复制贴图: {len(results['copied'])} 个")
    print(f"  重命名: {len(results['renamed'])} 个")
    print(f"  未找到: {len(results['not_found'])} 个")
    print(f"  错误: {len(results['errors'])} 个")

    if results['renamed']:
        print("\n重命名详情:")
        for item in results['renamed']:
            print(f"  {item['original']} -> {item['converted']}")

    if results['not_found']:
        print("\n未找到的贴图:")
        for item in results['not_found']:
            print(f"  {item['filename']}")

    print(f"\n贴图已保存到: {textures_dir}")

    return results


def main():
    import sys

    if len(sys.argv) < 2:
        print("SketchUp .skp 材质贴图复制工具")
        print("使用方法: python skp_texture_copier.py <skp文件路径> [搜索目录...]")
        print("\n示例:")
        print("  python skp_texture_copier.py model.skp")
        print("  python skp_texture_copier.py model.skp D:/Textures C:/Materials")
        return

    skp_path = sys.argv[1]
    search_dirs = sys.argv[2:] if len(sys.argv) > 2 else None

    if not os.path.exists(skp_path):
        print(f"错误: 文件不存在 - {skp_path}")
        return

    results = process_skp_file(skp_path, search_dirs)


if __name__ == '__main__':
    main()