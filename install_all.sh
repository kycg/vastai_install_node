#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# One‑stop ComfyUI installer + FP8 models (parallel in tmux windows)
# =============================================================================

# -- Configuration ------------------------------------------------------------
INSTALL_DIR="${INSTALL_DIR:-/workspace/ComfyUI}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# -- Dependency installation --------------------------------------------------
install_deps() {
  echo "==> Installing system dependencies..."
  apt update
  apt install -y git python3-pip aria2 dos2unix tmux
}

# -- ComfyUI node list --------------------------------------------------------
BASE_NODES=(
  "https://github.com/kycg/comfyui-Lora-auto-downloader"
  "https://github.com/crystian/ComfyUI-Crystools"
  "https://github.com/XLabs-AI/x-flux-comfyui"
  "https://github.com/city96/ComfyUI-GGUF"
)
ENHANCED_NODES=(
  "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
  "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
  "https://github.com/valofey/Openrouter-Node"
  "https://github.com/WASasquatch/was-node-suite-comfyui"
)

download_nodes() {
  echo "==> [nodes] Installing/updating ComfyUI custom nodes..."
  mkdir -p "$INSTALL_DIR/custom_nodes"
  for repo in "${BASE_NODES[@]}" "${ENHANCED_NODES[@]}"; do
    name=$(basename "$repo")
    dest="$INSTALL_DIR/custom_nodes/$name"
    if [[ -d "$dest" ]]; then
      echo "→ Updating node: $name"
      git -C "$dest" pull --ff-only || echo "⚠️  Failed to update $name, continuing..."
    else
      echo "→ Cloning node: $name"
      git clone --depth 1 "$repo" "$dest" || { echo "⚠️  Clone failed for $name, skipping."; continue; }
    fi
    if [[ -f "$dest/requirements.txt" ]]; then
      echo "   Installing deps for $name"
      pip install --no-cache-dir -r "$dest/requirements.txt" \
        || echo "⚠️  Pip install failed for $name, skipping deps."
    fi
  done
  echo "✅  [nodes] Complete."
}

# -- FP8 model list -----------------------------------------------------------
declare -A MODELS=(
  ["$INSTALL_DIR/models/loras/FLUX.1-Turbo-Alpha.safetensors"]="https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors?download=true"
  ["$INSTALL_DIR/models/clip/clip_l.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors?download=true"
  ["$INSTALL_DIR/models/vae/flux-ae.safetensors"]="https://huggingface.co/foxmail/flux_vae/resolve/main/ae.safetensors?download=true"
  ["$INSTALL_DIR/models/unet/flux1-dev-fp8-e4m3fn.safetensors"]="https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8-e4m3fn.safetensors?download=true"
  ["$INSTALL_DIR/models/clip/t5xxl_fp8_e4m3fn.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors?download=true"
  ["$INSTALL_DIR/models/unet/flux1-fill-dev-Q5_K_S.gguf"]="https://huggingface.co/YarvixPA/FLUX.1-Fill-dev-GGUF/resolve/main/flux1-fill-dev-Q5_K_S.gguf"
)

download_models() {
  echo "==> [models] Downloading FP8 model set (16 threads each file)..."
  for dest in "${!MODELS[@]}"; do
    url=${MODELS[$dest]}
    dir=$(dirname "$dest")
    file=$(basename "$dest")
    mkdir -p "$dir"
    if [[ -f "$dest" ]]; then
      echo "→ Skipping existing: $file"
    else
      echo "→ Downloading $file"
      aria2c -x16 -s16 -d "$dir" -o "$file" "$url" \
        || echo "⚠️  Failed to download $file"
    fi
  done
  echo "✅  [models] Complete."
}

# -- Main control flow --------------------------------------------------------
case "${1:-}" in
  nodes)
    download_nodes
    exit 0
    ;;
  models)
    download_models
    exit 0
    ;;
  *)
    install_deps
    echo "==> Launching tmux session 'comfy_setup' with two windows..."
    # Start tmux session
    tmux new-session -d -s comfy_setup -n nodes \
      "bash -lc '${SCRIPT_PATH} nodes; exec bash'"
    tmux new-window -t comfy_setup:1 -n models \
      "bash -lc '${SCRIPT_PATH} models; exec bash'"
    echo "Attach with: tmux attach -t comfy_setup"
    tmux attach -t comfy_setup
    ;;
esac
