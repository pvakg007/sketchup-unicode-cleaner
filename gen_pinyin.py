#!/usr/bin/env python3
"""Generate merged PINYIN_TABLE and write it into the GUI source."""
import re

existing = {
    '贴': 'tie', '图': 'tu', '材': 'cai', '质': 'zhi',
    '木': 'mu', '石': 'shi', '砖': 'zhuan', '瓦': 'wa',
    '板': 'ban', '块': 'kuai', '片': 'pian', '层': 'ceng',
    '面': 'mian', '纹': 'wen', '理': 'li', '漆': 'qi',
    '红': 'hong', '橙': 'cheng', '黄': 'huang', '绿': 'lv',
    '青': 'qing', '蓝': 'lan', '紫': 'zi', '白': 'bai',
    '黑': 'hei', '灰': 'hui', '褐': 'he', '棕': 'zong',
    '金': 'jin', '银': 'yin', '铜': 'tong', '铁': 'tie',
    '地': 'di', '墙': 'qiang', '顶': 'ding', '门': 'men',
    '窗': 'chuang', '柱': 'zhu', '梁': 'liang', '楼': 'lou',
    '大': 'da', '小': 'xiao', '新': 'xin', '旧': 'jiu',
    '上': 'shang', '下': 'xia', '左': 'zuo', '右': 'you',
    '前': 'qian', '后': 'hou', '中': 'zhong', '外': 'wai',
    '水': 'shui', '火': 'huo', '土': 'tu', '风': 'feng',
    '山': 'shan', '海': 'hai', '天': 'tian', '云': 'yun',
    '花': 'hua', '草': 'cao', '树': 'shu', '叶': 'ye',
    '一': 'yi', '二': 'er', '三': 'san', '四': 'si',
    '五': 'wu', '六': 'liu', '七': 'qi', '八': 'ba',
    '九': 'jiu', '十': 'shi', '百': 'bai', '千': 'qian',
}

merged = dict(existing)
with open('pinyin_dict.txt', 'r', encoding='utf-8') as f:
    content = f.read()
for line in content.strip().split('\n'):
    if line.startswith('Total:'):
        continue
    pairs = re.findall(r"'([^']+)'\s*=>\s*'([^']+)'", line)
    for char, pinyin in pairs:
        if char not in merged:
            merged[char] = pinyin

# Group by pinyin for compact output
by_pinyin = {}
for char, py in sorted(merged.items()):
    by_pinyin.setdefault(py, []).append(char)

lines = []
for py in sorted(by_pinyin):
    chars = by_pinyin[py]
    parts = [f"'{c}': '{py}'" for c in chars]
    lines.append('    ' + ', '.join(parts) + ',')

output = 'PINYIN_TABLE = {\n' + '\n'.join(lines) + '\n}\n'
print(output)
