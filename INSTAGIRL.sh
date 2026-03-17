#!/bin/bash
set -e

# Активация окружения
source /venv/main/bin/activate

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PYTHON="/venv/main/bin/python"
VENV_PIP="/venv/main/bin/pip"

# Настройки API и Турбо-движка
export HF_HUB_ENABLE_HF_TRANSFER=1

if [ -z "$HF_TOKEN" ]; then
    echo -e "\033[0;31m [!] WARNING: HF_TOKEN не найден в Environment Variables! \033[0m"
    echo -e "\033[0;33m Передай его через Vast.ai: -e HF_TOKEN=hf_... \033[0m"
fi

echo "=== ComfyUI запускает ( ИНСТА СУЧКА ) ==="

# Предварительная установка турбо-загрузчика
$VENV_PIP install --no-cache-dir hf_transfer

APT_PACKAGES=()
PIP_PACKAGES=()

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/kijai/ComfyUI-segment-anything-2"
    "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader"
    "https://github.com/fq393/ComfyUI-ZMG-Nodes"
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/chrisgoringe/cg-use-everywhere"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/plugcrypt/CRT-Nodes"
    "https://github.com/evanspearman/ComfyMath"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Smirnov75/ComfyUI-mxToolkit"
    "https://github.com/TheLustriVA/ComfyUI-Image-Size-Tools"
    "https://github.com/ZhiHui6/zhihui_nodes_comfyui"
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes"
    "https://github.com/teskor-hub/comfyui-teskors-utils"
    "https://github.com/hanjangma41/NEW-UTILSs"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
)

# --- МАССИВЫ С ПОЛНЫМИ ССЫЛКАМИ ---
CLIP_MODELS=("https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors")
VAE_MODELS=("https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors")
DETECTION_MODELS=("https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx")
UPSCALER_MODELS=("https://huggingface.co/GerbyHorty76/videoloras/resolve/main/4xUltrasharp_4xUltrasharpV10.pt")

# --- ФУНКЦИИ ---

# Универсальная турбо-загрузка
download_hf() {
    local file_or_url=$1
    local dir=$2
    local repo=${3:-"VladimirSoch/For_Work"} 
    
    mkdir -p "$dir"
    
    if [[ "$file_or_url" =~ huggingface\.co ]]; then
        local repo_id=$(echo "$file_or_url" | sed -E 's|https://huggingface.co/([^/]+/[^/]+)/resolve/[^/]+/(.*)|\1|')
        local filename=$(echo "$file_or_url" | sed -E 's|https://huggingface.co/([^/]+/[^/]+)/resolve/[^/]+/(.*)|\2|')
    else
        local repo_id="$repo"
        local filename="$file_or_url"
    fi

    if [ ! -f "$dir/$filename" ]; then
        echo "🚀 HF Turbo Download: $filename"
        $VENV_PYTHON -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='$repo_id', filename='$filename', local_dir='$dir', local_dir_use_symlinks=False, token='$HF_TOKEN')"
    fi
}

function provisioning_get_files() {
    local dir="$1"
    shift
    local files=("$@")
    for item in "${files[@]}"; do
        download_hf "$item" "$dir"
    done
}

function provisioning_start() {
    provisioning_get_apt_packages
    provisioning_clone_comfyui
    provisioning_install_base_reqs
    provisioning_get_nodes
    provisioning_get_pip_packages

    echo "##############################################"
    echo "# РЕЖИМ: INSTAGIRL                           #"
    echo "##############################################"
    
    # Загрузка воркфлоу
    download_hf "instagirl2.5.json" "$WORKSPACE/.sys_cache/workflows" "VladimirSoch/WORKFLOWS"
    download_hf "PHOTOUPSCALE.json" "$WORKSPACE/.sys_cache/workflows" "VladimirSoch/WORKFLOWS"

    # Lora-пак
    download_hf "Instagirlv2.5-HIGH.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "Instagirlv2.5-LOW.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "Lenovo.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors" "$COMFYUI_DIR/models/loras"
    
    # VAE & Text Encoders
    download_hf "wan_2.1_vae.safetensors" "$COMFYUI_DIR/models/vae"
    download_hf "umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$COMFYUI_DIR/models/clip"
    
    # Diffusion Models (GGUF Wan 2.2)
    download_hf "Wan2.2-T2V-A14B-HighNoise-Q8_0.gguf" "$COMFYUI_DIR/models/diffusion_models"
    download_hf "Wan2.2-T2V-A14B-LowNoise-Q8_0.gguf" "$COMFYUI_DIR/models/diffusion_models"
    
    # Detection
    download_hf "vitpose_h_wholebody_model.onnx" "$COMFYUI_DIR/models/detection"
    download_hf "vitpose_h_wholebody_data.bin" "$COMFYUI_DIR/models/detection"

    echo "HERWAM настроил всё под INSTAGIRL!"
}

