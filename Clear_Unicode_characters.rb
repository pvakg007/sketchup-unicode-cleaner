# frozen_string_literal: true

# SketchUp 一体化插件 - 名称清理 + 贴图复制
# 功能：
#   1. 清理材质、组、组件名称中的非ASCII字符（转拼音）
#   2. 复制所有材质贴图到 textures 子目录
#   3. 非UTF-8文件名转换为拼音格式
# 所有代码合并为单文件，无需额外依赖

require 'set'

# ============================================================================
# 拼音转换模块
# ============================================================================
module PinyinConverter
  MAX_NAME_LENGTH = 30

  # 西里尔字母 → 拉丁字母同形映射（视觉相同但码点不同）
  HOMOGLYPH_MAP = {
    'а' => 'a', 'А' => 'A',  # U+0430/U+0410
    'е' => 'e', 'Е' => 'E',  # U+0435/U+0415
    'о' => 'o', 'О' => 'O',  # U+043E/U+041E
    'р' => 'p', 'Р' => 'P',  # U+0440/U+0420
    'с' => 'c', 'С' => 'C',  # U+0441/U+0421
    'у' => 'y', 'У' => 'Y',  # U+0443/U+0423
    'х' => 'x', 'Х' => 'X',  # U+0445/U+0425
    'в' => 'b', 'В' => 'B',  # U+0432/U+0412
    'н' => 'h', 'Н' => 'H',  # U+043D/U+041D
    'м' => 'm', 'М' => 'M',  # U+043C/U+041C
    'т' => 't', 'Т' => 'T',  # U+0442/U+0422
    'к' => 'k', 'К' => 'K',  # U+043A/U+041A
  }.freeze

  PINYIN_TABLE = {
    '阿' => 'a',
    '埃' => 'ai', '爱' => 'ai', '矮' => 'ai', '艾' => 'ai',
    '安' => 'an', '岸' => 'an', '按' => 'an', '暗' => 'an', '案' => 'an', '胺' => 'an',
    '凹' => 'ao', '奥' => 'ao', '奧' => 'ao', '澳' => 'ao',
    '八' => 'ba', '坝' => 'ba', '巴' => 'ba', '把' => 'ba',
    '拜' => 'bai', '柏' => 'bai', '白' => 'bai', '百' => 'bai',
    '办' => 'ban', '半' => 'ban', '斑' => 'ban', '板' => 'ban', '版' => 'ban', '班' => 'ban',
    '邦' => 'bang',
    '保' => 'bao', '刨' => 'bao', '堡' => 'bao', '宝' => 'bao', '抱' => 'bao', '苞' => 'bao', '薄' => 'bao',
    '北' => 'bei', '卑' => 'bei', '备' => 'bei', '杯' => 'bei', '背' => 'bei', '被' => 'bei', '贝' => 'bei',
    '本' => 'ben',
    '泵' => 'beng',
    '壁' => 'bi', '比' => 'bi', '毕' => 'bi', '碧' => 'bi', '笔' => 'bi', '臂' => 'bi', '鼻' => 'bi',
    '变' => 'bian', '扁' => 'bian', '编' => 'bian', '边' => 'bian',
    '标' => 'biao', '表' => 'biao',
    '别' => 'bie',
    '槟' => 'bin',
    '並' => 'bing', '冰' => 'bing', '并' => 'bing', '饼' => 'bing',
    '伯' => 'bo', '博' => 'bo', '波' => 'bo', '玻' => 'bo', '箔' => 'bo', '簸' => 'bo', '铂' => 'bo',
    '不' => 'bu', '布' => 'bu', '步' => 'bu', '补' => 'bu', '部' => 'bu',
    '擦' => 'ca',
    '彩' => 'cai', '材' => 'cai', '菜' => 'cai',
    '餐' => 'can',
    '仓' => 'cang', '沧' => 'cang', '滄' => 'cang',
    '槽' => 'cao', '糙' => 'cao', '草' => 'cao',
    '侧' => 'ce', '册' => 'ce', '厕' => 'ce', '策' => 'ce',
    '层' => 'ceng',
    '茶' => 'cha', '诧' => 'cha',
    '拆' => 'chai',
    '产' => 'chan', '铲' => 'chan',
    '厂' => 'chang', '场' => 'chang', '常' => 'chang', '长' => 'chang',
    '朝' => 'chao', '超' => 'chao',
    '车' => 'che',
    '晨' => 'chen', '沉' => 'chen', '辰' => 'chen',
    '乘' => 'cheng', '城' => 'cheng', '橙' => 'cheng', '秤' => 'cheng', '称' => 'cheng', '程' => 'cheng',
    '吃' => 'chi', '尺' => 'chi', '池' => 'chi', '翅' => 'chi', '赤' => 'chi', '齿' => 'chi',
    '虫' => 'chong',
    '丑' => 'chou', '抽' => 'chou', '绸' => 'chou', '臭' => 'chou',
    '储' => 'chu', '出' => 'chu', '初' => 'chu', '厨' => 'chu', '橱' => 'chu', '础' => 'chu',
    '传' => 'chuan', '川' => 'chuan', '穿' => 'chuan', '船' => 'chuan',
    '创' => 'chuang', '創' => 'chuang', '床' => 'chuang', '窗' => 'chuang',
    '锤' => 'chui',
    '春' => 'chun', '纯' => 'chun',
    '次' => 'ci', '瓷' => 'ci', '磁' => 'ci', '词' => 'ci',
    '丛' => 'cong', '从' => 'cong',
    '粗' => 'cu', '醋' => 'cu',
    '翠' => 'cui',
    '存' => 'cun', '寸' => 'cun',
    '大' => 'da', '打' => 'da', '搭' => 'da', '答' => 'da', '达' => 'da',
    '代' => 'dai', '带' => 'dai', '黛' => 'dai',
    '丹' => 'dan', '但' => 'dan', '单' => 'dan', '氮' => 'dan', '淡' => 'dan', '蛋' => 'dan',
    '当' => 'dang',
    '刀' => 'dao', '到' => 'dao', '岛' => 'dao', '道' => 'dao',
    '德' => 'de', '的' => 'de',
    '凳' => 'deng', '灯' => 'deng', '登' => 'deng',
    '低' => 'di', '地' => 'di', '堤' => 'di', '帝' => 'di', '底' => 'di', '廸' => 'di', '弟' => 'di', '笛' => 'di', '第' => 'di',
    '蒂' => 'di', '迪' => 'di',
    '典' => 'dian', '垫' => 'dian', '店' => 'dian', '殿' => 'dian', '点' => 'dian', '电' => 'dian', '碘' => 'dian', '靛' => 'dian', '颠' => 'dian',
    '吊' => 'diao', '调' => 'diao', '雕' => 'diao',
    '蝶' => 'die',
    '丁' => 'ding', '定' => 'ding', '订' => 'ding', '钉' => 'ding', '顶' => 'ding',
    '东' => 'dong', '冬' => 'dong', '洞' => 'dong',
    '豆' => 'dou', '都' => 'dou',
    '度' => 'du', '杜' => 'du', '肚' => 'du', '读' => 'du',
    '断' => 'duan', '段' => 'duan', '短' => 'duan', '端' => 'duan', '缎' => 'duan', '锻' => 'duan',
    '对' => 'dui',
    '吨' => 'dun', '墩' => 'dun', '敦' => 'dun', '盾' => 'dun', '蹲' => 'dun', '钝' => 'dun', '顿' => 'dun',
    '多' => 'duo',
    '俄' => 'e', '鹅' => 'e',
    '恩' => 'en',
    '二' => 'er', '儿' => 'er', '尔' => 'er', '耳' => 'er',
    '发' => 'fa', '法' => 'fa', '阀' => 'fa',
    '反' => 'fan', '梵' => 'fan', '繁' => 'fan', '范' => 'fan', '饭' => 'fan',
    '仿' => 'fang', '房' => 'fang', '放' => 'fang', '方' => 'fang', '芳' => 'fang',
    '啡' => 'fei', '妃' => 'fei', '斐' => 'fei', '绯' => 'fei', '翡' => 'fei', '菲' => 'fei', '费' => 'fei', '非' => 'fei',
    '份' => 'fen', '分' => 'fen', '粉' => 'fen', '芬' => 'fen',
    '凤' => 'feng', '峰' => 'feng', '枫' => 'feng', '缝' => 'feng', '蜂' => 'feng', '风' => 'feng',
    '佛' => 'fu', '副' => 'fu', '复' => 'fu', '夫' => 'fu', '富' => 'fu', '扶' => 'fu', '斧' => 'fu', '服' => 'fu', '浮' => 'fu',
    '父' => 'fu', '福' => 'fu', '符' => 'fu', '腹' => 'fu', '芙' => 'fu',
    '改' => 'gai', '概' => 'gai', '该' => 'gai',
    '干' => 'gan', '杆' => 'gan',
    '岗' => 'gang', '杠' => 'gang', '港' => 'gang', '钢' => 'gang',
    '糕' => 'gao', '高' => 'gao',
    '个' => 'ge', '割' => 'ge', '各' => 'ge', '哥' => 'ge', '格' => 'ge', '歌' => 'ge', '铬' => 'ge', '阁' => 'ge', '革' => 'ge', '鸽' => 'ge',
    '给' => 'gei',
    '根' => 'gen',
    '供' => 'gong', '公' => 'gong', '宫' => 'gong', '工' => 'gong', '弓' => 'gong', '拱' => 'gong', '汞' => 'gong',
    '沟' => 'gou', '狗' => 'gou', '钩' => 'gou',
    '古' => 'gu', '姑' => 'gu', '谷' => 'gu', '骨' => 'gu', '鼓' => 'gu',
    '刮' => 'gua', '挂' => 'gua',
    '关' => 'guan', '灌' => 'guan', '管' => 'guan', '罐' => 'guan', '观' => 'guan', '馆' => 'guan',
    '光' => 'guang', '广' => 'guang',
    '柜' => 'gui', '桂' => 'gui', '瑰' => 'gui', '硅' => 'gui', '规' => 'gui', '贵' => 'gui',
    '国' => 'guo', '果' => 'guo', '过' => 'guo', '锅' => 'guo',
    '哈' => 'ha',
    '海' => 'hai', '还' => 'hai',
    '寒' => 'han', '汉' => 'han', '焊' => 'han',
    '号' => 'hao', '好' => 'hao', '浩' => 'hao',
    '合' => 'he', '和' => 'he', '喝' => 'he', '河' => 'he', '盒' => 'he', '荷' => 'he', '褐' => 'he', '鹤' => 'he',
    '黑' => 'hei',
    '很' => 'hen', '痕' => 'hen',
    '横' => 'heng',
    '红' => 'hong', '虹' => 'hong', '鸿' => 'hong',
    '厚' => 'hou', '后' => 'hou',
    '壶' => 'hu', '弧' => 'hu', '户' => 'hu', '湖' => 'hu', '狐' => 'hu', '琥' => 'hu', '瑚' => 'hu', '胡' => 'hu', '虎' => 'hu',
    '划' => 'hua', '化' => 'hua', '华' => 'hua', '滑' => 'hua', '画' => 'hua', '畫' => 'hua', '花' => 'hua', '话' => 'hua',
    '坏' => 'huai',
    '幻' => 'huan', '换' => 'huan', '环' => 'huan',
    '凰' => 'huang', '皇' => 'huang', '荒' => 'huang', '黄' => 'huang',
    '会' => 'hui', '卉' => 'hui', '回' => 'hui', '灰' => 'hui', '绘' => 'hui', '辉' => 'hui',
    '昏' => 'hun', '混' => 'hun',
    '或' => 'huo', '活' => 'huo', '火' => 'huo', '霍' => 'huo',
    '几' => 'ji', '及' => 'ji', '圾' => 'ji', '基' => 'ji', '季' => 'ji', '寂' => 'ji', '技' => 'ji', '机' => 'ji', '极' => 'ji',
    '济' => 'ji', '矶' => 'ji', '級' => 'ji', '级' => 'ji', '纪' => 'ji', '肌' => 'ji', '计' => 'ji', '记' => 'ji', '际' => 'ji',
    '集' => 'ji', '鸡' => 'ji',
    '佳' => 'jia', '假' => 'jia', '加' => 'jia', '夹' => 'jia', '家' => 'jia', '架' => 'jia', '甲' => 'jia',
    '件' => 'jian', '减' => 'jian', '剑' => 'jian', '剪' => 'jian', '尖' => 'jian', '建' => 'jian', '渐' => 'jian', '简' => 'jian', '肩' => 'jian',
    '贱' => 'jian', '间' => 'jian',
    '匠' => 'jiang', '将' => 'jiang', '江' => 'jiang', '浆' => 'jiang', '绛' => 'jiang', '酱' => 'jiang', '降' => 'jiang',
    '浇' => 'jiao', '礁' => 'jiao', '胶' => 'jiao', '脚' => 'jiao', '角' => 'jiao', '铰' => 'jiao', '饺' => 'jiao',
    '介' => 'jie', '姐' => 'jie', '接' => 'jie', '洁' => 'jie', '界' => 'jie', '节' => 'jie', '阶' => 'jie',
    '斤' => 'jin', '津' => 'jin', '紧' => 'jin', '进' => 'jin', '金' => 'jin', '锦' => 'jin',
    '井' => 'jing', '京' => 'jing', '净' => 'jing', '境' => 'jing', '径' => 'jing', '惊' => 'jing', '景' => 'jing', '晶' => 'jing', '精' => 'jing',
    '茎' => 'jing', '镜' => 'jing', '静' => 'jing', '颈' => 'jing',
    '九' => 'jiu', '旧' => 'jiu', '究' => 'jiu', '舅' => 'jiu', '酒' => 'jiu',
    '举' => 'ju', '具' => 'ju', '剧' => 'ju', '局' => 'ju', '居' => 'ju', '榉' => 'ju', '菊' => 'ju', '锯' => 'ju',
    '卷' => 'juan',
    '爵' => 'jue',
    '军' => 'jun', '菌' => 'jun',
    '卡' => 'ka', '咖' => 'ka',
    '凯' => 'kai', '开' => 'kai',
    '看' => 'kan', '砍' => 'kan',
    '康' => 'kang', '抗' => 'kang',
    '拷' => 'kao', '烤' => 'kao',
    '克' => 'ke', '刻' => 'ke', '可' => 'ke', '客' => 'ke', '柯' => 'ke', '科' => 'ke', '课' => 'ke',
    '肯' => 'ken',
    '坑' => 'keng',
    '孔' => 'kong', '空' => 'kong',
    '口' => 'kou', '扣' => 'kou', '蔻' => 'kou',
    '哭' => 'ku', '库' => 'ku', '苦' => 'ku', '裤' => 'ku', '酷' => 'ku',
    '跨' => 'kua',
    '块' => 'kuai', '快' => 'kuai',
    '宽' => 'kuan', '款' => 'kuan',
    '框' => 'kuang', '矿' => 'kuang', '筐' => 'kuang',
    '昆' => 'kun',
    '垃' => 'la', '拉' => 'la', '腊' => 'la', '辣' => 'la',
    '来' => 'lai', '莱' => 'lai',
    '兰' => 'lan', '栏' => 'lan', '篮' => 'lan', '蓝' => 'lan', '藍' => 'lan',
    '廊' => 'lang', '朗' => 'lang', '浪' => 'lang',
    '劳' => 'lao', '勞' => 'lao', '老' => 'lao',
    '类' => 'lei', '雷' => 'lei',
    '冷' => 'leng', '棱' => 'leng',
    '丽' => 'li', '利' => 'li', '力' => 'li', '栗' => 'li', '梨' => 'li', '沥' => 'li', '理' => 'li', '璃' => 'li', '砾' => 'li',
    '立' => 'li', '粒' => 'li', '莉' => 'li', '里' => 'li',
    '帘' => 'lian', '廉' => 'lian', '脸' => 'lian', '莲' => 'lian', '连' => 'lian', '链' => 'lian',
    '两' => 'liang', '亮' => 'liang', '凉' => 'liang', '梁' => 'liang',
    '料' => 'liao',
    '列' => 'lie', '烈' => 'lie',
    '林' => 'lin', '磷' => 'lin',
    '凌' => 'ling', '岭' => 'ling', '玲' => 'ling', '菱' => 'ling', '零' => 'ling', '领' => 'ling',
    '六' => 'liu', '柳' => 'liu', '流' => 'liu', '硫' => 'liu', '鎏' => 'liu',
    '珑' => 'long', '瓏' => 'long', '胧' => 'long', '龙' => 'long',
    '楼' => 'lou',
    '卢' => 'lu', '炉' => 'lu', '路' => 'lu', '露' => 'lu', '魯' => 'lu', '鲁' => 'lu', '鹭' => 'lu', '鹿' => 'lu',
    '乱' => 'luan',
    '伦' => 'lun', '倫' => 'lun', '轮' => 'lun',
    '洛' => 'luo', '络' => 'luo', '罗' => 'luo', '羅' => 'luo', '落' => 'luo', '螺' => 'luo', '裸' => 'luo',
    '氯' => 'lv', '綠' => 'lv', '绿' => 'lv', '铝' => 'lv',
    '玛' => 'ma', '瑪' => 'ma', '馬' => 'ma', '马' => 'ma', '麻' => 'ma',
    '脉' => 'mai', '麦' => 'mai',
    '慢' => 'man', '曼' => 'man', '满' => 'man', '漫' => 'man',
    '忙' => 'mang',
    '帽' => 'mao', '毛' => 'mao', '猫' => 'mao', '铆' => 'mao',
    '妹' => 'mei', '梅' => 'mei', '玫' => 'mei', '美' => 'mei', '魅' => 'mei',
    '门' => 'men',
    '孟' => 'meng', '朦' => 'meng', '梦' => 'meng', '檬' => 'meng', '蒙' => 'meng', '锰' => 'meng',
    '密' => 'mi', '秘' => 'mi', '米' => 'mi', '蜜' => 'mi', '迷' => 'mi',
    '免' => 'mian', '棉' => 'mian', '面' => 'mian',
    '苗' => 'miao',
    '名' => 'ming', '明' => 'ming',
    '墨' => 'mo', '摩' => 'mo', '末' => 'mo', '模' => 'mo', '漠' => 'mo', '磨' => 'mo', '膜' => 'mo', '莫' => 'mo', '默' => 'mo',
    '姆' => 'mu', '幕' => 'mu', '慕' => 'mu', '暮' => 'mu', '木' => 'mu', '母' => 'mu',
    '娜' => 'na', '拿' => 'na', '纳' => 'na', '那' => 'na',
    '奶' => 'nai', '耐' => 'nai',
    '南' => 'nan', '楠' => 'nan', '难' => 'nan',
    '瑙' => 'nao', '脑' => 'nao',
    '内' => 'nei',
    '能' => 'neng',
    '妮' => 'ni', '尼' => 'ni', '拟' => 'ni', '泥' => 'ni',
    '年' => 'nian', '念' => 'nian',
    '鸟' => 'niao',
    '镍' => 'nie',
    '凝' => 'ning', '柠' => 'ning',
    '牛' => 'niu', '纽' => 'niu',
    '浓' => 'nong',
    '努' => 'nu',
    '暖' => 'nuan',
    '挪' => 'nuo', '諾' => 'nuo', '诺' => 'nuo',
    '女' => 'nv',
    '欧' => 'ou', '殴' => 'ou', '藕' => 'ou',
    '帕' => 'pa',
    '拍' => 'pai', '排' => 'pai', '牌' => 'pai',
    '潘' => 'pan', '盘' => 'pan',
    '旁' => 'pang',
    '抛' => 'pao',
    '佩' => 'pei', '裴' => 'pei', '配' => 'pei',
    '喷' => 'pen', '盆' => 'pen',
    '朋' => 'peng', '棚' => 'peng',
    '劈' => 'pi', '批' => 'pi', '皮' => 'pi',
    '偏' => 'pian', '片' => 'pian', '篇' => 'pian',
    '漂' => 'piao', '票' => 'piao', '飘' => 'piao',
    '品' => 'pin', '拼' => 'pin', '频' => 'pin',
    '屏' => 'ping', '平' => 'ping', '瓶' => 'ping',
    '坡' => 'po', '泼' => 'po', '珀' => 'po', '破' => 'po',
    '剖' => 'pou',
    '普' => 'pu', '蒲' => 'pu', '铺' => 'pu',
    '七' => 'qi', '其' => 'qi', '器' => 'qi', '奇' => 'qi', '妻' => 'qi', '旗' => 'qi', '棋' => 'qi', '气' => 'qi', '漆' => 'qi',
    '绮' => 'qi', '起' => 'qi', '齐' => 'qi',
    '前' => 'qian', '千' => 'qian', '浅' => 'qian', '淺' => 'qian', '签' => 'qian', '铅' => 'qian',
    '墙' => 'qiang', '强' => 'qiang', '枪' => 'qiang',
    '乔' => 'qiao', '俏' => 'qiao', '敲' => 'qiao', '桥' => 'qiao',
    '切' => 'qie',
    '琴' => 'qin',
    '情' => 'qing', '氢' => 'qing', '清' => 'qing', '轻' => 'qing', '青' => 'qing',
    '穷' => 'qiong',
    '楸' => 'qiu', '秋' => 'qiu',
    '区' => 'qu', '去' => 'qu', '曲' => 'qu', '渠' => 'qu',
    '全' => 'quan', '圈' => 'quan', '泉' => 'quan',
    '缺' => 'que', '雀' => 'que',
    '裙' => 'qun',
    '染' => 'ran', '然' => 'ran',
    '让' => 'rang',
    '热' => 're',
    '人' => 'ren', '仍' => 'reng', '扔' => 'reng',
    '日' => 'ri',
    '绒' => 'rong', '柔' => 'rong', '肉' => 'rong',
    '入' => 'ru', '如' => 'ru', '褥' => 'ru',
    '软' => 'ruan',
    '瑞' => 'rui', '锐' => 'rui',
    '润' => 'run',
    '弱' => 'ruo',
    '撒' => 'sa', '萨' => 'sa', '薩' => 'sa',
    '塞' => 'sai', '赛' => 'sai',
    '三' => 'san', '伞' => 'san',
    '桑' => 'sang',
    '瑟' => 'se', '色' => 'se',
    '森' => 'sen',
    '沙' => 'sha', '砂' => 'sha', '莎' => 'sha',
    '删' => 'shan', '山' => 'shan', '扇' => 'shan', '杉' => 'shan', '珊' => 'shan', '衫' => 'shan', '闪' => 'shan',
    '上' => 'shang', '商' => 'shang', '尚' => 'shang', '裳' => 'shang',
    '少' => 'shao', '烧' => 'shao', '绍' => 'shao', '邵' => 'shao',
    '奢' => 'she', '射' => 'she', '舌' => 'she', '舍' => 'she', '蛇' => 'she', '设' => 'she',
    '深' => 'shen', '燊' => 'shen', '神' => 'shen', '绅' => 'shen',
    '升' => 'sheng', '圣' => 'sheng', '生' => 'sheng', '绳' => 'sheng',
    '世' => 'shi', '事' => 'shi', '仕' => 'shi', '使' => 'shi', '十' => 'shi', '士' => 'shi', '实' => 'shi', '室' => 'shi', '市' => 'shi',
    '式' => 'shi', '施' => 'shi', '时' => 'shi', '時' => 'shi', '湿' => 'shi', '石' => 'shi', '示' => 'shi', '视' => 'shi', '诗' => 'shi',
    '适' => 'shi', '饰' => 'shi',
    '手' => 'shou', '收' => 'shou', '首' => 'shou',
    '书' => 'shu', '叔' => 'shu', '墅' => 'shu', '属' => 'shu', '术' => 'shu', '树' => 'shu', '殊' => 'shu', '熟' => 'shu', '疏' => 'shu',
    '竖' => 'shu', '鼠' => 'shu',
    '刷' => 'shua',
    '帅' => 'shuai',
    '栓' => 'shuan',
    '双' => 'shuang', '霜' => 'shuang',
    '水' => 'shui', '睡' => 'shui',
    '烁' => 'shuo', '说' => 'shuo',
    '丝' => 'si', '四' => 'si', '思' => 'si', '撕' => 'si', '斯' => 'si', '絲' => 'si',
    '松' => 'song',
    '塑' => 'su', '素' => 'su', '苏' => 'su',
    '算' => 'suan', '酸' => 'suan',
    '岁' => 'sui', '碎' => 'sui', '穗' => 'sui', '邃' => 'sui',
    '孙' => 'sun', '损' => 'sun',
    '所' => 'suo', '索' => 'suo', '锁' => 'suo',
    '他' => 'ta', '塔' => 'ta', '榻' => 'ta', '踏' => 'ta',
    '台' => 'tai', '太' => 'tai', '态' => 'tai', '抬' => 'tai', '汰' => 'tai', '钛' => 'tai',
    '探' => 'tan', '檀' => 'tan', '毯' => 'tan', '滩' => 'tan', '潭' => 'tan', '炭' => 'tan', '碳' => 'tan',
    '堂' => 'tang', '塘' => 'tang', '棠' => 'tang', '汤' => 'tang', '糖' => 'tang', '躺' => 'tang',
    '套' => 'tao', '桃' => 'tao', '淘' => 'tao', '陶' => 'tao',
    '特' => 'te',
    '藤' => 'teng',
    '体' => 'ti', '提' => 'ti', '梯' => 'ti', '瑅' => 'ti', '缇' => 'ti', '题' => 'ti',
    '天' => 'tian', '甜' => 'tian',
    '条' => 'tiao',
    '帖' => 'tie', '贴' => 'tie', '铁' => 'tie',
    '厅' => 'ting', '听' => 'ting', '庭' => 'ting',
    '通' => 'tong', '铜' => 'tong',
    '头' => 'tou', '透' => 'tou',
    '兔' => 'tu', '凸' => 'tu', '图' => 'tu', '土' => 'tu', '涂' => 'tu', '突' => 'tu',
    '推' => 'tui',
    '托' => 'tuo', '脱' => 'tuo', '驼' => 'tuo',
    '瓦' => 'wa', '袜' => 'wa',
    '外' => 'wai',
    '万' => 'wan', '弯' => 'wan', '晚' => 'wan', '湾' => 'wan', '碗' => 'wan',
    '往' => 'wang', '旺' => 'wang', '王' => 'wang', '网' => 'wang',
    '为' => 'wei', '卫' => 'wei', '唯' => 'wei', '威' => 'wei', '尾' => 'wei', '微' => 'wei', '未' => 'wei', '维' => 'wei', '蔚' => 'wei',
    '韦' => 'wei', '魏' => 'wei',
    '文' => 'wen', '温' => 'wen', '紋' => 'wen', '纹' => 'wen', '问' => 'wen',
    '卧' => 'wo', '沃' => 'wo',
    '乌' => 'wu', '五' => 'wu', '务' => 'wu', '午' => 'wu', '屋' => 'wu', '无' => 'wu', '武' => 'wu', '物' => 'wu', '舞' => 'wu',
    '钨' => 'wu', '雾' => 'wu', '霧' => 'wu',
    '吸' => 'xi', '夕' => 'xi', '希' => 'xi', '席' => 'xi', '惜' => 'xi', '戏' => 'xi', '洗' => 'xi', '溪' => 'xi', '系' => 'xi',
    '細' => 'xi', '细' => 'xi', '膝' => 'xi', '西' => 'xi', '锡' => 'xi',
    '下' => 'xia', '夏' => 'xia', '峡' => 'xia',
    '仙' => 'xian', '咸' => 'xian', '显' => 'xian', '现' => 'xian', '纤' => 'xian', '线' => 'xian', '闲' => 'xian', '限' => 'xian',
    '像' => 'xiang', '向' => 'xiang', '想' => 'xiang', '橡' => 'xiang', '相' => 'xiang', '祥' => 'xiang', '箱' => 'xiang', '象' => 'xiang',
    '项' => 'xiang', '香' => 'xiang',
    '削' => 'xiao', '小' => 'xiao', '效' => 'xiao', '晓' => 'xiao', '笑' => 'xiao', '箫' => 'xiao', '销' => 'xiao',
    '写' => 'xie', '斜' => 'xie', '鞋' => 'xie',
    '信' => 'xin', '心' => 'xin', '新' => 'xin', '芯' => 'xin', '锌' => 'xin',
    '型' => 'xing', '形' => 'xing', '星' => 'xing', '杏' => 'xing', '醒' => 'xing',
    '兄' => 'xiong', '熊' => 'xiong', '胸' => 'xiong',
    '休' => 'xiu', '修' => 'xiu', '溴' => 'xiu', '绣' => 'xiu', '袖' => 'xiu', '銹' => 'xiu', '锈' => 'xiu',
    '序' => 'xu', '需' => 'xu', '须' => 'xu',
    '宣' => 'xuan', '玄' => 'xuan', '轩' => 'xuan', '选' => 'xuan',
    '学' => 'xue', '血' => 'xue', '雪' => 'xue',
    '循' => 'xun', '熏' => 'xun', '逊' => 'xun',
    '亚' => 'ya', '亞' => 'ya', '压' => 'ya', '哑' => 'ya', '崖' => 'ya', '牙' => 'ya', '芽' => 'ya', '雅' => 'ya', '鸭' => 'ya',
    '岩' => 'yan', '檐' => 'yan', '演' => 'yan', '烟' => 'yan', '盐' => 'yan', '眼' => 'yan', '研' => 'yan', '砚' => 'yan', '言' => 'yan',
    '颜' => 'yan',
    '样' => 'yang', '氧' => 'yang', '洋' => 'yang', '羊' => 'yang', '阳' => 'yang',
    '腰' => 'yao', '要' => 'yao', '钥' => 'yao',
    '业' => 'ye', '也' => 'ye', '叶' => 'ye', '夜' => 'ye', '爷' => 'ye', '耶' => 'ye', '野' => 'ye', '页' => 'ye',
    '一' => 'yi', '亿' => 'yi', '以' => 'yi', '伊' => 'yi', '姨' => 'yi', '已' => 'yi', '异' => 'yi', '意' => 'yi', '易' => 'yi',
    '椅' => 'yi', '移' => 'yi', '绎' => 'yi', '翼' => 'yi', '艺' => 'yi', '蚁' => 'yi', '衣' => 'yi', '议' => 'yi', '逸' => 'yi',
    '印' => 'yin', '因' => 'yin', '殷' => 'yin', '銀' => 'yin', '银' => 'yin',
    '应' => 'ying', '影' => 'ying', '樱' => 'ying', '硬' => 'ying', '英' => 'ying',
    '用' => 'yong',
    '优' => 'you', '友' => 'you', '右' => 'you', '尤' => 'you', '有' => 'you', '柚' => 'you', '油' => 'you', '釉' => 'you',
    '与' => 'yu', '域' => 'yu', '愉' => 'yu', '浴' => 'yu', '玉' => 'yu', '羽' => 'yu', '萸' => 'yu', '语' => 'yu', '郁' => 'yu',
    '雨' => 'yu', '预' => 'yu', '魚' => 'yu', '鱼' => 'yu',
    '元' => 'yuan', '原' => 'yuan', '园' => 'yuan', '圆' => 'yuan', '垣' => 'yuan', '缘' => 'yuan', '远' => 'yuan', '院' => 'yuan',
    '悦' => 'yue', '月' => 'yue', '约' => 'yue', '越' => 'yue',
    '云' => 'yun', '匀' => 'yun', '运' => 'yun',
    '杂' => 'za',
    '再' => 'zai', '在' => 'zai', '载' => 'zai',
    '脏' => 'zang',
    '噪' => 'zao', '早' => 'zao', '灶' => 'zao', '藻' => 'zao', '造' => 'zao',
    '泽' => 'ze',
    '增' => 'zeng',
    '扎' => 'zha',
    '斋' => 'zhai', '窄' => 'zhai',
    '占' => 'zhan', '站' => 'zhan',
    '丈' => 'zhang', '张' => 'zhang', '掌' => 'zhang', '樟' => 'zhang', '章' => 'zhang',
    '找' => 'zhao', '沼' => 'zhao', '照' => 'zhao', '罩' => 'zhao',
    '折' => 'zhe', '浙' => 'zhe', '赭' => 'zhe',
    '枕' => 'zhen', '榛' => 'zhen', '珍' => 'zhen', '真' => 'zhen', '臻' => 'zhen', '针' => 'zhen', '镇' => 'zhen',
    '整' => 'zheng', '正' => 'zheng', '筝' => 'zheng', '证' => 'zheng',
    '之' => 'zhi', '制' => 'zhi', '只' => 'zhi', '志' => 'zhi', '指' => 'zhi', '智' => 'zhi', '枝' => 'zhi', '直' => 'zhi', '纸' => 'zhi',
    '织' => 'zhi', '脂' => 'zhi', '至' => 'zhi', '致' => 'zhi', '质' => 'zhi', '趾' => 'zhi',
    '中' => 'zhong', '种' => 'zhong', '重' => 'zhong', '钟' => 'zhong',
    '宙' => 'zhou', '洲' => 'zhou', '轴' => 'zhou',
    '主' => 'zhu', '柱' => 'zhu', '烛' => 'zhu', '猪' => 'zhu', '珠' => 'zhu', '竹' => 'zhu', '茱' => 'zhu', '铸' => 'zhu',
    '抓' => 'zhua',
    '专' => 'zhuan', '砖' => 'zhuan', '转' => 'zhuan',
    '状' => 'zhuang', '装' => 'zhuang',
    '追' => 'zhui',
    '准' => 'zhun',
    '桌' => 'zhuo', '浊' => 'zhuo',
    '兹' => 'zi', '子' => 'zi', '字' => 'zi', '紫' => 'zi', '自' => 'zi', '资' => 'zi',
    '总' => 'zong', '棕' => 'zong', '粽' => 'zong', '踪' => 'zong',
    '走' => 'zou',
    '族' => 'zu', '祖' => 'zu', '组' => 'zu', '足' => 'zu',
    '钻' => 'zuan',
    '最' => 'zui',
    '尊' => 'zun',
    '作' => 'zuo', '做' => 'zuo', '坐' => 'zuo', '左' => 'zuo',
  }.freeze

  def self.convert(text)
    return '' if text.nil? || text.empty?

    segments = []
    buffer = ''

    text.chars.each do |char|
      if char.ascii_only?
        buffer += char
      elsif HOMOGLYPH_MAP.key?(char)
        buffer += HOMOGLYPH_MAP[char]
      else
        if !buffer.empty?
          segments << buffer
          buffer = ''
        end
        if PINYIN_TABLE.key?(char)
          val = PINYIN_TABLE[char]
          segments << val unless val.empty?
        else
          segments << char.codepoints.first.to_s(16)
        end
      end
    end
    segments << buffer unless buffer.empty?

    result = segments.join('_')
    result = result.downcase
    result = result.gsub(/[^\w\-]/, '')
    result = result.gsub(/_+/, '_').gsub(/^_|_$/, '')

    result.empty? ? '' : (result.length > MAX_NAME_LENGTH ? result[0, MAX_NAME_LENGTH] : result)
  end

  def self.needs_conversion?(text)
    !text.nil? && !text.empty? && !text.ascii_only?
  end
