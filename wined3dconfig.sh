#!/bin/bash
# Wine Direct3D 配置工具 - 最终修正版
# 更新：完全兼容注册表格式，支持多语言环境

# 安全获取DWORD值函数（支持十六进制/十进制）
get_reg_dword() {
  local key="$1"
  local default="$2"
  # 获取原始注册表输出
  local reg_output=$(wine reg query "HKCU\\Software\\Wine\\Direct3D" /v "$key" 2>/dev/null)
  
  # 使用AWK精确提取数值
  local value=$(echo "$reg_output" | awk '
    BEGIN { found = 0 }
    /REG_DWORD/ {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^0x[0-9a-fA-F]+$/) {  # 匹配十六进制
          print strtonum($i);
          found = 1;
          exit;
        }
        else if ($i ~ /^[0-9]+$/) {     # 匹配十进制
          print $i;
          found = 1;
          exit;
        }
      }
    }
    END { if (!found) exit 1 }' 2>/dev/null)

  # 设置默认值并返回
  [[ -z "$value" ]] && value=$default
  echo $((value))
}

# 获取当前配置（最终安全版）
get_current_config() {
  # 主渲染器配置（加强过滤）
  current_renderer=$(wine reg query "HKCU\\Software\\Wine\\Direct3D" /v renderer 2>/dev/null | 
                    awk -F'\t' '/REG_SZ/ {gsub(/[^a-zA-Z0-9]/, "", $3); print $3}')
  current_renderer=${current_renderer:-"auto"}

  # DDraw渲染器配置（兼容多语言）
  ddraw_renderer=$(wine reg query "HKCU\\Software\\Wine\\Direct3D" /v DirectDrawRenderer 2>/dev/null | 
                  awk -F'\t' '/REG_SZ/ {gsub(/[^a-zA-Z0-9]/, "", $3); print $3}')
  ddraw_renderer=${ddraw_renderer:-"gdi"}

  # 数值型参数（安全处理）
  csmt_status=$(get_reg_dword "CSMT" 0)
  glsl_status=$(get_reg_dword "UseGLSL" 1)
  strict_shaders=$(get_reg_dword "StrictShaders" 0)
}

# 显示配置状态（带技术说明）
show_status() {
  get_current_config
  clear
  echo ""
  echo "=============== Wine图形配置状态 ==============="
  printf " %-25s : %-8s %s\n" \
    "主渲染器 (3D API)" "${current_renderer}" "[auto=自动选择 | opengl | vulkan | d3d9]" \
    "CSMT多线程" "$([ "$csmt_status" -eq 1 ] && echo "启用" || echo "禁用")" "[提升多核性能，可能导致部分游戏崩溃]" \
    "GLSL着色器" "$([ "$glsl_status" -eq 1 ] && echo "启用" || echo "禁用")" "[硬件加速着色器，旧显卡建议禁用]" \
    "严格着色模式" "$([ "$strict_shaders" -eq 1 ] && echo "启用" || echo "禁用")" "[修复图形错误，可能降低性能]" \
    "DDraw渲染器" "${ddraw_renderer}" "[gdi=兼容模式 | opengl=加速 | d3d9=原生]"
  echo "================================================"
}

# 主控制菜单
main_menu() {
  while true; do
    show_status
    echo ""
    echo "------------ 主配置菜单 ------------"
    echo " 1. 切换3D渲染器"
    echo " 2. 调整高级图形设置"
    echo " 3. 配置2D加速 (DirectDraw)"
    echo " 4. 重置所有设置为默认值"
    echo " 0. 退出配置工具"
    echo "-----------------------------------"
    read -rp "请输入选项 [0-4]: " choice

    case $choice in
      1) renderer_menu ;;
      2) advanced_menu ;;
      3) ddraw_menu ;;
      4) confirm_reset ;;
      0) exit 0 ;;
      *) echo "无效输入，请重新选择"; sleep 1 ;;
    esac
  done
}

