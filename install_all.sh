#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Vast.ai provisioning script — ComfyUI custom nodes + FP8 models (multi-threaded)
# =============================================================================

# 1) Activate virtualenv
source /venv/main/bin/activate

# 2) ComfyUI install directory
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

# 3) APT & PIP packages
APT_INSTALL=${APT_INSTALL:-"apt update && apt install -y"}
APT_PACKAGES=(
    git
    python3-pip
    aria2
    dos2unix
)
PIP_PACKAGES=(
    # add any global pip deps here, e.g. sentencepiece, transformers…
)

# ──────────────────────────────────────────────────────────────────────────────
# 4) Node lists
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

# 5) FP8 model URLs
declare -A FP8_MODELS=(
    ["loras/FLUX.1-Turbo-Alpha.safetensors"]="https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors?download=true"
    ["clip/clip_l.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors?download=true"
    ["vae/flux-ae.safetensors"]="https://huggingface.co/foxmail/flux_vae/resolve/main/ae.safetensors?download=true"
    ["unet/flux1-dev-fp8-e4m3fn.safetensors"]="https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8-e4m3fn.safetensors?download=true"
    ["clip/t5xxl_fp8_e4m3fn.safetensors"]="https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors?download=true"
    ["unet/flux1-fill-dev-Q5_K_S.gguf"]="https://huggingface.co/YarvixPA/FLUX.1-Fill-dev-GGUF/resolve/main/flux1-fill-dev-Q5_K_S.gguf"
)

# =============================================================================
# Helpers
# =============================================================================

function print_header() {
    cat << 'EOF'

##############################################
#                                            #
#          Provisioning container            #
#                                            #
#         This will take some time           #
#                                            #
# Your container will be ready on completion #
#                                            #
##############################################

EOF
}

function print_end() {
    echo -e "\n✅ Provisioning complete."
}

# Install APT packages
function install_apt() {
    echo "==> Installing APT packages: ${APT_PACKAGES[*]}"
    sudo ${APT_INSTALL} "${APT_PACKAGES[@]}"
}

# Install PIP packages
function install_pip() {
    if (( ${#PIP_PACKAGES[@]} )); then
        echo "==> Installing PIP packages: ${PIP_PACKAGES[*]}"
        pip install --no-cache-dir "${PIP_PACKAGES[@]}"
    fi
}

# Clone or update nodes
function download_nodes() {
    mkdir -p "${COMFYUI_DIR}/custom_nodes"
    for repo in "${@}"; do
        name=$(basename "$repo")
        dest="${COMFYUI_DIR}/custom_nodes/${name}"
        if [[ -d "$dest" ]]; then
            echo "→ Updating node: $name"
            git -C "$dest" pull --ff-only || echo "⚠️  update failed: $name"
        else
            echo "→ Cloning node: $name"
            git clone --depth 1 "$repo" "$dest" || { echo "⚠️  clone failed: $name"; continue; }
        fi
        if [[ -f "$dest/requirements.txt" ]]; then
            echo "   Installing deps for $name"
            pip install --no-cache-dir -r "$dest/requirements.txt" \
                || echo "⚠️  pip install failed: $name"
        fi
    done
}

# Wrapper for download_nodes
function get_nodes() {
    echo "==> Installing/updating ComfyUI custom nodes..."
    download_nodes "${BASE_NODES[@]}" "${ENHANCED_NODES[@]}"
    echo "✅ Nodes done."
}

# Multi-threaded download via aria2c
function download_fp8_models() {
    echo "==> Downloading FP8 models (16× threads)..."
    for subpath in "${!FP8_MODELS[@]}"; do
        url="${FP8_MODELS[$subpath]}"
        dir="${COMFYUI_DIR}/models/${subpath%/*}"
        mkdir -p "$dir"
        filename=$(basename "${subpath}")
        echo "→ $filename"
        aria2c -x16 -s16 -d "$dir" -o "$filename" "$url" \
            || echo "⚠️  failed: $filename"
    done
    echo "✅ FP8 models done."
}

# =============================================================================
# Main
# =============================================================================

if [[ ! -f /.noprovisioning ]]; then
    print_header
    install_apt
    get_nodes
    install_pip
    download_fp8_models
    print_end
fi
