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

  PINYIN_TABLE = {
    '贴' => 'tie', '图' => 'tu', '材' => 'cai', '质' => 'zhi',
    '木' => 'mu', '石' => 'shi', '砖' => 'zhuan', '瓦' => 'wa',
    '板' => 'ban', '块' => 'kuai', '片' => 'pian', '层' => 'ceng',
    '面' => 'mian', '纹' => 'wen', '理' => 'li', '漆' => 'qi',
    '涂' => 'tu', '料' => 'liao', '粉' => 'fen', '泥' => 'ni',
    '沙' => 'sha', '土' => 'tu', '岩' => 'yan', '矿' => 'kuang',
    '金' => 'jin', '银' => 'yin', '铜' => 'tong', '铁' => 'tie',
    '钢' => 'gang', '铝' => 'lv', '塑' => 'su', '胶' => 'jiao',
    '玻' => 'bo', '璃' => 'li', '瓷' => 'ci', '陶' => 'tao',
    '纸' => 'zhi', '布' => 'bu', '皮' => 'pi', '革' => 'ge',
    '毛' => 'mao', '绒' => 'rong', '丝' => 'si', '线' => 'xian',
    '棉' => 'mian', '麻' => 'ma', '纤' => 'xian', '维' => 'wei',
    '锡' => 'xi', '铬' => 'ge', '锌' => 'xin', '锰' => 'meng',
    '铂' => 'bo', '钛' => 'tai', '镍' => 'nie', '钨' => 'wu',
    '铅' => 'qian', '汞' => 'gong', '硫' => 'liu', '碳' => 'tan',
    '硅' => 'gui', '氮' => 'dan', '氧' => 'yang', '氢' => 'qing',
    '氯' => 'lv', '磷' => 'lin', '碘' => 'dian', '溴' => 'xiu',
    '混' => 'hun', '凝' => 'ning', '浇' => 'jiao', '铸' => 'zhu',
    '锻' => 'duan', '焊' => 'han', '铆' => 'mao', '栓' => 'shuan',
    '钉' => 'ding', '螺' => 'luo', '垫' => 'dian', '罩' => 'zhao',
    '地' => 'di', '墙' => 'qiang', '顶' => 'ding', '棚' => 'peng',
    '门' => 'men', '窗' => 'chuang', '柱' => 'zhu', '梁' => 'liang',
    '楼' => 'lou', '梯' => 'ti', '台' => 'tai', '阶' => 'jie',
    '檐' => 'yan', '廊' => 'lang', '厅' => 'ting', '室' => 'shi',
    '房' => 'fang', '屋' => 'wu', '厨' => 'chu', '厕' => 'ce',
    '浴' => 'yu', '卫' => 'wei', '卧' => 'wo', '客' => 'ke',
    '书' => 'shu', '餐' => 'can', '茶' => 'cha', '酒' => 'jiu',
    '会' => 'hui', '议' => 'yi', '办' => 'ban', '公' => 'gong',
    '走' => 'zou', '道' => 'dao', '路' => 'lu', '径' => 'jing',
    '桥' => 'qiao', '栏' => 'lan', '杆' => 'gan', '扶' => 'fu',
    '手' => 'shou', '脚' => 'jiao', '踏' => 'ta', '步' => 'bu',
    '阁' => 'ge', '院' => 'yuan', '塔' => 'ta', '殿' => 'dian',
    '堡' => 'bao', '坝' => 'ba', '堤' => 'di', '沟' => 'gou',
    '渠' => 'qu', '槽' => 'cao', '井' => 'jing', '仓' => 'cang',
    '库' => 'ku', '垣' => 'yuan', '壁' => 'bi', '幕' => 'mu',
    '帘' => 'lian', '桌' => 'zhuo', '椅' => 'yi', '凳' => 'deng',
    '柜' => 'gui', '床' => 'chuang', '榻' => 'ta', '架' => 'jia',
    '箱' => 'xiang', '盒' => 'he', '筐' => 'kuang', '篮' => 'lan',
    '灯' => 'deng', '镜' => 'jing', '屏' => 'ping', '扇' => 'shan',
    '伞' => 'san', '壶' => 'hu', '杯' => 'bei', '盘' => 'pan',
    '碗' => 'wan', '瓶' => 'ping', '罐' => 'guan', '盆' => 'pen',
    '花' => 'hua', '草' => 'cao', '树' => 'shu', '叶' => 'ye',
    '枝' => 'zhi', '根' => 'gen', '果' => 'guo', '橱' => 'chu',
    '几' => 'ji', '案' => 'an', '墩' => 'dun', '裳' => 'shang',
    '枕' => 'zhen', '被' => 'bei', '毯' => 'tan', '褥' => 'ru',
    '席' => 'xi', '烛' => 'zhu', '炉' => 'lu', '钟' => 'zhong',
    '表' => 'biao', '琴' => 'qin', '棋' => 'qi', '筝' => 'zheng',
    '红' => 'hong', '橙' => 'cheng', '黄' => 'huang', '绿' => 'lv',
    '青' => 'qing', '蓝' => 'lan', '紫' => 'zi', '白' => 'bai',
    '黑' => 'hei', '灰' => 'hui', '褐' => 'he', '棕' => 'zong',
    '淡' => 'dan', '深' => 'shen', '浅' => 'qian', '亮' => 'liang',
    '暗' => 'an', '明' => 'ming', '昏' => 'hun', '浊' => 'zhuo',
    '清' => 'qing', '米' => 'mi', '豆' => 'dou', '杏' => 'xing',
    '桃' => 'tao', '玫' => 'mei', '瑰' => 'gui', '玛' => 'ma',
    '瑙' => 'nao', '翡' => 'fei', '翠' => 'cui', '琥' => 'hu',
    '珀' => 'po', '宝' => 'bao', '绯' => 'fei', '绛' => 'jiang',
    '赭' => 'zhe', '黛' => 'dai', '靛' => 'dian', '碧' => 'bi',
    '蔚' => 'wei', '藕' => 'ou', '栗' => 'li', '柚' => 'you',
    '上' => 'shang', '下' => 'xia', '左' => 'zuo', '右' => 'you',
    '前' => 'qian', '后' => 'hou', '内' => 'nei', '外' => 'wai',
    '中' => 'zhong', '旁' => 'pang', '侧' => 'ce', '边' => 'bian',
    '东' => 'dong', '西' => 'xi', '南' => 'nan', '北' => 'bei',
    '角' => 'jiao', '端' => 'duan', '缘' => 'yuan', '心' => 'xin',
    '底' => 'di', '头' => 'tou', '尾' => 'wei', '峰' => 'feng',
    '谷' => 'gu', '坡' => 'po', '岸' => 'an', '滩' => 'tan',
    '岛' => 'dao', '大' => 'da', '小' => 'xiao', '长' => 'chang',
    '短' => 'duan', '宽' => 'kuan', '窄' => 'zhai', '高' => 'gao',
    '低' => 'di', '厚' => 'hou', '薄' => 'bao', '圆' => 'yuan',
    '方' => 'fang', '扁' => 'bian', '尖' => 'jian', '钝' => 'dun',
    '曲' => 'qu', '直' => 'zhi', '弯' => 'wan', '平' => 'ping',
    '斜' => 'xie', '凸' => 'tu', '凹' => 'ao', '粗' => 'cu',
    '细' => 'xi', '硬' => 'ying', '软' => 'ruan', '滑' => 'hua',
    '糙' => 'cao', '光' => 'guang', '密' => 'mi', '疏' => 'shu',
    '匀' => 'yun', '锐' => 'rui', '棱' => 'leng', '缝' => 'feng',
    '一' => 'yi', '二' => 'er', '三' => 'san', '四' => 'si',
    '五' => 'wu', '六' => 'liu', '七' => 'qi', '八' => 'ba',
    '九' => 'jiu', '十' => 'shi', '百' => 'bai', '千' => 'qian',
    '万' => 'wan', '亿' => 'yi', '零' => 'ling', '个' => 'ge',
    '只' => 'zhi', '张' => 'zhang', '条' => 'tiao', '件' => 'jian',
    '套' => 'tao', '组' => 'zu', '对' => 'dui', '双' => 'shuang',
    '排' => 'pai', '列' => 'lie', '批' => 'pi', '份' => 'fen',
    '段' => 'duan', '节' => 'jie', '册' => 'ce', '本' => 'ben',
    '页' => 'ye', '寸' => 'cun', '尺' => 'chi', '丈' => 'zhang',
    '斤' => 'jin', '两' => 'liang', '克' => 'ke', '吨' => 'dun',
    '新' => 'xin', '旧' => 'jiu', '老' => 'lao', '好' => 'hao',
    '坏' => 'huai', '美' => 'mei', '丑' => 'chou', '优' => 'you',
    '真' => 'zhen', '假' => 'jia', '正' => 'zheng', '反' => 'fan',
    '主' => 'zhu', '总' => 'zong', '单' => 'dan', '多' => 'duo',
    '少' => 'shao', '全' => 'quan', '半' => 'ban', '满' => 'man',
    '空' => 'kong', '实' => 'shi', '纯' => 'chun', '简' => 'jian',
    '繁' => 'fan', '快' => 'kuai', '慢' => 'man', '轻' => 'qing',
    '重' => 'zhong', '强' => 'qiang', '弱' => 'ruo', '热' => 're',
    '冷' => 'leng', '温' => 'wen', '凉' => 'liang', '干' => 'gan',
    '湿' => 'shi', '净' => 'jing', '洁' => 'jie', '脏' => 'zang',
    '香' => 'xiang', '臭' => 'chou', '甜' => 'tian', '苦' => 'ku',
    '辣' => 'la', '酸' => 'suan', '咸' => 'xian', '松' => 'song',
    '紧' => 'jin', '贵' => 'gui', '贱' => 'jian', '富' => 'fu',
    '穷' => 'qiong', '难' => 'nan', '易' => 'yi', '忙' => 'mang',
    '闲' => 'xian', '早' => 'zao', '晚' => 'wan', '初' => 'chu',
    '末' => 'mo', '首' => 'shou', '次' => 'ci', '第' => 'di',
    '最' => 'zui', '打' => 'da', '拉' => 'la', '推' => 'tui',
    '放' => 'fang', '拿' => 'na', '抓' => 'zhua', '提' => 'ti',
    '抱' => 'bao', '举' => 'ju', '扔' => 'reng', '接' => 'jie',
    '抬' => 'tai', '按' => 'an', '压' => 'ya', '切' => 'qie',
    '剪' => 'jian', '折' => 'zhe', '断' => 'duan', '撕' => 'si',
    '擦' => 'ca', '洗' => 'xi', '刷' => 'shua', '磨' => 'mo',
    '削' => 'xiao', '割' => 'ge', '砍' => 'kan', '劈' => 'pi',
    '敲' => 'qiao', '装' => 'zhuang', '拆' => 'chai', '修' => 'xiu',
    '补' => 'bu', '换' => 'huan', '改' => 'gai', '整' => 'zheng',
    '配' => 'pei', '选' => 'xuan', '找' => 'zhao', '看' => 'kan',
    '写' => 'xie', '读' => 'du', '说' => 'shuo', '听' => 'ting',
    '想' => 'xiang', '问' => 'wen', '答' => 'da', '笑' => 'xiao',
    '哭' => 'ku', '坐' => 'zuo', '站' => 'zhan', '躺' => 'tang',
    '蹲' => 'dun', '吃' => 'chi', '喝' => 'he', '睡' => 'shui',
    '醒' => 'xing', '开' => 'kai', '关' => 'guan', '进' => 'jin',
    '出' => 'chu', '来' => 'lai', '去' => 'qu', '回' => 'hui',
    '过' => 'guo', '起' => 'qi', '落' => 'luo', '升' => 'sheng',
    '降' => 'jiang', '加' => 'jia', '减' => 'jian', '增' => 'zeng',
    '删' => 'shan', '立' => 'li', '穿' => 'chuan', '脱' => 'tuo',
    '人' => 'ren', '物' => 'wu', '品' => 'pin', '名' => 'ming',
    '字' => 'zi', '号' => 'hao', '标' => 'biao', '记' => 'ji',
    '签' => 'qian', '牌' => 'pai', '文' => 'wen', '设' => 'she',
    '显' => 'xian', '示' => 'shi', '制' => 'zhi', '造' => 'zao',
    '建' => 'jian', '水' => 'shui', '火' => 'huo', '风' => 'feng',
    '气' => 'qi', '天' => 'tian', '云' => 'yun', '雨' => 'yu',
    '雪' => 'xue', '山' => 'shan', '海' => 'hai', '日' => 'ri',
    '月' => 'yue', '春' => 'chun', '夏' => 'xia', '秋' => 'qiu',
    '冬' => 'dong', '抽' => 'chou', '铰' => 'jiao', '事' => 'shi',
    '情' => 'qing', '状' => 'zhuang', '态' => 'tai', '形' => 'xing',
    '样' => 'yang', '式' => 'shi', '类' => 'lei', '种' => 'zhong',
    '型' => 'xing', '符' => 'fu', '卡' => 'ka', '证' => 'zheng',
    '票' => 'piao', '剑' => 'jian', '弓' => 'gong', '盾' => 'dun',
    '甲' => 'jia', '旗' => 'qi', '鼓' => 'gu', '笛' => 'di',
    '箫' => 'xiao', '眼' => 'yan', '耳' => 'er', '鼻' => 'bi',
    '口' => 'kou', '脸' => 'lian', '发' => 'fa', '齿' => 'chi',
    '舌' => 'she', '骨' => 'gu', '血' => 'xue', '肉' => 'rou',
    '脉' => 'mai', '胸' => 'xiong', '背' => 'bei', '腰' => 'yao',
    '腹' => 'fu', '肩' => 'jian', '臂' => 'bi', '掌' => 'zhang',
    '指' => 'zhi', '膝' => 'xi', '足' => 'zu', '趾' => 'zhi',
    '颈' => 'jing', '原' => 'yuan', '野' => 'ye', '林' => 'lin',
    '森' => 'sen', '丛' => 'cong', '灌' => 'guan', '荒' => 'huang',
    '漠' => 'mo', '洋' => 'yang', '江' => 'jiang', '河' => 'he',
    '溪' => 'xi', '流' => 'liu', '泉' => 'quan', '潭' => 'tan',
    '池' => 'chi', '塘' => 'tang', '湖' => 'hu', '泽' => 'ze',
    '沼' => 'zhao', '湾' => 'wan', '港' => 'gang', '礁' => 'jiao',
    '雾' => 'wu', '霜' => 'shuang', '露' => 'lu', '雷' => 'lei',
    '电' => 'dian', '闪' => 'shan', '星' => 'xing', '晨' => 'chen',
    '夜' => 'ye', '午' => 'wu', '夕' => 'xi', '季' => 'ji',
    '年' => 'nian', '代' => 'dai', '岭' => 'ling', '崖' => 'ya',
    '峡' => 'xia', '洞' => 'dong', '狗' => 'gou', '猫' => 'mao',
    '鸟' => 'niao', '鱼' => 'yu', '龙' => 'long', '凤' => 'feng',
    '虎' => 'hu', '鹤' => 'he', '莲' => 'lian', '菊' => 'ju',
    '兰' => 'lan', '梅' => 'mei', '竹' => 'zhu', '柏' => 'bai',
    '杉' => 'shan', '桂' => 'gui', '荷' => 'he', '藤' => 'teng',
    '苗' => 'miao', '芽' => 'ya', '茎' => 'jing', '穗' => 'sui',
    '苞' => 'bao', '牛' => 'niu', '羊' => 'yang', '马' => 'ma',
    '猪' => 'zhu', '鸡' => 'ji', '鸭' => 'ya', '鹅' => 'e',
    '兔' => 'tu', '蛇' => 'she', '鹿' => 'lu', '熊' => 'xiong',
    '象' => 'xiang', '蜂' => 'feng', '蝶' => 'die', '虫' => 'chong',
    '蚁' => 'yi', '刀' => 'dao', '枪' => 'qiang', '斧' => 'fu',
    '锤' => 'chui', '铲' => 'chan', '钩' => 'gou', '针' => 'zhen',
    '锯' => 'ju', '刨' => 'bao', '规' => 'gui', '绳' => 'sheng',
    '索' => 'suo', '链' => 'lian', '环' => 'huan', '锁' => 'suo',
    '钥' => 'yao', '轮' => 'lun', '轴' => 'zhou', '杠' => 'gang',
    '管' => 'guan', '阀' => 'fa', '泵' => 'beng', '饭' => 'fan',
    '菜' => 'cai', '汤' => 'tang', '糖' => 'tang', '盐' => 'yan',
    '醋' => 'cu', '酱' => 'jiang', '油' => 'you', '麦' => 'mai',
    '蛋' => 'dan', '奶' => 'nai', '饼' => 'bing', '糕' => 'gao',
    '饺' => 'jiao', '粽' => 'zong', '衣' => 'yi', '裤' => 'ku',
    '裙' => 'qun', '帽' => 'mao', '鞋' => 'xie', '袜' => 'wa',
    '领' => 'ling', '袖' => 'xiu', '扣' => 'kou', '带' => 'dai',
    '绸' => 'chou', '缎' => 'duan', '锦' => 'jin', '绣' => 'xiu',
    '编' => 'bian', '织' => 'zhi', '父' => 'fu', '母' => 'mu',
    '兄' => 'xiong', '弟' => 'di', '姐' => 'jie', '妹' => 'mei',
    '儿' => 'er', '女' => 'nv', '夫' => 'fu', '妻' => 'qi',
    '爷' => 'ye', '叔' => 'shu', '姨' => 'yi', '姑' => 'gu',
    '舅' => 'jiu', '孙' => 'sun', '祖' => 'zu', '王' => 'wang',
    '皇' => 'huang', '帝' => 'di', '将' => 'jiang', '军' => 'jun',
    '帅' => 'shuai', '很' => 'hen', '都' => 'dou', '也' => 'ye',
    '还' => 'hai', '已' => 'yi', '在' => 'zai', '从' => 'cong',
    '到' => 'dao', '往' => 'wang', '向' => 'xiang', '把' => 'ba',
    '让' => 'rang', '给' => 'gei', '和' => 'he', '与' => 'yu',
    '或' => 'huo', '但' => 'dan', '因' => 'yin', '为' => 'wei',
    '所' => 'suo', '以' => 'yi', '能' => 'neng', '可' => 'ke',
    '要' => 'yao', '应' => 'ying', '该' => 'gai', '需' => 'xu',
    '须' => 'xu', '车' => 'che', '船' => 'chuan', '机' => 'ji',
    '器' => 'qi', '灶' => 'zao', '锅' => 'guo', '秤' => 'cheng',
    '笔' => 'bi', '墨' => 'mo', '砚' => 'yan', '印' => 'yin',
    '章' => 'zhang', '帖' => 'tie', '卷' => 'juan', '篇' => 'pian',
    '话' => 'hua', '语' => 'yu', '言' => 'yan', '词' => 'ci',
    '歌' => 'ge', '舞' => 'wu', '戏' => 'xi', '影' => 'ying',
    '像' => 'xiang', '相' => 'xiang', '照' => 'zhao', '格' => 'ge',
    '框' => 'kuang', ' ' => '_', '（' => '_', '）' => '',
    '【' => '_', '】' => '', '《' => '', '》' => '',
    '：' => '_', '；' => '_', '，' => '_', '。' => '',
    '！' => '', '？' => '', '·' => '_', '～' => '_',
    '×' => 'x', '＝' => '_', '＋' => '_', '－' => '-',
    '％' => '_',
  }.freeze

  def self.convert(text)
    return '' if text.nil? || text.empty?

    # Split into segments: consecutive ASCII chars stay together, non-ASCII chars convert individually
    segments = []
    buffer = ''

    text.chars.each do |char|
      if char.ascii_only?
        buffer += char
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

    # Join segments with underscore
    result = segments.join('_')
    # Lowercase
    result = result.downcase
    # Keep only letters, digits, underscore, hyphen
    result = result.gsub(/[^\w\-]/, '')
    # Collapse underscores
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
      %w[柜 板 金 抽 拉 铰 桌].any? { |char| text.include?(char) }
    end

    # 名称已经是合法的：纯ASCII、只含\w和-、不超过30字符、无需任何改动
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

        # 已是合法名称（纯ASCII、只含字母数字下划线连字符、不超长）则跳过
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

    # SketchUp 要求材质名称全局唯一，需要同时检查本地集合和模型
    def find_unique_material_name(base_name, original_name)
      candidate = generate_unique_name(base_name, @existing_names)
      # 如果名字没变，直接返回
      return candidate if candidate == original_name
      # 确保 SketchUp 模型中也不存在同名
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
      # 已是合法名称，跳过
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
      # 已是合法名称，跳过
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
          # 实例名也合法，跳过
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
  parent_menu = nil
  menu_locations.each do |name|
    begin
      parent_menu = UI.menu(name)
      break if parent_menu
    rescue
      next
    end
  end
  parent_menu ||= UI.menu('Plugins')

  tex_menu = parent_menu.add_submenu('贴图复制工具')
  tex_menu.add_item('复制贴图并重命名UTF-8') { TextureCopier.copy_all_textures }

  parent_menu.add_separator

  name_menu = parent_menu.add_submenu('名称清理工具')
  name_menu.add_item('清理材质名称') { NameCleanerPlugin::MaterialCleaner.new.execute }
  name_menu.add_separator
  name_menu.add_item('清理组和组件（跳过家具）') { NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: true).execute }
  name_menu.add_item('清理组和组件（全部清理）') { NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: false).execute }
  name_menu.add_separator
  name_menu.add_item('全部清理（跳过家具）') do
    NameCleanerPlugin::MaterialCleaner.new.execute
    NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: true).execute
  end
  name_menu.add_item('全部清理（不跳过）') do
    NameCleanerPlugin::MaterialCleaner.new.execute
    NameCleanerPlugin::GroupComponentCleaner.new(skip_chinese: false).execute
  end

  file_loaded(__FILE__)
end