# 渲染器选择菜单
renderer_menu() {
  while true; do
    show_status
    echo ""
    echo "------ 选择3D渲染后端 ------"
    echo " 1. 自动选择 (推荐)"
    echo " 2. OpenGL (兼容性好)"
    echo " 3. Vulkan (需要支持VK的显卡)"
    echo " 4. Direct3D9 (原生DLL时使用)"
    echo " 5. 软件渲染 (故障排除)"
    echo " 6. 禁用3D加速"
    echo " 0. 返回主菜单"
    read -rp "请选择渲染器 [0-6]: " option

    case $option in
      1) set_renderer "auto" ;;
      2) set_renderer "opengl" ;;
      3) set_renderer "vulkan" ;;
      4) set_renderer "d3d9" ;;
      5) set_renderer "gdi" ;;
      6) set_renderer "no3d" ;;
      0) return ;;
      *) echo "无效选项"; sleep 1 ;;
    esac
  done
}

# 设置渲染器函数
set_renderer() {
  wine reg add "HKCU\Software\Wine\Direct3D" /v renderer /d "$1" /f >/dev/null 2>&1
  echo "✔ 主渲染器已设置为：$1"
  sleep 1
}

# 高级图形设置菜单
advanced_menu() {
  while true; do
    show_status
    echo ""
    echo "------ 高级图形设置 ------"
    echo " 1. 切换CSMT多线程 [当前: $([ "$csmt_status" -eq 1 ] && echo "启用" || echo "禁用")]"
    echo " 2. 切换GLSL着色器 [当前: $([ "$glsl_status" -eq 1 ] && echo "启用" || echo "禁用")]"
    echo " 3. 切换严格着色模式 [当前: $([ "$strict_shaders" -eq 1 ] && echo "启用" || echo "禁用")]"
    echo " 0. 返回主菜单"
    read -rp "请选择要修改的选项 [0-3]: " option

    case $option in
      1) toggle_dword_param "CSMT" ;;
      2) toggle_dword_param "UseGLSL" ;;
      3) toggle_dword_param "StrictShaders" ;;
      0) return ;;
      *) echo "无效选项"; sleep 1 ;;
    esac
  done
}

# DDraw配置菜单
ddraw_menu() {
  while true; do
    show_status
    echo ""
    echo "------ DirectDraw配置 ------"
    echo " 1. GDI (兼容模式)"
    echo " 2. OpenGL (硬件加速)"
    echo " 3. Direct3D9 (原生加速)"
    echo " 4. 自动选择"
    echo " 0. 返回主菜单"
    read -rp "请选择DDraw渲染器 [0-4]: " option

    case $option in
      1) set_ddraw "gdi" ;;
      2) set_ddraw "opengl" ;;
      3) set_ddraw "d3d9" ;;
      4) set_ddraw "auto" ;;
      0) return ;;
      *) echo "无效选项"; sleep 1 ;;
    esac
  done
}

# 设置DDraw渲染器
set_ddraw() {
  wine reg add "HKCU\Software\Wine\Direct3D" /v DirectDrawRenderer /d "$1" /f >/dev/null 2>&1
  echo "✔ DDraw渲染器已设置为：$1"
  sleep 1
}
# 切换DWORD参数（安全版）
toggle_dword_param() {
  param="$1"
  current=$(get_reg_dword "$param" 0)
  new_value=$((1 - current))
  wine reg add "HKCU\Software\Wine\Direct3D" /v "$param" /t REG_DWORD /d "$new_value" /f >/dev/null 2>&1
  echo "✔ $param 已切换为：$([ "$new_value" -eq 1 ] && echo "启用" || echo "禁用")"
  sleep 1
}

# 其余菜单函数保持不变...

# 初始化环境
init_wine_env() {
  if ! command -v wine &> /dev/null; then
    echo "错误：未找到wine命令，请先安装Wine"
    exit 1
  fi
  # 强制创建注册表键（兼容所有Wine版本）
  wine reg add "HKCU\\Software\\Wine\\Direct3D" /f >/dev/null 2>&1 || {
    echo "注册表操作失败，请检查Wine配置"
    exit 1
  }
}

# 脚本入口
init_wine_env
main_menu
