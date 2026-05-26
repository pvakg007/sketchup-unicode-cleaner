# SketchUp Unicode Cleaner

SketchUp 材质/组件名称清理 + 贴图复制工具集。将模型中的中文/Unicode 名称转为拼音 ASCII，同时处理贴图文件的复制与重命名。

## 功能概览

| 工具 | 类型 | 用途 |
|------|------|------|
| `Clear_Unicode_characters.rb` | SketchUp 插件 (.rb) | 在 SketchUp 内一键清理名称 + 复制贴图 |
| `skp_texture_copier_gui.py` | 独立 GUI 工具 (.py) | 脱离 SketchUp，直接处理 .skp 文件 |

---

## 1. SketchUp 插件 (`Clear_Unicode_characters.rb`)

### 安装

将 `Clear_Unicode_characters.rb` 复制到 SketchUp 插件目录：

```
%APPDATA%\SketchUp\SketchUp 2025\SketchUp\Plugins\
```

重启 SketchUp 后，菜单栏会出现 **Extensions → 名称清理工具**（或 **扩展 → 名称清理工具**，取决于语言版本）。

### 菜单功能

| 菜单项 | 功能 |
|--------|------|
| **清理材质名称** | 将所有材质名中的 CJK 字符转为拼音 ASCII |
| **清理组和组件（跳过家具）** | 清理组/组件名，但跳过含"柜板金抽屉铰桌"等家具关键字的对象 |
| **清理组和组件（全部清理）** | 清理所有组/组件名，不跳过任何对象 |
| **全部清理（跳过家具）** | 材质 + 组/组件一键清理，跳过家具 |
| **全部清理（不跳过）** | 材质 + 组/组件一键清理，全部处理 |
| **复制贴图并重命名 UTF-8** | 复制模型所有材质贴图到模型目录的 `textures/` 子文件夹，非 ASCII 文件名自动转拼音 |

### 命名转换规则

- **CJK 中文** → 拼音（如 `金属` → `jinshu`，`材质` → `caizhi`）
- **西里尔同形字母** → 拉丁字母（如 `с` → `c`，`а` → `a`）— 视觉相同但 Unicode 码点不同的字符会被映射为拉丁等价字符
- **未知非 ASCII 字符** → Unicode 码点十六进制（如 `∑` → `2211`）
- 多个拼音片段用 `_` 连接（如 `金属板` → `jinshu_ban`）
- 最大名称长度: 30 字符

### 贴图复制说明

点击"复制贴图并重命名UTF-8"后：
- 自动遍历模型中所有材质的贴图
- 将贴图复制到 **.skp 文件所在目录**的 `textures/` 子文件夹
- 如果贴图文件名含非 ASCII 字符，自动转为拼音格式
- 弹出结果对话框显示复制/重命名详情

---

## 2. Python GUI 工具 (`skp_texture_copier_gui.py`)

独立的 Windows GUI 工具，**不需要打开 SketchUp**，直接读取 .skp 文件（ZIP 格式）内部结构处理贴图。

### 启动方式

```bash
python skp_texture_copier_gui.py
```

或使用打包好的 EXE（`dist/TheaTextureCopier1.0.exe`，由 PyInstaller 生成）。

### 使用步骤

1. **选择 SKP 文件** — 点击"浏览"选择 .skp 文件
2. **解析 SKP** — 自动读取文件内所有 material.xml，列出材质及其贴图引用
3. **勾选贴图** — 在列表中勾选需要处理的贴图（或全选）
4. **复制贴图并更新 SKP** — 将贴图导出到 `textures/` 目录，重命名非 ASCII 文件名，并更新 .skp 内部的路径引用

### 贴图列表列说明

| 列 | 说明 |
|----|------|
| 材质 | 材质名称（来自 material.xml） |
| 贴图文件 | 贴图文件名 |
| 原路径 | material.xml 中记录的原始路径 |
| 来源 | 贴图来源：磁盘路径 / ZIP内嵌 / 搜索找到 / 未找到 |
| 状态 | 处理结果：成功 / 跳过 / 失败 |

### 依赖

- Python 3.10+
- 标准库: `tkinter`, `zipfile`, `xml.etree`, `zlib`
- 无需安装第三方包

### 打包为 EXE

```bash
pyinstaller --onefile --windowed --name SKPTextureCopier skp_texture_copier_gui.py
```

---

## 项目结构

```
├── Clear_Unicode_characters.rb    # SketchUp Ruby 插件（主文件）
├── skp_texture_copier_gui.py      # Python GUI 工具（主文件）
├── skp_texture_copier.py          # Python 命令行版本
├── copy_textures.rb               # Ruby 贴图复制模块
├── pinyin_merged.py               # 拼音数据（Python）
├── pinyin_dict.txt                # 拼音数据（文本）
├── gen_pinyin.py                  # 拼音表生成脚本
├── lib/
│   ├── pinyin_table.rb            # Ruby 拼音表
│   └── texture_copier.rb          # Ruby 贴图复制器
├── run.bat                        # 快速启动脚本
└── dist/
    └── TheaTextureCopier1.0.exe   # 打包好的 EXE
```

## 注意事项

- 处理 .skp 文件前建议先备份原文件
- Python GUI 工具直接修改 .skp 内部结构（ZIP），处理后 SketchUp 2025/2026 可正常打开
- SketchUp 插件在操作中支持撤销（Ctrl+Z）