end

# ============================================================================
# Common utilities
# ============================================================================
module NameCleanerPlugin
  module Utilities
    MAX_NAME_LEN = 30

    def clean_text(text)
      return '' if text.nil? || text.empty?
      converted = PinyinConverter.convert(text)
      converted.empty? ? '' : converted
    end

    def generate_unique_name(base_name, existing_names, prefix = 'Item')
      base = base_name.length > MAX_NAME_LEN ? base_name[0, MAX_NAME_LEN] : base_name
      return base unless existing_names.include?(base)
      truncated = base.length > 25 ? base[0, 25] : base
      counter = 1
      loop do
        candidate = "#{truncated}_#{counter}"
        candidate = candidate[0, MAX_NAME_LEN] if candidate.length > MAX_NAME_LEN
        return candidate unless existing_names.include?(candidate)
        counter += 1
      end
    end

    def generate_random_name(existing_names, prefix = 'Item')
      loop do
        random_name = "#{prefix}_#{rand(100_000..999_999)}"
        return random_name unless existing_names.include?(random_name)
      end
    end

    def contains_furniture_chinese?(text)
      return false if text.nil? || text.empty?
      %w[柜 板 金 抽 拉 铰 桌 上 下 左 右 顶 底].any? { |char| text.include?(char) }
    end

    def name_already_clean?(name)
      return false if name.nil? || name.empty?
      return false unless name.ascii_only?
      return false unless name.match?(/\A[\w\-]+\z/)
      return false if name.length > MAX_NAME_LEN
      true
    end

    def safe_operation(operation_name, model)
      model.start_operation(operation_name, true)
      yield
      model.commit_operation
    rescue => e
      begin
        model.abort_operation
      rescue
        nil
      end
      UI.messagebox("#{operation_name}失败: #{e.message}")
    end
  end

  # 材质清理器
  class MaterialCleaner
    include Utilities

    def initialize
      @model = Sketchup.active_model
      @existing_names = Set.new
    end

    def execute
      return UI.messagebox('没有打开的模型') unless @model
      safe_operation('材质名称清理', @model) { perform_cleanup }
    end

    private

    def perform_cleanup
      materials = @model.materials
      changed_count = 0
      skipped_count = 0
      materials.each { |mat| @existing_names.add(mat.name) if mat.name && !mat.name.empty? }
      materials.each do |material|
        original_name = material.name || ''

        if name_already_clean?(original_name)
          skipped_count += 1
          next
        end

        clean_name = clean_text(original_name)
        clean_name = generate_random_name(@existing_names, 'Material') if clean_name.empty?
        final_name = find_unique_material_name(clean_name, original_name)
        if final_name != original_name
          material.name = final_name
          @existing_names.add(final_name)
          changed_count += 1
        end
      end
      UI.messagebox("材质名称清理完成！\n处理: #{materials.size} 个材质\n重命名: #{changed_count} 个\n跳过: #{skipped_count} 个")
    end

    def find_unique_material_name(base_name, original_name)
      candidate = generate_unique_name(base_name, @existing_names)
      return candidate if candidate == original_name
      counter = 1
      while @model.materials[candidate] && candidate != original_name
        truncated = candidate.length > 25 ? candidate[0, 25] : candidate
        candidate = "#{truncated}_#{counter}"
        candidate = candidate[0, MAX_NAME_LEN] if candidate.length > MAX_NAME_LEN
        counter += 1
      end
      @existing_names.add(candidate)
      candidate
    end
  end

  # 组和组件清理器
  class GroupComponentCleaner
    include Utilities

    def initialize(skip_chinese: false)
      @model = Sketchup.active_model
      @existing_names = Set.new
      @skip_chinese = skip_chinese
      @stats = { processed: 0, renamed: 0, skipped: 0 }
    end

    def execute
      return UI.messagebox('没有打开的模型') unless @model
      safe_operation('组和组件名称清理', @model) { perform_cleanup }
    end

    private

    def perform_cleanup
      collect_existing_names(@model.entities)
      process_entities(@model.entities)
      show_results
    end

    def collect_existing_names(entities)
      entities.each do |entity|
        case entity
        when Sketchup::Group
          @existing_names.add(entity.name) if entity.name && !entity.name.empty?
          collect_existing_names(entity.entities) if entity.entities.any?
        when Sketchup::ComponentInstance
          @existing_names.add(entity.name) if entity.name && !entity.name.empty?
          @existing_names.add(entity.definition.name) if entity.definition.name && !entity.definition.name.empty?
          collect_existing_names(entity.definition.entities) if entity.definition.entities.any?
        end
      end
    end

    def process_entities(entities)
      entities.each do |entity|
        case entity
        when Sketchup::Group then process_group(entity)
        when Sketchup::ComponentInstance then process_component(entity)
        end
      end
    end

    def process_group(group)
      original_name = group.name || ''
      if @skip_chinese && contains_furniture_chinese?(original_name)
        @stats[:skipped] += 1
        @stats[:processed] += 1
        process_entities(group.entities) if group.entities.any?
        return
      end
      if name_already_clean?(original_name)
        @stats[:processed] += 1
        process_entities(group.entities) if group.entities.any?
        return
      end
      clean_name = clean_text(original_name)
      if clean_name.empty?
        new_name = generate_random_name(@existing_names, 'Group')
        group.name = new_name
        @existing_names.add(new_name)
        @stats[:renamed] += 1
      elsif original_name != clean_name
        final_name = generate_unique_name(clean_name, @existing_names)
        group.name = final_name
        @existing_names.add(final_name)
        @stats[:renamed] += 1
      end
      @stats[:processed] += 1
      process_entities(group.entities) if group.entities.any?
    end

    def process_component(component)
      definition = component.definition
      original_def_name = definition.name || ''
      if @skip_chinese && contains_furniture_chinese?(original_def_name)
        @stats[:skipped] += 1
        @stats[:processed] += 1
        process_entities(definition.entities) if definition.entities.any?
        return
      end
      if name_already_clean?(original_def_name)
        @stats[:processed] += 1
        process_entities(definition.entities) if definition.entities.any?
        return
      end
      clean_def_name = clean_text(original_def_name)
      definition_renamed = false
      if clean_def_name.empty?
        new_name = generate_random_name(@existing_names, 'Component')
        definition.name = new_name
        @existing_names.add(new_name)
        @stats[:renamed] += 1
        definition_renamed = true
      elsif original_def_name != clean_def_name
        final_name = generate_unique_name(clean_def_name, @existing_names)
        definition.name = final_name
        @existing_names.add(final_name)
        @stats[:renamed] += 1
        definition_renamed = true
      end
      unless definition_renamed
        original_inst_name = component.name || ''
        if name_already_clean?(original_inst_name)
          # skip
        elsif !(@skip_chinese && contains_furniture_chinese?(original_inst_name))
          clean_inst_name = clean_text(original_inst_name)
          if !clean_inst_name.empty? && original_inst_name != clean_inst_name
            final_name = generate_unique_name(clean_inst_name, @existing_names)
            component.name = final_name
            @existing_names.add(final_name)
            @stats[:renamed] += 1
          end
        end
      end
      @stats[:processed] += 1
      process_entities(definition.entities) if definition.entities.any?
    end

    def show_results
      summary = "组和组件名称清理完成！\n\n" \
                "处理的项目: #{@stats[:processed]}\n" \
                "重命名的项目: #{@stats[:renamed]}\n"
      summary += "跳过的家具项目: #{@stats[:skipped]}\n" if @skip_chinese
      UI.messagebox(summary)
    end
  end
