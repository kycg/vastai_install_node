#!/usr/bin/env bash
# ComfyUI custom nodes installer (auto group aware)

set -euo pipefail

# 安装目录
INSTALL_DIR="${INSTALL_DIR:-/workspace/ComfyUI}"
PIP_BIN="${PIP_BIN:-pip}"

# ========= 分组定义 =========
unset -v GROUPS 2>/dev/null || true
declare -A GROUPS

# 基础组
GROUPS[base]="\
https://github.com/Comfy-Org/ComfyUI-Manager \
https://github.com/kycg/comfyui-Lora-auto-downloader \
https://github.com/city96/ComfyUI-GGUF"

# 增强组
GROUPS[enhanced]="\
https://github.com/crystian/ComfyUI-Crystools \
https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes \
https://github.com/valofey/Openrouter-Node \
https://github.com/WASasquatch/was-node-suite-comfyui"

GROUPS[kontext]="\
https://github.com/nunchaku-tech/ComfyUI-nunchaku \
https://github.com/Saquib764/omini-kontext \
https://github.com/liusida/ComfyUI-AutoCropFaces \
https://github.com/kijai/ComfyUI-Florence2 \
https://github.com/WASasquatch/was-node-suite-comfyui"

GROUPS[flux]="\
https://github.com/kycg/comfyui-Lora-auto-downloader \
https://github.com/city96/ComfyUI-GGUF \
https://github.com/XLabs-AI/x-flux-comfyui \
https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
https://github.com/valofey/Openrouter-Node \
https://github.com/kijai/ComfyUI-Florence2 \
https://github.com/pythongosssss/ComfyUI-WD14-Tagger \
https://github.com/WASasquatch/was-node-suite-comfyui"

GROUPS[wan]="\
https://github.com/kycg/comfyui-Lora-auto-downloader \
https://github.com/city96/ComfyUI-GGUF \
https://github.com/valofey/Openrouter-Node \
https://github.com/kijai/ComfyUI-WanVideoWrapper \
https://github.com/kijai/ComfyUI-KJNodes \
https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
https://github.com/stduhpf/ComfyUI-WanMoeKSampler \
https://github.com/kijai/ComfyUI-Florence2 \
https://github.com/pythongosssss/ComfyUI-WD14-Tagger \
https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
https://github.com/WASasquatch/was-node-suite-comfyui"


# 单节点别名
GROUPS[wanxxx]="https://github.com/WASasquatch/was-node-suite-comfyui"

# 示例：自定义新组
# GROUPS[sdxl]="https://github.com/xxx/ComfyUI-SDXL-Tool https://github.com/yyy/ComfyUI-SDXL-Refiner"
# GROUPS[windows]="https://github.com/zzz/ComfyUI-Windows-Nodes"

# ========= 工具函数 =========
usage() {
  echo "用法: $0 [组名|URL]..."
  echo "示例:"
  echo "  $0 base          安装 base 组"
  echo "  $0 enhanced      安装 enhanced 组"
  echo "  $0 flux wan      同时安装 flux 和 wan"
  echo "  $0 sdxl          安装你自己添加的 sdxl 组"
  echo "  $0 https://...   安装单个仓库"
  echo ""
  echo "可用组:"
  for g in "${!GROUPS[@]}"; do
    echo "  - $g"
  done
}

is_url() {
  [[ "$1" =~ ^https?://[^[:space:]]+$ ]]
}

install_repo() {
  local repo="$1"
  local name path
  name="$(basename "$repo")"
  path="$INSTALL_DIR/custom_nodes/$name"

  mkdir -p "$INSTALL_DIR/custom_nodes"

  if [[ -d "$path" ]]; then
    echo "Updating node: $name"
    git config --global --add safe.directory "$path" || true
    git -C "$path" pull --ff-only || echo "Warning: failed to update $name"
  else
    echo "Cloning node: $name"
    git clone --depth 1 "$repo" "$path" || { echo "Warning: failed to clone $name"; return; }
  fi

  if [[ -f "$path/requirements.txt" ]]; then
    echo "Installing dependencies for $name"
    $PIP_BIN install -r "$path/requirements.txt" || echo "Warning: failed to install deps for $name"
  fi
}

# ========= 主程序 =========
main() {
  [[ $# -eq 0 ]] && { usage; exit 1; }

  local targets=()
  for arg in "$@"; do
    if is_url "$arg"; then
      targets+=("$arg")
    elif [[ -n "${GROUPS[$arg]+set}" ]]; then
      # 展开组里的所有 repo
      # shellcheck disable=SC2206
      targets+=(${GROUPS[$arg]})
    else
      echo "未知的组名或URL: $arg"
      usage
      exit 1
    fi
  done

  echo "=== Installing ComfyUI Custom Nodes ==="
  for repo in "${targets[@]}"; do
    install_repo "$repo"
  done
  echo "=== Installation complete ==="
}

main "$@"
