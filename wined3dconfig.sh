#!/bin/bash
# Wine Direct3D 配置工具（包含详细的注册表参数配置）

# 检查Wine是否安装
if ! command -v wine &> /dev/null; then
  echo "错误：未找到wine命令，请先安装Wine。"
  exit 1
fi

# 获取当前配置函数
get_current_config() {
  current_renderer=$(wine reg query "HKCU\Software\Wine\Direct3D" /v renderer 2>/dev/null | awk -F' ' '/REG_SZ/ {print $NF}')
  
  # 获取 CSMT 状态，确保其为有效的整数
  csmt_status=$(wine reg query "HKCU\Software\Wine\Direct3D" /v csmt 2>/dev/null | awk -F' ' '/REG_DWORD/ {print $NF}' || echo "0")
  csmt_status=$(echo "$csmt_status" | sed 's/0x//')  # 去掉0x前缀

  # 确保 csmt_status 仅为数字并进行算术处理
  if [[ ! "$csmt_status" =~ ^[0-9]+$ ]]; then
    csmt_status=0
  fi
  csmt_status=$((csmt_status))  # 确保它是整数

  multisample_textures=$(wine reg query "HKCU\Software\Wine\Direct3D" /v MultisampleTextures 2>/dev/null | awk -F' ' '/REG_DWORD/ {print $NF}' || echo "1")
  sample_count=$(wine reg query "HKCU\Software\Wine\Direct3D" /v SampleCount 2>/dev/null | awk -F' ' '/REG_DWORD/ {print $NF}' || echo "1")
  shader_backend=$(wine reg query "HKCU\Software\Wine\Direct3D" /v shader_backend 2>/dev/null | awk -F' ' '/REG_SZ/ {print $NF}' || echo "glsl")
  strict_shader_math=$(wine reg query "HKCU\Software\Wine\Direct3D" /v strict_shader_math 2>/dev/null | awk -F' ' '/REG_DWORD/ {print $NF}' || echo "0")
  glsl_status=$(wine reg query "HKCU\Software\Wine\Direct3D" /v UseGLSL 2>/dev/null | awk -F' ' '/REG_SZ/ {print $NF}' || echo "glsl")
}

# 显示当前配置（带参数说明）
show_status() {
  get_current_config
  echo ""
  echo "================ 当前图形配置 ================"
  printf " %-25s : %s\n" \
    "主渲染器" "${current_renderer:-auto}" \
    "CSMT 多线程" "$([ "$csmt_status" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "多重采样纹理" "$([ "${multisample_textures:-1}" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "交换链采样计数" "${sample_count:-1}" \
    "着色器后端" "${shader_backend:-glsl}" \
    "严格着色器数学" "$([ "${strict_shader_math:-0}" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "GLSL 着色器" "${glsl_status:-glsl}"
  echo "----------------------------------------------"
  echo "参数说明："
  echo "1) 主渲染器: 选择3D图形接口"
  echo "2) CSMT    : 提升多核CPU渲染性能，可能影响兼容性"
  echo "3) 多重采样纹理: 启用或禁用纹理的多重采样"
  echo "4) 交换链采样计数: 设置强制启用的多重采样计数"
  echo "5) 着色器后端: 设置使用的着色器语言（glsl、arb或none）"
  echo "6) 严格着色器数学: 关闭激进优化来解决渲染错误"
  echo "=============================================="
}

# 主菜单
main_menu() {
  show_status
  echo ""
  echo "-------- Wine Direct3D 配置工具 --------"
  echo " 1. 选择主渲染器"
  echo " 2. 配置高级参数"
  echo " 3. 重置为默认值"
  echo " 0. 退出"
  read -rp "请输入选择 [0-3]: " main_choice

  case $main_choice in
    1) renderer_menu ;;
    2) advanced_menu ;;
    3) reset_default ;;
    0) exit 0 ;;
    *) echo "无效输入"; sleep 1; main_menu ;;
  esac
}

# 渲染器选择菜单
renderer_menu() {
  show_status
  echo ""
  echo "------ 选择主渲染器 ------"
  echo " 1. gdi    - 软件渲染"
  echo " 2. no3d   - 禁用3D加速"
  echo " 3. opengl - OpenGL加速"
  echo " 4. vulkan - Vulkan加速"
  echo " 5. d3d9   - 原生D3D9"
  echo " 6. auto   - 自动选择"
  echo " 0. 返回主菜单"
  read -rp "请输入选择 [0-6]: " renderer_choice

  case $renderer_choice in
    1) apply_renderer "gdi" ;;
    2) apply_renderer "no3d" ;;
    3) apply_renderer "opengl" ;;
    4) apply_renderer "vulkan" ;;
    5) apply_renderer "d3d9" ;;
    6) apply_renderer "auto" ;;
    0) main_menu ;;
    *) echo "无效输入"; sleep 1; renderer_menu ;;
  esac
}

