# frozen_string_literal: true

require_relative 'pinyin_table'

module TextureCopier
  extend self

  # 复制所有材质贴图到模型目录的textures子目录
  def copy_all_textures
    model = Sketchup.active_model

    # 检查模型是否已保存
    unless model.path && !model.path.empty?
      UI.messagebox('请先保存模型文件！')
      return nil
    end

    # 创建textures子目录
    model_dir = File.dirname(model.path)
    textures_dir = File.join(model_dir, 'textures')

    unless Dir.exist?(textures_dir)
      Dir.mkdir(textures_dir)
    end

    # 收集处理结果
    results = {
      copied: [],
      renamed: [],
      skipped: [],
      errors: []
    }

    # 用于处理同名冲突的计数器
    used_names = {}

    # 遍历所有材质
    materials = model.materials.to_a
    materials.each do |material|
      process_material(material, textures_dir, results, used_names)
    end

    # 显示结果
    show_results(results)

    results
  end

  # 处理单个材质
  def process_material(material, textures_dir, results, used_names)
    texture = material.texture
    return unless texture

    begin
      original_path = texture.filename
      original_name = File.basename(original_path)
      ext = File.extname(original_name)

      # 生成新的基础文件名
      base_name = generate_base_name(original_name, ext, results)

      # 处理同名冲突
      new_name = resolve_conflict(base_name, ext, used_names)
      new_path = File.join(textures_dir, new_name)

      # 获取原始贴图尺寸
      original_width = texture.width
      original_height = texture.height

      # 写入贴图文件
      texture.write(new_path)

      # 更新材质贴图路径（保留尺寸）
      if original_width > 0 && original_height > 0
        material.texture = [new_path, original_width, original_height]
      else
        material.texture = new_path
      end

      # 记录成功
      results[:copied] << {
        material: material.name,
        original: original_name,
        new: new_name
      }

    rescue => e
      results[:errors] << {
        material: material.name,
        original: original_name,
        error: e.message
      }
    end
  end

  # 生成新的基础文件名
  def generate_base_name(original_name, ext, results)
    # 去掉扩展名
    name_without_ext = File.basename(original_name, ext)

    # 检查是否需要转换
    if PinyinConverter.needs_conversion?(name_without_ext)
      # 转换为拼音
      converted = PinyinConverter.convert(name_without_ext)
      results[:renamed] << {
        original: original_name,
        converted: "#{converted}#{ext}"
      }
      converted
    else
      # 原名已是ASCII兼容
      name_without_ext
    end
  end

  # 解决文件名冲突
  def resolve_conflict(base_name, ext, used_names)
    # 首次尝试
    candidate = "#{base_name}#{ext}"

    if used_names[candidate]
      # 已存在同名文件，添加序号
      counter = 1
      loop do
        candidate = "#{base_name}_#{counter}#{ext}"
        break unless used_names[candidate]
        counter += 1
      end
    end

    # 标记已使用
    used_names[candidate] = true
    candidate
  end

  # 显示处理结果
  def show_results(results)
    copied_count = results[:copied].size
    renamed_count = results[:renamed].size
    error_count = results[:errors].size

    # 构建消息
    msg = "贴图复制完成！\n\n"
    msg += "复制贴图: #{copied_count} 个\n"

    if renamed_count > 0
      msg += "重命名: #{renamed_count} 个\n"
      msg += "\n重命名详情:\n"
      results[:renamed].each do |item|
        msg += "  #{item[:original]} → #{item[:converted]}\n"
      end
    end

    if error_count > 0
      msg += "\n错误: #{error_count} 个\n"
      results[:errors].each do |item|
        msg += "  #{item[:material]}: #{item[:error]}\n"
      end
    end

    msg += "\n贴图已保存到模型目录的 textures 子文件夹中。"

    UI.messagebox(msg)
  end
end