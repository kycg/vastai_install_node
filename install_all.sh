#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Vast.ai provisioning script — installs ComfyUI custom nodes + FP8 models
# =============================================================================

# 1) Activate Python venv
source /venv/main/bin/activate

# 2) Paths
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_DIR}/custom_nodes"

# 3) System packages
echo "==> Updating APT and installing system packages..."
sudo apt-get update -y
sudo apt-get install -y git python3-pip aria2 dos2unix

# 4) Python packages
echo "==> Installing Python packages..."
pip install --no-cache-dir \
  sentencepiece piexif matplotlib segment-anything scikit-image \
  transformers opencv-python-headless GitPython \
  "scipy>=1.11.4" "dlib==19.22.0" \
  insightface onnxruntime facexlib

# =============================================================================
# 5) Install / update ComfyUI custom nodes
# =============================================================================
echo "==> Installing/updating ComfyUI custom nodes..."
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

mkdir -p "$CUSTOM_NODES_DIR"
for repo in "${BASE_NODES[@]}" "${ENHANCED_NODES[@]}"; do
  name=$(basename "$repo")
  dest="$CUSTOM_NODES_DIR/$name"
  if [[ -d "$dest" ]]; then
    echo "→ Updating node: $name"
    git -C "$dest" pull --ff-only || echo "⚠️  update failed: $name"
  else
    echo "→ Cloning node: $name"
    git clone --depth 1 "$repo" "$dest" || { echo "⚠️  clone failed: $name"; continue; }
  fi
  if [[ -f "$dest/requirements.txt" ]]; then
    echo "   Installing Python deps for $name"
    pip install --no-cache-dir -r "$dest/requirements.txt" \
      || echo "⚠️  pip install failed: $name"
  fi
done
echo "✅ Custom nodes installation complete."

# =============================================================================
# 6) Download FP8 models (16‑way parallel with aria2)
# =============================================================================
echo "==> Downloading FP8 model set..."
declare -A MODELS=(
  ["models/loras/FLUX.1-Turbo-Alpha.safetensors"]="https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors?download=true"
  ["models/clip/clip_l.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors?download=true"
  ["models/vae/flux-ae.safetensors"]="https://huggingface.co/foxmail/flux_vae/resolve/main/ae.safetensors?download=true"
  ["models/unet/flux1-dev-fp8-e4m3fn.safetensors"]="https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8-e4m3fn.safetensors?download=true"
  ["models/clip/t5xxl_fp8_e4m3fn.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors?download=true"
  ["models/unet/flux1-fill-dev-Q5_K_S.gguf"]="https://huggingface.co/YarvixPA/FLUX.1-Fill-dev-GGUF/resolve/main/flux1-fill-dev-Q5_K_S.gguf"
)

for subpath in "${!MODELS[@]}"; do
  url="${MODELS[$subpath]}"
  dest_dir="$COMFYUI_DIR/$(dirname "$subpath")"
  file="$(basename "$subpath")"
  mkdir -p "$dest_dir"
  if [[ -f "$dest_dir/$file" ]]; then
    echo "→ Skipping existing: $file"
  else
    echo "→ Downloading $file"
    aria2c -x16 -s16 -d "$dest_dir" -o "$file" "$url" \
      || echo "⚠️  failed to download: $file"
  fi
done
echo "✅ FP8 model download complete."

# =============================================================================
# 7) Done
# =============================================================================
echo "All done! ComfyUI nodes & FP8 models are installed in $COMFYUI_DIR."