end

# ============================================================================
# Texture copier
# ============================================================================
module TextureCopier
  extend self

  def copy_all_textures
    model = Sketchup.active_model
    unless model.path && !model.path.empty?
      UI.messagebox('请先保存模型文件！')
      return nil
    end
    model_dir = File.dirname(model.path)
    textures_dir = File.join(model_dir, 'textures')
    Dir.mkdir(textures_dir) unless Dir.exist?(textures_dir)
    results = { copied: [], renamed: [], errors: [] }
    used_names = {}
    model.materials.to_a.each do |material|
      process_material(material, textures_dir, results, used_names)
    end
    show_results(results)
    results
  end

  private

  def process_material(material, textures_dir, results, used_names)
    texture = material.texture
    return unless texture
    original_path = texture.filename
    original_name = File.basename(original_path)
    ext = File.extname(original_name)
    base_name = generate_base_name(original_name, ext, results)
    new_name = resolve_conflict(base_name, ext, used_names)
    new_path = File.join(textures_dir, new_name)
    original_width = texture.width
    original_height = texture.height
    texture.write(new_path)
    if original_width > 0 && original_height > 0
      material.texture = [new_path, original_width, original_height]
    else
      material.texture = new_path
    end
    results[:copied] << { material: material.name, original: original_name, new: new_name }
  rescue => e
    results[:errors] << { material: material.name, original: original_name, error: e.message }
  end

  def generate_base_name(original_name, ext, results)
    name_without_ext = File.basename(original_name, ext)
    if PinyinConverter.needs_conversion?(name_without_ext)
      converted = PinyinConverter.convert(name_without_ext)
      results[:renamed] << { original: original_name, converted: "#{converted}#{ext}" }
      converted
    else
      name_without_ext
    end
  end

  def resolve_conflict(base_name, ext, used_names)
    candidate = "#{base_name}#{ext}"
    return candidate unless used_names[candidate]
    max_base = 25
    truncated = base_name.length > max_base ? base_name[0, max_base] : base_name
    counter = 1
    loop do
      candidate = "#{truncated}_#{counter}#{ext}"
      break unless used_names[candidate]
      counter += 1
    end
    used_names[candidate] = true
    candidate
  end

  def show_results(results)
    copied_count = results[:copied].size
    renamed_count = results[:renamed].size
    error_count = results[:errors].size
    msg = "贴图复制完成！\n\n复制贴图: #{copied_count} 个\n"
    if renamed_count > 0
      msg += "重命名: #{renamed_count} 个\n"
      msg += "\n重命名详情:\n"
      results[:renamed].each { |item| msg += "  #{item[:original]} -> #{item[:converted]}\n" }
    end
    if error_count > 0
      msg += "\n错误: #{error_count} 个\n"
      results[:errors].each { |item| msg += "  #{item[:material]}: #{item[:error]}\n" }
    end
    msg += "\n贴图已保存到模型目录的 textures 子文件夹中。"
    UI.messagebox(msg)
  end
