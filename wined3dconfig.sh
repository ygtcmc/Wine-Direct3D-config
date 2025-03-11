#!/bin/bash
# Wine Direct3D 配置工具（带参数说明）

# 检查Wine是否安装
if ! command -v wine &> /dev/null; then
  echo "错误：未找到wine命令，请先安装Wine。"
  exit 1
fi

# 获取当前配置函数
get_current_config() {
  current_renderer=$(wine reg query "HKCU\Software\Wine\Direct3D" /v renderer 2>/dev/null | awk -F' ' '/REG_SZ/ {print $NF}')
  ddraw_renderer=$(wine reg query "HKCU\Software\Wine\Direct3D" /v DirectDrawRenderer 2>/dev/null | awk -F' ' '/REG_SZ/ {print $NF}')

  csmt_status=$(wine reg query "HKCU\Software\Wine\Direct3D" /v CSMT 2>/dev/null | awk '/REG_DWORD/ {print $NF}' | sed 's/0x//')
  csmt_status=$((csmt_status))

  glsl_status=$(wine reg query "HKCU\Software\Wine\Direct3D" /v UseGLSL 2>/dev/null | awk '/REG_DWORD/ {print $NF}' | sed 's/0x//')
  glsl_status=$((glsl_status))

  strict_shaders=$(wine reg query "HKCU\Software\Wine\Direct3D" /v StrictShaders 2>/dev/null | awk '/REG_DWORD/ {print $NF}' | sed 's/0x//')
  strict_shaders=$((strict_shaders))
}

# 显示当前配置（带参数说明）
show_status() {
  get_current_config
  echo ""
  echo "================ 当前图形配置 ================"
  printf " %-25s : %s\n" \
    "主渲染器 (3D API)" "${current_renderer:-auto}" \
    "CSMT多线程 (多核优化)" "$([ "${csmt_status:-0}" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "GLSL着色器 (硬件着色)" "$([ "${glsl_status:-1}" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "严格着色器 (兼容模式)" "$([ "${strict_shaders:-0}" -eq 1 ] && echo "enabled" || echo "disabled")" \
    "DDraw渲染器 (2D加速)" "${ddraw_renderer:-gdi}"
  echo "----------------------------------------------"
  echo "参数说明："
  echo "1) 主渲染器: 选择3D图形接口（auto=自动选择最佳）"
  echo "2) CSMT    : 提升多核CPU渲染性能，可能影响兼容性"
  echo "3) GLSL    : 启用硬件着色器加速，建议保持开启"
  echo "4) 严格模式: 严格遵循着色器规范，解决部分图形错误"
  echo "5) DDraw   : 影响2D游戏和视频播放性能"
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
  echo " 2. 切换 GLSL 着色器 [当前: $([ "${glsl_status:-1}" -eq 1 ] && echo "enabled" || echo "disabled")]"
  echo " 3. 切换严格着色器   [当前: $([ "${strict_shaders:-0}" -eq 1 ] && echo "enabled" || echo "disabled")]"
  echo " 4. 设置 DDraw 渲染器"
  echo " 0. 返回主菜单"
  read -rp "请输入选择 [0-4]: " adv_choice

  case $adv_choice in
    1) toggle_param "CSMT" ;;
    2) toggle_param "UseGLSL" ;;
    3) toggle_param "StrictShaders" ;;
    4) set_ddraw ;;
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

# 设置 DDraw 渲染器
set_ddraw() {
  echo ""
  echo "------ 设置 DirectDraw 渲染器 ------"
  echo " 1. gdi     - 软件渲染"
  echo " 2. opengl  - OpenGL加速"
  echo " 3. d3d9    - 原生D3D9"
  echo " 4. auto    - 自动选择"
  echo " 0. 返回上级菜单"
  read -rp "请输入选择 [0-4]: " ddraw_choice
  
  case $ddraw_choice in
    1) val="gdi" ;;
    2) val="opengl" ;;
    3) val="d3d9" ;;
    4) val="auto" ;;
    0) advanced_menu; return ;;
    *) echo "无效选择"; return ;;
  esac
  
  wine reg add "HKCU\Software\Wine\Direct3D" /v DirectDrawRenderer /d "$val" /f >/dev/null 2>&1
  echo "DDraw 渲染器已设置为: $val"
  sleep 1
  advanced_menu
}

# 重置默认配置
reset_default() {
  wine reg delete "HKCU\Software\Wine\Direct3D" /v renderer /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v CSMT /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v UseGLSL /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v StrictShaders /f >/dev/null 2>&1
  wine reg delete "HKCU\Software\Wine\Direct3D" /v DirectDrawRenderer /f >/dev/null 2>&1
  echo "已重置为默认配置"
  sleep 1
  main_menu
}

# 初始化：确保注册表键存在
wine reg add "HKCU\Software\Wine\Direct3D" /f >/dev/null 2>&1

# 启动主菜单
main_menu
