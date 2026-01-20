#!/bin/bash

# ===============================
# 加载配置文件（如果存在）
# ===============================
if [ -f "config_kitti_raw.sh" ]; then
    source config_kitti_raw.sh
    echo "[Info] Configuration loaded from config_kitti_raw.sh"
fi

# ===============================
# KITTI RAW数据集配置（默认值）
# ===============================
RAW_DATE="${RAW_DATE:-2011_09_26}"
RAW_DRIVE="${RAW_DRIVE:-2011_09_26_drive_0001_sync}"
DATA_ROOT="${DATA_ROOT:-/gz-data/dataset/${RAW_DATE}/${RAW_DRIVE}}"

# 输入图片目录（KITTI RAW数据集结构）
IMG_DIR="${IMG_DIR:-${DATA_ROOT}/image_02/data}"

# SAM权重文件路径
SAM_CHECKPOINT="${SAM_CHECKPOINT:-/gz-data/model/sam_vit_h_4b8939.pth}"
MODEL_TYPE="${SAM_MODEL_TYPE:-vit_h}"

# 输出目录（统一保存到result文件夹）
OUT_DIR="${RESULT_DIR:-result}"

# CUDA设备
CUDA_DEVICE="${CUDA_DEVICE:-cuda}"

# ===============================
# 路径检查与创建
# ===============================

# 创建result目录
mkdir -p "$OUT_DIR"
echo "[Info] Output directory: $OUT_DIR"

# 检查输入图片目录是否存在
if [ ! -d "$IMG_DIR" ]; then
    echo "[Error] Image directory not found: $IMG_DIR"
    echo "Please check the KITTI dataset path."
    exit 1
fi

# 检查SAM权重文件是否存在
if [ ! -f "$SAM_CHECKPOINT" ]; then
    echo "[Error] SAM checkpoint not found at $SAM_CHECKPOINT"
    echo "Please download it or update the path in this script."
    exit 1
fi

# ===============================
# 运行SAM & LSD提取
# ===============================
echo "=== Running SAM & LSD Extraction ==="
echo "Dataset: ${RAW_DRIVE}"
echo "Image Directory: $IMG_DIR"
echo "Output Directory: $OUT_DIR"
echo ""

python3 python/run_sam.py \
    --img_dir "$IMG_DIR" \
    --out_dir "$OUT_DIR" \
    --checkpoint "$SAM_CHECKPOINT" \
    --model_type "$MODEL_TYPE" \
    --device "$CUDA_DEVICE"

if [ $? -eq 0 ]; then
    echo ""
    echo "[Success] SAM Extraction Done."
    echo "Results saved to: $OUT_DIR"
else
    echo ""
    echo "[Error] SAM Extraction Failed with exit code $?"
    exit 1
fi