end

# ============================================================================
# Menu registration
# ============================================================================
unless file_loaded?(__FILE__)
  menu_locations = ['Extensions', 'Plugins', '扩展', '插件']

  extensions_menu = nil
  menu_locations.each do |menu_name|
    begin
      extensions_menu = UI.menu(menu_name)
      break if extensions_menu
    rescue
      next
    end
  end

  menu = extensions_menu || UI.menu
  submenu = menu.add_submenu('名称清理工具')

  submenu.add_item('清理材质名称') { NameCleanerPlugin::MaterialCleaner.new.execute }
  submenu.add_separator
  submenu.add_item('清理组和组件（跳过家具）') { NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: true).execute }
  submenu.add_item('清理组和组件（全部清理）') { NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: false).execute }
  submenu.add_separator
  submenu.add_item('全部清理（跳过家具）') do
    NameCleanerPlugin::MaterialCleaner.new.execute
    NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: true).execute
  end
  submenu.add_item('全部清理（不跳过）') do
    NameCleanerPlugin::MaterialCleaner.new.execute
    NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: false).execute
  end
  submenu.add_separator
  submenu.add_item('复制贴图并重命名UTF-8') { TextureCopier.copy_all_textures }

  puts "名称清理插件菜单已创建"
  file_loaded(__FILE__)
end