# 应用渲染器设置
apply_renderer() {
  wine reg add "HKCU\Software\Wine\Direct3D" /v renderer /d "$1" /f >/dev/null 2>&1
  echo "主渲染器已设置为: $1"
  sleep 1
  renderer_menu
}

# 高级参数菜单
advanced_menu() {
  show_status
  echo ""
  echo "------ 高级参数配置 ------"
  echo " 1. 切换 CSMT 多线程 [当前: $([ "${csmt_status:-0}" -eq 1 ] && echo "enabled" || echo "disabled")]"
  echo " 2. 切换多重采样纹理 [当前: $([ "${multisample_textures:-1}" -eq 1 ] && echo "enabled" || echo "disabled")]"
  echo " 3. 设置交换链采样计数 [当前: $sample_count]"
  echo " 4. 切换着色器后端 [当前: $shader_backend]"
  echo " 5. 切换严格着色器数学 [当前: $([ "${strict_shader_math:-0}" -eq 1 ] && echo "enabled" || echo "disabled")]"
  echo " 6. 切换 GLSL 着色器 [当前: $([ "${glsl_status:-glsl}" == "glsl" ] && echo "enabled" || echo "disabled")]"
  echo " 0. 返回主菜单"
  read -rp "请输入选择 [0-6]: " adv_choice

  case $adv_choice in
    1) toggle_param "csmt" ;;
    2) toggle_param "MultisampleTextures" ;;
    3) set_sample_count ;;
    4) set_shader_backend ;;
    5) toggle_param "strict_shader_math" ;;
    6) toggle_param "UseGLSL" ;;
    0) main_menu ;;
    *) echo "无效输入"; sleep 1; advanced_menu ;;
  esac
}

# 切换DWORD类型参数
toggle_param() {
  param=$1
  current=$(wine reg query "HKCU\Software\Wine\Direct3D" /v $param 2>/dev/null | awk '/REG_DWORD/ {print $NF}' | sed 's/0x//')
  current=$((current))  # 转换为十进制数值，默认为0
  new_val=$((1 - current))
  wine reg add "HKCU\Software\Wine\Direct3D" /v $param /t REG_DWORD /d $new_val /f >/dev/null 2>&1
  status=$( (( new_val )) && echo "enabled" || echo "disabled" )
  echo "$param 已切换为: $status"
  sleep 1
  advanced_menu
}

# 设置交换链采样计数
set_sample_count() {
  read -rp "请输入新的采样计数 (如: 1, 2, 4): " count
  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    echo "无效输入，请输入一个正整数"
    sleep 1
    set_sample_count
    return
  fi
  wine reg add "HKCU\Software\Wine\Direct3D" /v SampleCount /t REG_DWORD /d "$count" /f >/dev/null 2>&1
  echo "交换链采样计数已设置为: $count"
  sleep 1
  advanced_menu
}

# 设置着色器后端
set_shader_backend() {
  echo "选择着色器后端:"
  echo " 1. glsl"
  echo " 2. arb"
  echo " 3. none"
  read -rp "请输入选择 [1-3]: " backend_choice

  case $backend_choice in
    1) val="glsl" ;;
    2) val="arb" ;;
    3) val="none" ;;
    *) echo "无效选择"; return ;;
  esac

  wine reg add "HKCU\Software\Wine\Direct3D" /v shader_backend /d "$val" /f >/dev/null 2>&1
  echo "着色器后端已设置为: $val"
  sleep 1
  advanced_menu
}

# 重置默认配置
reset_default() {
  wine reg delete "HKCU\Software\Wine\Direct3D" /v renderer /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v csmt /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v MultisampleTextures /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v SampleCount /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v shader_backend /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v strict_shader_math /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v UseGLSL /f >/dev/null 2>&1
  echo "已重置为默认配置"
  sleep 1
  main_menu
}

# 初始化：确保注册表键存在
wine reg add "HKCU\Software\Wine\Direct3D" /f >/dev/null 2>&1

# 启动主菜单
main_menu