function provisioning_clone_comfyui() {
    if [[ ! -d "${COMFYUI_DIR}" ]]; then
        git clone https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    fi
}

function provisioning_install_base_reqs() {
    cd "${COMFYUI_DIR}"
    $VENV_PIP install --no-cache-dir -r requirements.txt
}

function provisioning_get_apt_packages() {
    if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
        sudo apt update && sudo apt install -y "${APT_PACKAGES[@]}"
    fi
}

function provisioning_get_pip_packages() {
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        $VENV_PIP install --no-cache-dir "${PIP_PACKAGES[@]}"
    fi
}

function provisioning_get_nodes() {
    mkdir -p "${COMFYUI_DIR}/custom_nodes"
    cd "${COMFYUI_DIR}/custom_nodes"
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="./${dir}"
        if [[ ! -d "$path" ]]; then
            git clone "$repo" "$path" --recursive
        fi
        if [[ -f "$path/requirements.txt" ]]; then
            sed -i '/torch/d; /torchvision/d' "$path/requirements.txt"
            $VENV_PIP install --no-cache-dir -r "$path/requirements.txt"
        fi
    done
}

provisioning_start

rm -f /.provisioning

echo "=== ХЕРВАМ запускает ComfyUI ==="
cd "${COMFYUI_DIR}"
export TORCH_CUDNN_V8_API_ENABLED=0
$VENV_PYTHON main.py --listen 0.0.0.0 --port 8188 --highvram --use-pytorch-cross-attention

# --- ФИНАЛЬНЫЙ БАННЕР HERWAM ---
echo "##############################################################"
echo "#                                                            #"
echo "#  _    _  ______  _____  __          __     __  __          #"
echo "# | |  | ||  ____||  __ \ \ \        / /\   |  \/  |         #"
echo "# | |__| || |__   | |__) | \ \  /\  / /  \  | \  / |         #"
echo "# |  __  ||  __|  |  _  /   \ \/  \/ / /\ \ | |\/| |         #"
echo "# | |  | || |____ | | \ \    \  /\  / ____ \| |  | |         #"
echo "# |_|  |_||______||_|  \_\    \/  \/_/    \_\_|  |_|         #"
echo "#                                                            #"
echo "##############################################################"
echo " "
# --- ВЫВОД ПРАВ СОБСТВЕННОСТИ В ЛОГИ ---
echo "#################################################################################"
echo "#                                                                               #"
echo "#   (c) 2026 HERWAM. ALL RIGHTS RESERVED.                                       #"
echo "#                                                                               #"
echo "#   THIS CONFIGURATION FILE IS THE INTELLECTUAL PROPERTY OF THE OWNER.          #"
echo "#   ANY COPYING, DISTRIBUTION, OR USE OF THIS CODE WITHOUT THE EXPRESS          #"
echo "#   WRITTEN PERMISSION OF THE OWNER IS STRICTLY PROHIBITED.                     #"
echo "#                                                                               #"
echo "#   (c) 2026 HERWAM. ВСЕ ПРАВА ЗАЩИЩЕНЫ.                                        #"
echo "#                                                                               #"
echo "#   ДАННЫЙ ФАЙЛ ЯВЛЯЕТСЯ ИНТЕЛЛЕКТУАЛЬНОЙ СОБСТВЕННОСТЬЮ ВЛАДЕЛЬЦА.             #"
echo "#   КОПИРОВАНИЕ ИЛИ ИСПОЛЬЗОВАНИЕ БЕЗ РАЗРЕШЕНИЯ СТРОГО ЗАПРЕЩЕНО.              #"
echo "#   ДЛЯ СОТРУДНИЧЕСТВА ОБРАЩАТЬСЯ В TG https://t.me/vnknshn                     #"
echo "#################################################################################"
echo " "