#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SketchUp .skp 材质贴图复制工具 - GUI版本
.skp 本质是 ZIP 压缩包，内部 materials/*/material.xml 存储贴图路径
功能：
1. 解析 .skp (ZIP) 内所有 material.xml
2. 提取贴图文件路径和名称
3. 从磁盘/ZIP内找到贴图，复制到 textures 目录
4. 重命名非 ASCII 文件名为 UTF-8 兼容格式
5. 更新 .skp 内所有 material.xml 中的贴图路径
"""

import os
import io
import re
import shutil
import struct
import zipfile
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
from xml.etree import ElementTree as ET


PINYIN_TABLE = {
    '阿': 'a',
    '埃': 'ai', '爱': 'ai', '矮': 'ai', '艾': 'ai',
    '安': 'an', '岸': 'an', '案': 'an', '胺': 'an',
    '凹': 'ao', '奥': 'ao', '奧': 'ao', '澳': 'ao',
    '八': 'ba', '巴': 'ba',
    '拜': 'bai', '柏': 'bai', '白': 'bai', '百': 'bai',
    '办': 'ban', '半': 'ban', '斑': 'ban', '板': 'ban', '版': 'ban', '班': 'ban',
    '邦': 'bang',
    '保': 'bao', '堡': 'bao', '宝': 'bao', '薄': 'bao',
    '北': 'bei', '卑': 'bei', '备': 'bei', '背': 'bei', '贝': 'bei',
    '本': 'ben',
    '壁': 'bi', '比': 'bi', '毕': 'bi', '碧': 'bi',
    '变': 'bian', '编': 'bian', '边': 'bian',
    '标': 'biao', '表': 'biao',
    '别': 'bie',
    '槟': 'bin',
    '並': 'bing', '冰': 'bing', '并': 'bing',
    '伯': 'bo', '博': 'bo', '波': 'bo', '玻': 'bo', '箔': 'bo', '簸': 'bo', '铂': 'bo',
    '不': 'bu', '布': 'bu', '部': 'bu',
    '彩': 'cai', '材': 'cai',
    '餐': 'can',
    '沧': 'cang', '滄': 'cang',
    '槽': 'cao', '糙': 'cao', '草': 'cao',
    '册': 'ce', '策': 'ce',
    '层': 'ceng',
    '茶': 'cha', '诧': 'cha',
    '产': 'chan',
    '厂': 'chang', '场': 'chang', '常': 'chang',
    '朝': 'chao', '超': 'chao',
    '晨': 'chen', '沉': 'chen', '辰': 'chen',
    '乘': 'cheng', '城': 'cheng', '橙': 'cheng', '称': 'cheng', '程': 'cheng',
    '尺': 'chi', '翅': 'chi', '赤': 'chi',
    '抽': 'chou',
    '储': 'chu', '厨': 'chu', '础': 'chu',
    '传': 'chuan', '川': 'chuan',
    '创': 'chuang', '創': 'chuang', '窗': 'chuang',
    '春': 'chun', '纯': 'chun',
    '次': 'ci', '瓷': 'ci', '磁': 'ci',
    '粗': 'cu',
    '翠': 'cui',
    '存': 'cun', '寸': 'cun',
    '大': 'da', '打': 'da', '搭': 'da', '达': 'da',
    '代': 'dai', '带': 'dai', '黛': 'dai',
    '丹': 'dan', '单': 'dan', '淡': 'dan',
    '当': 'dang',
    '刀': 'dao', '道': 'dao',
    '德': 'de', '的': 'de',
    '灯': 'deng', '登': 'deng',
    '低': 'di', '地': 'di', '帝': 'di', '廸': 'di', '第': 'di', '蒂': 'di', '迪': 'di',
    '典': 'dian', '店': 'dian', '点': 'dian', '电': 'dian', '颠': 'dian',
    '吊': 'diao', '调': 'diao', '雕': 'diao',
    '蝶': 'die',
    '丁': 'ding', '定': 'ding', '订': 'ding', '顶': 'ding',
    '东': 'dong', '冬': 'dong', '洞': 'dong',
    '豆': 'dou', '都': 'dou',
    '度': 'du', '杜': 'du', '肚': 'du',
    '短': 'duan', '端': 'duan', '缎': 'duan',
    '对': 'dui',
    '敦': 'dun', '顿': 'dun',
    '多': 'duo',
    '俄': 'e', '鹅': 'e',
    '恩': 'en',
    '二': 'er', '尔': 'er', '耳': 'er',
    '发': 'fa', '法': 'fa',
    '反': 'fan', '梵': 'fan', '范': 'fan',
    '仿': 'fang', '房': 'fang', '放': 'fang', '方': 'fang', '芳': 'fang',
    '啡': 'fei', '妃': 'fei', '斐': 'fei', '翡': 'fei', '菲': 'fei', '费': 'fei', '非': 'fei',
    '分': 'fen', '粉': 'fen', '芬': 'fen',
    '凤': 'feng', '峰': 'feng', '枫': 'feng', '缝': 'feng', '蜂': 'feng', '风': 'feng',
    '佛': 'fu', '副': 'fu', '复': 'fu', '夫': 'fu', '服': 'fu', '浮': 'fu', '福': 'fu', '芙': 'fu',
    '改': 'gai', '概': 'gai',
    '干': 'gan',
    '岗': 'gang', '港': 'gang', '钢': 'gang',
    '高': 'gao',
    '各': 'ge', '哥': 'ge', '格': 'ge', '歌': 'ge', '革': 'ge', '鸽': 'ge',
    '根': 'gen',
    '供': 'gong', '公': 'gong', '宫': 'gong', '工': 'gong', '拱': 'gong',
    '古': 'gu', '谷': 'gu', '骨': 'gu',
    '刮': 'gua', '挂': 'gua',
    '关': 'guan', '观': 'guan', '馆': 'guan',
    '光': 'guang', '广': 'guang',
    '柜': 'gui', '桂': 'gui', '瑰': 'gui', '硅': 'gui', '规': 'gui', '贵': 'gui',
    '丨': 'gun',
    '国': 'guo', '果': 'guo', '过': 'guo',
    '哈': 'ha',
    '海': 'hai',
    '寒': 'han', '汉': 'han',
    '号': 'hao', '好': 'hao', '浩': 'hao',
    '合': 'he', '和': 'he', '河': 'he', '荷': 'he', '褐': 'he',
    '黑': 'hei',
    '很': 'hen', '痕': 'hen',
    '横': 'heng',
    '红': 'hong', '虹': 'hong', '鸿': 'hong',
    '厚': 'hou', '后': 'hou',
    '弧': 'hu', '户': 'hu', '湖': 'hu', '狐': 'hu', '琥': 'hu', '瑚': 'hu', '胡': 'hu', '虎': 'hu',
    '划': 'hua', '化': 'hua', '华': 'hua', '滑': 'hua', '画': 'hua', '畫': 'hua', '花': 'hua',
    '幻': 'huan', '环': 'huan',
    '凰': 'huang', '皇': 'huang', '黄': 'huang',
    '会': 'hui', '卉': 'hui', '灰': 'hui', '绘': 'hui', '辉': 'hui',
    '昏': 'hun', '混': 'hun',
    '活': 'huo', '火': 'huo', '霍': 'huo',
    '几': 'ji', '及': 'ji', '圾': 'ji', '基': 'ji', '季': 'ji', '寂': 'ji', '技': 'ji', '机': 'ji', '极': 'ji', '济': 'ji', '矶': 'ji', '級': 'ji', '级': 'ji', '纪': 'ji', '肌': 'ji', '计': 'ji', '际': 'ji', '集': 'ji', '鸡': 'ji',
    '佳': 'jia', '加': 'jia', '夹': 'jia', '家': 'jia',
    '件': 'jian', '建': 'jian', '渐': 'jian', '简': 'jian', '间': 'jian',
    '匠': 'jiang', '江': 'jiang', '浆': 'jiang', '降': 'jiang',
    '礁': 'jiao', '胶': 'jiao', '脚': 'jiao', '角': 'jiao',
    '介': 'jie', '界': 'jie', '节': 'jie',
    '津': 'jin', '进': 'jin', '金': 'jin', '锦': 'jin',
    '京': 'jing', '净': 'jing', '境': 'jing', '惊': 'jing', '景': 'jing', '晶': 'jing', '精': 'jing', '镜': 'jing', '静': 'jing',
    '九': 'jiu', '旧': 'jiu', '究': 'jiu', '酒': 'jiu',
    '具': 'ju', '剧': 'ju', '局': 'ju', '居': 'ju', '榉': 'ju', '菊': 'ju',
    '爵': 'jue',
    '军': 'jun', '菌': 'jun',
    '卡': 'ka', '咖': 'ka',
    '凯': 'kai', '开': 'kai',
    '康': 'kang', '抗': 'kang',
    '拷': 'kao', '烤': 'kao',
    '克': 'ke', '刻': 'ke', '可': 'ke', '客': 'ke', '柯': 'ke', '科': 'ke', '课': 'ke',
    '肯': 'ken',
    '坑': 'keng',
    '孔': 'kong', '空': 'kong',
    '口': 'kou', '蔻': 'kou',
    '库': 'ku', '酷': 'ku',
    '跨': 'kua',
    '块': 'kuai',
    '款': 'kuan',
    '框': 'kuang',
    '昆': 'kun',
    '垃': 'la', '拉': 'la', '腊': 'la',
    '莱': 'lai',
    '兰': 'lan', '蓝': 'lan', '藍': 'lan',
    '朗': 'lang', '浪': 'lang',
    '劳': 'lao', '勞': 'lao', '老': 'lao',
    '类': 'lei', '雷': 'lei',
    '冷': 'leng',
    '丽': 'li', '利': 'li', '力': 'li', '栗': 'li', '梨': 'li', '沥': 'li', '理': 'li', '璃': 'li', '砾': 'li', '立': 'li', '粒': 'li', '莉': 'li', '里': 'li',
    '廉': 'lian', '连': 'lian',
    '亮': 'liang', '梁': 'liang',
    '料': 'liao',
    '列': 'lie', '烈': 'lie',
    '林': 'lin',
    '凌': 'ling', '玲': 'ling', '菱': 'ling',
    '六': 'liu', '柳': 'liu', '流': 'liu', '鎏': 'liu',
    '珑': 'long', '瓏': 'long', '胧': 'long', '龙': 'long',
    '楼': 'lou',
    '卢': 'lu', '路': 'lu', '露': 'lu', '魯': 'lu', '鲁': 'lu', '鹭': 'lu',
    '乱': 'luan',
    '伦': 'lun', '倫': 'lun',
    '洛': 'luo', '络': 'luo', '罗': 'luo', '羅': 'luo', '落': 'luo', '裸': 'luo',
    '綠': 'lv', '绿': 'lv',
    '玛': 'ma', '瑪': 'ma', '馬': 'ma', '马': 'ma', '麻': 'ma',
    '脉': 'mai', '麦': 'mai',
    '曼': 'man', '满': 'man', '漫': 'man',
    '毛': 'mao', '猫': 'mao',
    '梅': 'mei', '玫': 'mei', '美': 'mei', '魅': 'mei',
    '门': 'men',
    '孟': 'meng', '朦': 'meng', '梦': 'meng', '檬': 'meng', '蒙': 'meng',
    '秘': 'mi', '米': 'mi', '蜜': 'mi', '迷': 'mi',
    '免': 'mian', '棉': 'mian', '面': 'mian',
    '名': 'ming', '明': 'ming',
    '墨': 'mo', '摩': 'mo', '模': 'mo', '漠': 'mo', '磨': 'mo', '膜': 'mo', '莫': 'mo', '默': 'mo',
    '姆': 'mu', '慕': 'mu', '暮': 'mu', '木': 'mu', '母': 'mu',
    '娜': 'na', '拿': 'na', '纳': 'na', '那': 'na',
    '奶': 'nai', '耐': 'nai',
    '南': 'nan', '楠': 'nan',
    '瑙': 'nao', '脑': 'nao',
    '内': 'nei',
    '妮': 'ni', '尼': 'ni', '拟': 'ni', '泥': 'ni',
    '年': 'nian', '念': 'nian',
    '鸟': 'niao',
    '凝': 'ning', '柠': 'ning',
    '纽': 'niu',
    '浓': 'nong',
    '努': 'nu',
    '暖': 'nuan',
    '挪': 'nuo', '諾': 'nuo', '诺': 'nuo',
    '欧': 'ou', '殴': 'ou', '藕': 'ou',
    '帕': 'pa',
    '拍': 'pai', '牌': 'pai',
    '潘': 'pan',
    '抛': 'pao',
    '佩': 'pei', '裴': 'pei', '配': 'pei',
    '喷': 'pen',
    '朋': 'peng',
    '皮': 'pi',
    '偏': 'pian', '片': 'pian',
    '漂': 'piao', '飘': 'piao',
    '品': 'pin', '拼': 'pin', '频': 'pin',
    '平': 'ping', '瓶': 'ping',
    '泼': 'po', '珀': 'po', '破': 'po',
    '剖': 'pou',
    '普': 'pu', '蒲': 'pu', '铺': 'pu',
    '七': 'qi', '其': 'qi', '器': 'qi', '奇': 'qi', '漆': 'qi', '绮': 'qi', '齐': 'qi',
    '前': 'qian', '千': 'qian', '浅': 'qian', '淺': 'qian',
    '墙': 'qiang', '强': 'qiang',
    '乔': 'qiao', '俏': 'qiao',
    '切': 'qie',
    '琴': 'qin',
    '情': 'qing', '清': 'qing', '轻': 'qing', '青': 'qing',
    '楸': 'qiu', '秋': 'qiu',
    '区': 'qu', '曲': 'qu',
    '全': 'quan', '圈': 'quan',
    '缺': 'que', '雀': 'que',
    '染': 'ran', '然': 'ran',
    '热': 're',
    '人': 'ren',
    '仍': 'reng',
    '日': 'ri',
    '绒': 'rong',
    '柔': 'rou',
    '入': 'ru', '如': 'ru',
    '软': 'ruan',
    '瑞': 'rui',
    '润': 'run',
    '撒': 'sa', '萨': 'sa', '薩': 'sa',
    '塞': 'sai', '赛': 'sai',
    '三': 'san',
    '桑': 'sang',
    '瑟': 'se', '色': 'se',
    '森': 'sen',
    '沙': 'sha', '砂': 'sha', '莎': 'sha',
    '山': 'shan', '珊': 'shan', '衫': 'shan', '闪': 'shan',
    '上': 'shang', '商': 'shang', '尚': 'shang',
    '烧': 'shao', '绍': 'shao', '邵': 'shao',
    '奢': 'she', '射': 'she', '舍': 'she', '设': 'she',
    '深': 'shen', '燊': 'shen', '神': 'shen', '绅': 'shen',
    '圣': 'sheng', '生': 'sheng',
    '世': 'shi', '仕': 'shi', '使': 'shi', '十': 'shi', '士': 'shi', '实': 'shi', '室': 'shi', '市': 'shi', '式': 'shi', '施': 'shi', '时': 'shi', '時': 'shi', '石': 'shi', '示': 'shi', '视': 'shi', '诗': 'shi', '适': 'shi', '饰': 'shi',
    '手': 'shou', '收': 'shou',
    '书': 'shu', '墅': 'shu', '属': 'shu', '术': 'shu', '树': 'shu', '殊': 'shu', '熟': 'shu', '疏': 'shu', '竖': 'shu', '鼠': 'shu',
    '双': 'shuang',
    '水': 'shui',
    '烁': 'shuo', '说': 'shuo',
    '丝': 'si', '四': 'si', '思': 'si', '斯': 'si', '絲': 'si',
    '松': 'song',
    '塑': 'su', '素': 'su', '苏': 'su',
    '算': 'suan',
    '岁': 'sui', '碎': 'sui', '邃': 'sui',
    '损': 'sun',
    '索': 'suo',
    '他': 'ta', '塔': 'ta',
    '台': 'tai', '太': 'tai', '态': 'tai', '汰': 'tai', '钛': 'tai',
    '探': 'tan', '檀': 'tan', '毯': 'tan', '滩': 'tan', '炭': 'tan',
    '堂': 'tang', '棠': 'tang', '糖': 'tang',
    '套': 'tao', '桃': 'tao', '淘': 'tao', '陶': 'tao',
    '特': 'te',
    '藤': 'teng',
    '体': 'ti', '梯': 'ti', '瑅': 'ti', '缇': 'ti', '题': 'ti',
    '天': 'tian',
    '条': 'tiao',
    '贴': 'tie', '铁': 'tie',
    '厅': 'ting', '庭': 'ting',
    '通': 'tong', '铜': 'tong',
    '头': 'tou', '透': 'tou',
    '凸': 'tu', '图': 'tu', '土': 'tu', '突': 'tu',
    '推': 'tui',
    '托': 'tuo', '驼': 'tuo',
    '瓦': 'wa',
    '外': 'wai',
    '万': 'wan', '湾': 'wan',
    '旺': 'wang', '王': 'wang', '网': 'wang',
    '为': 'wei', '卫': 'wei', '唯': 'wei', '威': 'wei', '尾': 'wei', '微': 'wei', '未': 'wei', '维': 'wei', '韦': 'wei', '魏': 'wei',
    '文': 'wen', '紋': 'wen', '纹': 'wen',
    '卧': 'wo', '沃': 'wo',
    '乌': 'wu', '五': 'wu', '务': 'wu', '午': 'wu', '无': 'wu', '武': 'wu', '物': 'wu', '雾': 'wu', '霧': 'wu',
    '吸': 'xi', '希': 'xi', '惜': 'xi', '洗': 'xi', '系': 'xi', '細': 'xi', '细': 'xi', '西': 'xi', '锡': 'xi',
    '下': 'xia', '夏': 'xia', '峡': 'xia',
    '仙': 'xian', '现': 'xian', '线': 'xian', '闲': 'xian', '限': 'xian',
    '像': 'xiang', '橡': 'xiang', '祥': 'xiang', '箱': 'xiang', '象': 'xiang', '项': 'xiang', '香': 'xiang',
    '小': 'xiao', '效': 'xiao', '晓': 'xiao', '销': 'xiao',
    '写': 'xie',
    '信': 'xin', '新': 'xin', '芯': 'xin',
    '型': 'xing', '形': 'xing', '星': 'xing', '杏': 'xing',
    '熊': 'xiong',
    '休': 'xiu', '修': 'xiu', '銹': 'xiu', '锈': 'xiu',
    '序': 'xu',
    '宣': 'xuan', '玄': 'xuan', '轩': 'xuan', '选': 'xuan',
    '学': 'xue', '雪': 'xue',
    '循': 'xun', '熏': 'xun', '逊': 'xun',
    '亚': 'ya', '亞': 'ya', '压': 'ya', '哑': 'ya', '牙': 'ya', '雅': 'ya',
    '岩': 'yan', '演': 'yan', '烟': 'yan', '盐': 'yan', '眼': 'yan', '研': 'yan', '颜': 'yan',
    '洋': 'yang', '阳': 'yang',
    '腰': 'yao',
    '业': 'ye', '叶': 'ye', '耶': 'ye', '野': 'ye', '页': 'ye',
    '一': 'yi', '以': 'yi', '伊': 'yi', '异': 'yi', '意': 'yi', '易': 'yi', '移': 'yi', '绎': 'yi', '翼': 'yi', '艺': 'yi', '衣': 'yi', '议': 'yi', '逸': 'yi',
    '印': 'yin', '殷': 'yin', '銀': 'yin', '银': 'yin',
    '应': 'ying', '影': 'ying', '樱': 'ying', '英': 'ying',
    '用': 'yong',
    '友': 'you', '右': 'you', '尤': 'you', '有': 'you', '油': 'you', '釉': 'you',
    '域': 'yu', '愉': 'yu', '浴': 'yu', '玉': 'yu', '羽': 'yu', '萸': 'yu', '语': 'yu', '郁': 'yu', '雨': 'yu', '预': 'yu', '魚': 'yu', '鱼': 'yu',
    '元': 'yuan', '原': 'yuan', '园': 'yuan', '圆': 'yuan', '远': 'yuan', '院': 'yuan',
    '悦': 'yue', '月': 'yue', '约': 'yue', '越': 'yue',
    '云': 'yun', '运': 'yun',
    '杂': 'za',
    '再': 'zai', '载': 'zai',
    '脏': 'zang',
    '噪': 'zao', '藻': 'zao',
    '增': 'zeng',
    '扎': 'zha',
    '斋': 'zhai', '窄': 'zhai',
    '占': 'zhan',
    '张': 'zhang', '樟': 'zhang', '长': 'zhang',
    '照': 'zhao',
    '折': 'zhe', '浙': 'zhe', '赭': 'zhe',
    '榛': 'zhen', '珍': 'zhen', '臻': 'zhen', '镇': 'zhen',
    '整': 'zheng', '正': 'zheng',
    '之': 'zhi', '制': 'zhi', '志': 'zhi', '智': 'zhi', '直': 'zhi', '纸': 'zhi', '织': 'zhi', '脂': 'zhi', '至': 'zhi', '致': 'zhi', '质': 'zhi',
    '中': 'zhong',
    '宙': 'zhou', '洲': 'zhou',
    '主': 'zhu', '柱': 'zhu', '珠': 'zhu', '竹': 'zhu', '茱': 'zhu',
    '专': 'zhuan', '砖': 'zhuan', '转': 'zhuan',
    '装': 'zhuang',
    '追': 'zhui',
    '准': 'zhun',
    '浊': 'zhuo',
    '兹': 'zi', '子': 'zi', '字': 'zi', '紫': 'zi', '自': 'zi', '资': 'zi',
    '棕': 'zong', '踪': 'zong',
    '族': 'zu', '组': 'zu',
    '钻': 'zuan',
    '最': 'zui',
    '尊': 'zun',
    '作': 'zuo', '做': 'zuo', '左': 'zuo',
}

TEXTURE_EXTS = {'.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.hdr', '.exr'}

# material.xml 使用的命名空间
NS_MAT = 'http://sketchup.google.com/schemas/sketchup/1.0/material'
NS_N0 = 'http://sketchup.google.com/schemas/1.0/types'


def convert_to_ascii(filename):
    """将文件名中的非ASCII字符转换为拼音或hex编码。
    中文之间用_分隔，连续ASCII字符保持原样不加_。
    无非ASCII字符的文件名直接返回原值。
    """
    name, ext = os.path.splitext(filename)

    # 如果没有非ASCII字符，直接返回原文件名
    if all(c.isascii() for c in name):
        return filename

    # 构建分段：中文->拼音/hex, ASCII字符连续成组
    segments = []
    ascii_buf = []
    for char in name:
        if char.isascii():
            ascii_buf.append(char)
        else:
            if ascii_buf:
                segments.append(''.join(ascii_buf))
                ascii_buf = []
            if char in PINYIN_TABLE:
                segments.append(PINYIN_TABLE[char])
            else:
                segments.append(f'u{ord(char):04x}')
    if ascii_buf:
        segments.append(''.join(ascii_buf))

    converted = '_'.join(segments).lower()
    converted = re.sub(r'_+', '_', converted).strip('_')
    return converted + ext.lower()


def needs_conversion(filename):
    """检查文件名是否包含非ASCII字符"""
    return any(not c.isascii() for c in os.path.splitext(filename)[0])


def parse_material_xml(xml_bytes):
    """
    解析 material.xml，从 <n0:Attribute key="MaterialXML" type="10"> 块中提取贴图路径。
    只处理 MaterialXML 属性块内的路径，忽略块外的路径和文件名。
    贴图路径格式：
    1) 引号内的 Windows 绝对路径，如 "C:\\path\\file.jpg"
    2) <Parameter Name="Filename" Type="File" Value="D:/path/file.jpg"/>
    3) &quot; 包裹的路径，如 &quot;C:\\path\\file.jpg&quot;
    """
    try:
        raw = xml_bytes.decode('utf-8', errors='replace')
    except Exception:
        raw = xml_bytes.decode('latin-1', errors='replace')

    info = {'texture_paths': [], 'raw_xml': raw}

    # 找到所有 <n0:Attribute key="MaterialXML" type="10">...</n0:Attribute> 块
    for m in re.finditer(
        r'<n0:Attribute\s+key="MaterialXML"\s+type="10">(.*?)</n0:Attribute>',
        raw, re.DOTALL
    ):
        block = m.group(1)
        ext_pattern = '|'.join(e.lstrip('.') for e in TEXTURE_EXTS)

        # 提取引号内的 Windows 绝对路径（含贴图扩展名）
        # 匹配: "C:\path\file.jpg" 和 Value="D:/path/file.png"
        for pm in re.finditer(
            r'"([A-Za-z]:[\\/][^"]*?\.(?:' + ext_pattern + r'))"',
            block, re.IGNORECASE
        ):
            path = pm.group(1)
            if path not in info['texture_paths']:
                info['texture_paths'].append(path)

        # 匹配 &quot; 包裹的路径: &quot;C:\path\file.jpg&quot;
        for pm in re.finditer(
            r'&quot;([A-Za-z]:[\\/][^&]*?\.(?:' + ext_pattern + r'))&quot;',
            block, re.IGNORECASE
        ):
            path = pm.group(1)
            if path not in info['texture_paths']:
                info['texture_paths'].append(path)

        # 提取无引号的路径（不含空格的情况）
        for pm in re.finditer(
            r'(?<![A-Za-z0-9_./\\一-鿿])'
            r'([A-Za-z]:[\\/][^\s"<>]*?\.(?:' + ext_pattern + r'))',
            block, re.IGNORECASE
        ):
            path = pm.group(1)
            if path not in info['texture_paths']:
                info['texture_paths'].append(path)

    return info


class SkpTextureCopierGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("SKP Texture Copier - SketchUp 贴图复制工具")
        self.root.geometry("900x650")

        self.skp_path = None
        self.search_dirs = []
        self.material_data = []  # [{zip_path, info, texture_items}]
        self.zf = None

        self._build_ui()

    def _build_ui(self):
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)

        main = ttk.Frame(self.root, padding="8")
        main.grid(row=0, column=0, sticky="nsew")
        main.columnconfigure(0, weight=1)
        main.rowconfigure(2, weight=1)
        main.rowconfigure(3, weight=1)

        # ---- 文件选择 ----
        f_file = ttk.LabelFrame(main, text="文件选择", padding="5")
        f_file.grid(row=0, column=0, sticky="ew", pady=(0, 5))
        f_file.columnconfigure(1, weight=1)

        ttk.Label(f_file, text="SKP文件:").grid(row=0, column=0, sticky="w")
        self.ent_skp = ttk.Entry(f_file)
        self.ent_skp.grid(row=0, column=1, padx=5, sticky="ew")
        ttk.Button(f_file, text="选择文件", command=self._on_select_skp).grid(row=0, column=2)

        ttk.Label(f_file, text="额外搜索:").grid(row=1, column=0, sticky="w")
        self.ent_search = ttk.Entry(f_file)
        self.ent_search.grid(row=1, column=1, padx=5, sticky="ew")
        ttk.Button(f_file, text="添加目录", command=self._on_add_search).grid(row=1, column=2)

        # ---- 按钮 ----
        f_btn = ttk.Frame(main)
        f_btn.grid(row=1, column=0, pady=5)
        ttk.Button(f_btn, text="1. 解析SKP", command=self._on_parse).pack(side="left", padx=5)
        ttk.Button(f_btn, text="2. 复制贴图并更新SKP", command=self._on_copy_and_update).pack(side="left", padx=5)

        # ---- 贴图列表 ----
        f_list = ttk.LabelFrame(main, text="贴图列表", padding="5")
        f_list.grid(row=2, column=0, sticky="nsew", pady=5)
        f_list.columnconfigure(0, weight=1)
        f_list.rowconfigure(0, weight=1)

        cols = ('material', 'texture_filename', 'source', 'status', 'new_filename')
        self.tree = ttk.Treeview(f_list, columns=cols, show='headings', height=12)
        for col, heading, w in [
            ('material', '材质目录', 200),
            ('texture_filename', '贴图文件名', 200),
            ('source', '来源', 100),
            ('status', '状态', 80),
            ('new_filename', '新文件名', 200),
        ]:
            self.tree.heading(col, text=heading)
            self.tree.column(col, width=w, minwidth=60)

        sb = ttk.Scrollbar(f_list, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.grid(row=0, column=0, sticky="nsew")
        sb.grid(row=0, column=1, sticky="ns")

        # ---- 日志 ----
        f_log = ttk.LabelFrame(main, text="日志", padding="5")
        f_log.grid(row=3, column=0, sticky="nsew", pady=5)
        f_log.columnconfigure(0, weight=1)
        f_log.rowconfigure(0, weight=1)

        self.txt_log = scrolledtext.ScrolledText(f_log, height=8, wrap="word")
        self.txt_log.grid(row=0, column=0, sticky="nsew")

    def log(self, msg):
        self.txt_log.insert(tk.END, msg + "\n")
        self.txt_log.see(tk.END)
        self.root.update_idletasks()

    # ---- UI回调 ----

    def _on_select_skp(self):
        path = filedialog.askopenfilename(
            title="选择 SketchUp 文件",
            filetypes=[("SketchUp files", "*.skp"), ("All files", "*.*")]
        )
        if path:
            self.skp_path = path
            self.ent_skp.delete(0, tk.END)
            self.ent_skp.insert(0, path)
            self.search_dirs = [os.path.dirname(path)]
            self.ent_search.delete(0, tk.END)
            self.ent_search.insert(0, self.search_dirs[0])
            self.log(f"已选择: {path}")

    def _on_add_search(self):
        path = filedialog.askdirectory(title="选择贴图搜索目录")
        if path:
            self.search_dirs.append(path)
            cur = self.ent_search.get()
            self.ent_search.delete(0, tk.END)
            self.ent_search.insert(0, cur + " ; " + path if cur else path)
            self.log(f"添加搜索目录: {path}")

    def _on_parse(self):
        if not self.skp_path:
            messagebox.showerror("错误", "请先选择 SKP 文件")
            return

        self.log("=" * 50)
        self.log("开始解析 SKP 文件 (ZIP 格式)...")

        # 清空
        for i in self.tree.get_children():
            self.tree.delete(i)
        self.material_data = []
        if self.zf:
            self.zf.close()
            self.zf = None

        try:
            self.zf = zipfile.ZipFile(self.skp_path, 'r')
        except zipfile.BadZipFile:
            messagebox.showerror("错误", "该文件不是有效的 ZIP/SKP 文件")
            return

        # 找到所有 material.xml
        xml_entries = [n for n in self.zf.namelist() if n.endswith('material.xml')]
        self.log(f"ZIP 内共 {len(xml_entries)} 个 material.xml 文件")

        # 找到 ZIP 内所有贴图文件（用于提取嵌入的贴图）
        zip_texture_files = {}
        for n in self.zf.namelist():
            bn = os.path.basename(n)
            if bn and os.path.splitext(bn)[1].lower() in TEXTURE_EXTS:
                zip_texture_files[bn.lower()] = n

        self.log(f"ZIP 内嵌入贴图文件: {len(zip_texture_files)} 个")

        for xml_entry in xml_entries:
            xml_bytes = self.zf.read(xml_entry)
            info = parse_material_xml(xml_bytes)

            # 材质目录名
            mat_dir = xml_entry.replace('materials/', '').replace('/material.xml', '')

            for full_path in info['texture_paths']:
                filename = os.path.basename(full_path)

                # 判断贴图来源
                source = "未找到"
                found_data = None

                # 1) 磁盘原始路径（直接用完整路径查找）
                if os.path.exists(full_path):
                    source = "磁盘路径"
                    found_data = ('disk', full_path)

                # 2) ZIP 内嵌（按文件名匹配）
                if found_data is None and filename.lower() in zip_texture_files:
                    source = "ZIP内嵌"
                    found_data = ('zip', zip_texture_files[filename.lower()])

                # 3) 搜索目录（按文件名递归搜索）
                if found_data is None:
                    for sd in self.search_dirs:
                        found = self._search_file(sd, filename)
                        if found:
                            source = "搜索目录"
                            found_data = ('disk', found)
                            break

                needs = needs_conversion(filename)
                new_name = convert_to_ascii(filename) if needs else filename
                status = "待复制" if found_data else "未找到"

                item_id = self.tree.insert('', 'end', values=(
                    mat_dir, filename, source, status, new_name
                ))

                self.material_data.append({
                    'tree_id': item_id,
                    'xml_entry': xml_entry,
                    'mat_dir': mat_dir,
                    'filename': filename,
                    'full_path': full_path,
                    'new_name': new_name,
                    'needs_rename': needs,
                    'source': source,
                    'found_data': found_data,
                })

        total = len(self.material_data)
        found = sum(1 for d in self.material_data if d['found_data'])
        rename = sum(1 for d in self.material_data if d['needs_rename'])
        self.log(f"解析完成: 共 {total} 个贴图, 找到 {found} 个, 需重命名 {rename} 个")

    def _on_copy_and_update(self):
        """一键执行: 复制贴图 + 重命名 + 更新SKP"""
        if not self.material_data:
            messagebox.showerror("错误", "请先解析 SKP 文件")
            return

        self.log("=" * 50)
        self.log("开始复制贴图并更新 SKP...")

        skp_dir = os.path.dirname(self.skp_path)
        textures_dir = os.path.join(skp_dir, 'textures')
        if not os.path.exists(textures_dir):
            os.makedirs(textures_dir)
            self.log(f"创建目录: {textures_dir}")

        # 创建备份: model.skp -> model_backup.skp
        base, ext = os.path.splitext(self.skp_path)
        backup_path = base + '_backup' + ext
        if not os.path.exists(backup_path):
            shutil.copy2(self.skp_path, backup_path)
            self.log(f"备份: {backup_path}")

        # ---- 第1步: 复制贴图到 textures 目录 ----
        used_names = {}
        copied_count = 0
        renamed_count = 0
        not_found_count = 0
        error_count = 0

        # 构建: xml_entry -> [(old_name, new_name)] 的映射
        xml_replacements = {}

        for item in self.material_data:
            filename = item['filename']
            found_data = item['found_data']
            xml_entry = item['xml_entry']

            if not found_data:
                not_found_count += 1
                self.tree.item(item['tree_id'], values=(
                    item['mat_dir'], filename, item['source'], "未找到", item['new_name']
                ))
                continue

            try:
                # 生成新文件名（处理冲突）
                new_name = item['new_name']
                name_base, name_ext = os.path.splitext(new_name)
                counter = 1
                while new_name in used_names:
                    new_name = f"{name_base}_{counter}{name_ext}"
                    counter += 1
                used_names[new_name] = True
                item['final_name'] = new_name

                dst_path = os.path.join(textures_dir, new_name)

                # 复制
                src_type, src_path = found_data
                if src_type == 'zip':
                    data = self.zf.read(src_path)
                    with open(dst_path, 'wb') as f:
                        f.write(data)
                else:
                    shutil.copy2(src_path, dst_path)

                copied_count += 1
                if item['needs_rename']:
                    renamed_count += 1
                    self.log(f"  复制+重命名: {filename} -> {new_name}")
                else:
                    self.log(f"  复制: {filename}")

                self.tree.item(item['tree_id'], values=(
                    item['mat_dir'], filename, item['source'], "已复制", new_name
                ))

                # 记录需要替换的内容
                if xml_entry not in xml_replacements:
                    xml_replacements[xml_entry] = []
                xml_replacements[xml_entry].append((item['full_path'], new_name))

            except Exception as e:
                error_count += 1
                self.log(f"  错误: {filename} - {e}")
                self.tree.item(item['tree_id'], values=(
                    item['mat_dir'], filename, item['source'], "错误", ""
                ))

        self.log(f"\n复制完成: {copied_count} 个, 重命名: {renamed_count} 个, 未找到: {not_found_count} 个, 错误: {error_count} 个")

        if copied_count == 0:
            messagebox.showinfo("结果", "没有可复制的贴图")
            return

        # ---- 第2步: 更新 ZIP 内所有 material.xml ----
        self.log("\n更新 SKP 文件内的 material.xml...")

        try:
            if self.zf:
                self.zf.close()

            with open(self.skp_path, 'rb') as f:
                original_bytes = f.read()

            # 用底层方式重写 ZIP: 逐条复制，只修改需要改的 XML
            new_bytes = self._rewrite_zip(original_bytes, xml_replacements)

            with open(self.skp_path, 'wb') as f:
                f.write(new_bytes)

            self.log("\nSKP 文件更新完成!")
            messagebox.showinfo("完成",
                f"处理完成!\n\n"
                f"复制: {copied_count}\n"
                f"重命名: {renamed_count}\n"
                f"未找到: {not_found_count}\n"
                f"错误: {error_count}\n\n"
                f"备份: {os.path.basename(backup_path)}\n"
                f"贴图目录: textures/")

            self.zf = zipfile.ZipFile(self.skp_path, 'r')

        except Exception as e:
            self.log(f"更新SKP错误: {e}")
            messagebox.showerror("错误", f"更新失败: {e}")

    def _rewrite_zip(self, zip_bytes, xml_replacements):
        """
        手动重建 .skp 内的 ZIP 部分。
        关键优化：未修改的条目保留原始压缩字节，只重建修改过的条目。
        这样最小化与原始文件的差异，避免完整性检查失败。
        """
        import zlib

        self.log(f"  xml_replacements: {len(xml_replacements)} 个条目")

        # 1. 分离 SKP 前导头和 ZIP 数据
        first_pk = zip_bytes.find(b'PK\x03\x04')
        if first_pk <= 0:
            self.log("  错误: 未找到 ZIP 数据")
            return zip_bytes

        preamble = zip_bytes[:first_pk]
        zip_data = zip_bytes[first_pk:]
        self.log(f"  SKP 前导头: {first_pk} 字节, ZIP 数据: {len(zip_data)} 字节")

        # 2. 手动解析原始 ZIP 条目（保留原始压缩数据）
        orig_entries = []
        pos = 0
        while pos < len(zip_data) - 4:
            sig = struct.unpack_from('<I', zip_data, pos)[0]
            if sig != 0x04034b50:
                break

            (ver, flags, method, mtime, mdate, crc,
             comp_size, uncomp_size, fn_len, extra_len
             ) = struct.unpack_from('<HHHHHIIIHH', zip_data, pos + 4)

            raw_fname = zip_data[pos + 30 : pos + 30 + fn_len]
            extra = zip_data[pos + 30 + fn_len : pos + 30 + fn_len + extra_len]
            comp_data = zip_data[pos + 30 + fn_len + extra_len :
                                 pos + 30 + fn_len + extra_len + comp_size]

            fname_str = raw_fname.decode('utf-8', errors='replace')

            entry = {
                'raw_fname': raw_fname,
                'fname_str': fname_str,
                'extra': extra,
                'flags': flags,
                'method': method,
                'mtime': mtime,
                'mdate': mdate,
                'crc': crc,
                'comp_data': comp_data,
                'comp_size': comp_size,
                'uncomp_size': uncomp_size,
                'ver': ver,
            }

            # 3. 如果需要修改，解压→修改→重新压缩
            if fname_str in xml_replacements:
                # 解压
                if method == 8:  # DEFLATE
                    raw_data = zlib.decompress(comp_data, -15)
                elif method == 0:  # STORED
                    raw_data = comp_data
                else:
                    raw_data = comp_data

                xml_text = raw_data.decode('utf-8')
                for old_path, new_name in xml_replacements[fname_str]:
                    xml_text = self._replace_texture_refs(xml_text, old_path, new_name)
                new_data = xml_text.encode('utf-8')

                # 重新压缩（SketchUp 使用 zlib level 1 / Z_BEST_SPEED）
                co = zlib.compressobj(1, zlib.DEFLATED, -15)
                new_comp = co.compress(new_data) + co.flush()

                entry['comp_data'] = new_comp
                entry['comp_size'] = len(new_comp)
                entry['uncomp_size'] = len(new_data)
                entry['crc'] = zlib.crc32(new_data) & 0xFFFFFFFF
                entry['modified'] = True
                self.log(f"  已修改: {fname_str}")

            orig_entries.append(entry)

            pos += 30 + fn_len + extra_len + comp_size
            # 跳过 data descriptor（如果有）
            if flags & 0x08:
                if pos < len(zip_data) - 4:
                    dd_sig = struct.unpack_from('<I', zip_data, pos)[0]
                    if dd_sig == 0x08074b50:
                        pos += 16
                    else:
                        pos += 12

        self.log(f"  解析 {len(orig_entries)} 个 ZIP 条目")

        # 4. 解析原始中央目录（获取 CD 参数）
        eocd_pos = zip_data.rfind(b'\x50\x4b\x05\x06')
        orig_cd = []
        if eocd_pos >= 0:
            (num_disk, num_disk_cd, num_entries_disk, num_entries_total,
             cd_size_orig, cd_offset_orig, comment_len
             ) = struct.unpack_from('<HHHHIIH', zip_data, eocd_pos + 4)

            cd_pos = cd_offset_orig
            for _ in range(num_entries_total):
                if cd_pos >= len(zip_data) - 4:
                    break
                sig = struct.unpack_from('<I', zip_data, cd_pos)[0]
                if sig != 0x02014b50:
                    break
                (ver_made, ver_needed, cd_flags, cd_method,
                 cd_mtime, cd_mdate, cd_crc,
                 cd_comp, cd_uncomp,
                 cd_fn_len, cd_extra_len, cd_comment_len,
                 cd_disk, cd_int_attr, cd_ext_attr,
                 cd_local_off
                 ) = struct.unpack_from('<HHHHHHIIIHHHHHII', zip_data, cd_pos + 4)

                cd_extra = zip_data[cd_pos + 46 + cd_fn_len :
                                    cd_pos + 46 + cd_fn_len + cd_extra_len]

                orig_cd.append({
                    'ver_made': ver_made,
                    'ver_needed': ver_needed,
                    'mtime': cd_mtime,
                    'mdate': cd_mdate,
                    'int_attr': cd_int_attr,
                    'ext_attr': cd_ext_attr,
                    'extra': cd_extra,
                })
                cd_pos += 46 + cd_fn_len + cd_extra_len + cd_comment_len

        # 5. 构建新的 ZIP：本地文件头 + 压缩数据
        out = bytearray()
        local_info = []

        for entry in orig_entries:
            local_hdr = struct.pack('<IHHHHHIIIHH',
                0x04034b50,
                entry['ver'],
                entry['flags'],
                entry['method'],
                entry['mtime'],
                entry['mdate'],
                entry['crc'],
                entry['comp_size'],
                entry['uncomp_size'],
                len(entry['raw_fname']),
                len(entry['extra']))

            local_info.append({
                'raw_fname': entry['raw_fname'],
                'extra': entry['extra'],
                'offset': len(out),
                'crc': entry['crc'],
                'comp_size': entry['comp_size'],
                'uncomp_size': entry['uncomp_size'],
                'flags': entry['flags'],
                'method': entry['method'],
            })

            out += local_hdr + entry['raw_fname'] + entry['extra'] + entry['comp_data']

        # 6. 中央目录
        cd_start = len(out)
        for i, info in enumerate(local_info):
            cd = orig_cd[i] if i < len(orig_cd) else {}
            fb = info['raw_fname']

            cd_entry = struct.pack('<IHHHHHHIIIHHHHHII',
                0x02014b50,
                cd.get('ver_made', 63),
                cd.get('ver_needed', 45),
                info['flags'],
                info['method'],
                cd.get('mtime', 0x0000),
                cd.get('mdate', 0x0021),
                info['crc'],
                info['comp_size'],
                info['uncomp_size'],
                len(fb),
                len(cd.get('extra', b'')),
                0, 0,
                cd.get('int_attr', 0),
                cd.get('ext_attr', 0),
                info['offset'])

            out += cd_entry + fb + cd.get('extra', b'')

        cd_size = len(out) - cd_start

        # 7. EOCD
        num = len(local_info)
        eocd = struct.pack('<IHHHHIIH',
            0x06054b50, 0, 0, num, num, cd_size, cd_start, 0)
        out += eocd

        result = bytes(preamble) + bytes(out)
        self.log(f"  重建完成: {len(result)} 字节 (原始 {len(zip_bytes)} 字节)")
        return result

    def _normalize_material_xml(self, xml_text):
        """规范化 material.xml 以匹配 SketchUp 2025/2026 的输出格式。
        移除旧版 SketchUp 遗留的 <mat:roughness_texture_invert> 元素。"""
        # 剥离 roughness_texture_invert 整行 — SketchUp 2025+ 不再使用此 PBR 参数
        xml_text = re.sub(
            r'^[ \t]*<mat:roughness_texture_invert>0</mat:roughness_texture_invert>[ \t]*\r?\n',
            '', xml_text, flags=re.MULTILINE
        )
        return xml_text

    def _replace_texture_refs(self, xml_text, old_path, new_name):
        """替换 material.xml 中 MaterialXML 块内的贴图路径，同时规范化 XML 格式。
        old_path 是完整原始路径，替换为 textures/new_name。
        处理正斜杠、反斜杠、&quot; 编码等变体，并移除 SketchUp 2025+ 不兼容的旧元素。"""
        xml_text = self._normalize_material_xml(xml_text)

        new_path = f"textures/{new_name}"

        # 构建所有可能的路径变体
        candidates = {old_path}
        if '/' in old_path:
            candidates.add(old_path.replace('/', '\\'))
        if '\\' in old_path:
            candidates.add(old_path.replace('\\', '/'))

        for candidate in candidates:
            # 直接替换（匹配 "path" 或 Value="path"）
            if candidate in xml_text:
                xml_text = xml_text.replace(candidate, new_path)
            # &quot; 编码形式: &quot;path&quot;
            quot_encoded = f'&quot;{candidate}&quot;'
            if quot_encoded in xml_text:
                xml_text = xml_text.replace(quot_encoded, f'&quot;{new_path}&quot;')

        return xml_text

    def _search_file(self, directory, filename):
        """在目录中递归搜索文件"""
        # 直接匹配
        candidate = os.path.join(directory, filename)
        if os.path.exists(candidate):
            return candidate

        # 大小写不敏感匹配
        try:
            for entry in os.scandir(directory):
                if entry.is_file() and entry.name.lower() == filename.lower():
                    return entry.path
        except PermissionError:
            pass

        # 递归搜索（限制深度避免太慢）
        try:
            for root, dirs, files in os.walk(directory):
                for f in files:
                    if f.lower() == filename.lower():
                        return os.path.join(root, f)
        except (PermissionError, OSError):
            pass

        return None


def main():
    root = tk.Tk()
    SkpTextureCopierGUI(root)
    root.mainloop()


if __name__ == '__main__':
    main()