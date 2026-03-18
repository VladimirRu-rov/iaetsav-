#!/bin/bash
set -e

# Активация окружения
source /venv/main/bin/activate

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
VENV_PYTHON="/venv/main/bin/python"
VENV_PIP="/venv/main/bin/pip"

# Настройки API и Турбо-движка
export PYTORCH_ALLOC_CONF="expandable_segments:True"
export HF_HUB_ENABLE_HF_TRANSFER=1

if [ -z "$HF_TOKEN" ]; then
    echo -e "\033[0;31m [!] WARNING: HF_TOKEN не найден в Environment Variables! \033[0m"
    echo -e "\033[0;33m Передай его через Vast.ai: -e HF_TOKEN=hf_... \033[0m"
fi

echo "=== ComfyUI запускает ( ХУХУХУХУХУ ) ==="

# Предварительная установка турбо-загрузчика
$VENV_PIP install --no-cache-dir hf_transfer

echo ">>> Оптимизация библиотек мониторинга и ускорение DWPose..."
$VENV_PIP uninstall -y pynvml && $VENV_PIP install nvidia-ml-py
$VENV_PIP install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

APT_PACKAGES=()
PIP_PACKAGES=()

NODES=(
    "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    "https://github.com/chflame163/ComfyUI_LayerStyle"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/kijai/ComfyUI-segment-anything-2"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/fq393/ComfyUI-ZMG-Nodes"
    "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/jnxmx/ComfyUI_HuggingFace_Downloader"
    "https://github.com/hanjangma41/NEW-UTILSs.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
)


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
        
        # --- БРОНЕБОЙНЫЙ ТУРБО-РЕЖИМ (3 попытки на каждый файл) ---
        local max_retries=3
        local attempt=1
        local success=0

        while [ $attempt -le $max_retries ]; do
            if $VENV_PYTHON -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='$repo_id', filename='$filename', local_dir='$dir', local_dir_use_symlinks=False, token='$HF_TOKEN')"; then
                success=1
                break # Успешно скачали, выходим из цикла
            else
                echo "⚠️ Обрыв связи при скачивании $filename (Попытка $attempt из $max_retries). Пробуем снова через 3 секунды..."
                attempt=$((attempt + 1))
                sleep 3
            fi
        done

        if [ $success -eq 0 ]; then
            echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Не удалось скачать $filename даже после $max_retries попыток. Идем дальше..."
        fi
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

    # --- БЛОК 10: ANIMATOR_X ---
    echo "##############################################"
    echo "# РЕЖИМ: ANIMATOR_X                          #"
    echo "##############################################"
    download_hf "Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" "$COMFYUI_DIR/models/diffusion_models"
    download_hf "wan_2.1_vae.safetensors" "$COMFYUI_DIR/models/vae"
    download_hf "clip_vision_h.safetensors" "$COMFYUI_DIR/models/clip_vision"
    download_hf "umt5_xxl_fp8_e4m3fn_scaled.safetensors" "$COMFYUI_DIR/models/clip"
    download_hf "lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "yolov10m.onnx" "$COMFYUI_DIR/models/detection"
    download_hf "vitpose_h_wholebody_model.onnx" "$COMFYUI_DIR/models/detection"
    download_hf "vitpose_h_wholebody_data.bin" "$COMFYUI_DIR/models/detection"
    download_hf "vitpose-l-wholebody.onnx" "$COMFYUI_DIR/models/detection"
    download_hf "sam2.1_hiera_large.safetensors" "$COMFYUI_DIR/models/sam2"

    provisioning_get_files "${COMFYUI_DIR}/models/upscale_models"     "${UPSCALER_MODELS[@]}"

    echo "HERWAM настроил всё!"
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
