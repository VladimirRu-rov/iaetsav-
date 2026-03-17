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

echo "=== ComfyUI запускает ( NSFW ) ==="

# Предварительная установка турбо-загрузчика
$VENV_PIP install --no-cache-dir hf_transfer

echo ">>> Оптимизация библиотек мониторинга и ускорение DWPose..."
$VENV_PIP uninstall -y pynvml && $VENV_PIP install nvidia-ml-py
$VENV_PIP install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

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
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/ubilabs/node-image-saver.git"
)

# --- ФУНКЦИИ ---

# Универсальная турбо-загрузка
download_hf() {
    local file_or_url=$1
    local dir=$2
    local repo=${3:-"VladimirSoch/What"} 
    
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
       $VENV_PYTHON -c "from huggingface_hub import hf_hub_download; hf_hub_download(repo_id='$repo_id', filename='$filename', local_dir='$dir', local_dir_use_symlinks=False, token='$HF_TOKEN')" || echo "⚠️ Ошибка загрузки $filename, пропускаем..."
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
    echo "# РЕЖИМ: NSFW                                #"
    echo "##############################################"
    
    # Модели диффузии и Чекпоинты
    download_hf "Flux2_9b.safetensors" "$COMFYUI_DIR/models/diffusion_models"
    download_hf "Realism.safetensors" "$COMFYUI_DIR/models/checkpoints"
    download_hf "Clip.safetensors" "$COMFYUI_DIR/models/text_encoders"
    download_hf "flux2_vae.safetensors" "$COMFYUI_DIR/models/vae"
    download_hf "face_yolov8m.pt" "$COMFYUI_DIR/models/ultralytics/bbox"
    download_hf "RealLora.safetensors" "$COMFYUI_DIR/models/loras"
    download_hf "female_breast-v4.2.pt" "$COMFYUI_DIR/models/loras"
    download_hf "Eyeful_v2.pt" "$COMFYUI_DIR/models/ultralytics/bbox"
    download_hf "hand_yolov8s.pt" "$COMFYUI_DIR/models/ultralytics/bbox"
    download_hf "person_yolov8mseg.pt" "$COMFYUI_DIR/models/ultralytics/segm"
    download_hf "4x_Remacri.pth" "$COMFYUI_DIR/models/upscale_models"
    download_hf "sam_vit_b_01ec64.pth" "$COMFYUI_DIR/models/sams"

    echo "HERWAM настроил всё под NSFW!"
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

cd "${COMFYUI_DIR}"
export TORCH_CUDNN_V8_API_ENABLED=0

echo ">>> Очистка портов..."
fuser -k 8188/tcp || true

echo "=== ЕБАШИМ ДЕНЬГИ запускает ComfyUI ==="
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

$VENV_PYTHON main.py --listen 0.0.0.0 --port 8188 --highvram --use-pytorch-cross-attention
