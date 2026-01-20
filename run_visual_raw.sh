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

# 图像目录
IMG_DIR="${IMG_DIR:-${DATA_ROOT}/image_02/data}"

# 相机标定文件（可选）
# KITTI RAW数据集的标定文件通常在 ${DATA_ROOT}/../calib_cam_to_cam.txt
CALIB_FILE="${CALIB_FILE:-${DATA_ROOT}/../calib_cam_to_cam.txt}"

# 结果目录
RESULT_DIR="${RESULT_DIR:-result}"

# 指定要可视化的帧ID
# 请根据标定结果选择合适的帧
OPTI_DIR="${OPTI_DIR:-${RESULT_DIR:-result}/opti}"

# 子采样因子
SUBSAMPLE="${SUBSAMPLE:-5}"

# ===============================
# 路径检查
# ===============================

echo "=== HSR Lidar-Camera Calibration Visualization ==="
echo "Dataset: ${RAW_DRIVE}"
echo "Frame ID: $FRAME_ID"
echo ""

# 检查图像文件
IMG_FILE="${IMG_DIR}/${FRAME_ID}.png"
if [ ! -f "$IMG_FILE" ]; then
    echo "[Error] Image file not found: $IMG_FILE"
    exit 1
fi

# 检查特征文件
FEATURE_BASE="${OPTI_DIR}/${FRAME_ID}"
if [ ! -f "${FEATURE_BASE}_points.txt" ]; then
    echo "[Error] Point features not found: ${FEATURE_BASE}_points.txt"
    echo "Please run run_lidar_raw.sh first."
    exit 1
fi

# 检查标定结果文件
CALIB_RESULT="${FEATURE_BASE}_calib_result.txt"
if [ ! -f "$CALIB_RESULT" ]; then
    echo "[Warning] Calibration result not found: $CALIB_RESULT"
    echo "Will use default transformation."
    echo "Please run run_opti_raw.sh first for better results."
fi

# 检查相机标定文件
if [ ! -f "$CALIB_FILE" ]; then
    echo "[Warning] Camera calibration file not found: $CALIB_FILE"
    echo "Will use default camera intrinsics."
    CALIB_FILE=""
fi

# ===============================
# 运行可视化
# ===============================

echo "[Running] Visualization..."
echo ""

OUTPUT_FILE="${OPTI_DIR}/visual_${FRAME_ID}.png"

if [ -n "$CALIB_FILE" ]; then
    # 使用标定文件
    python3 visual_result.py \
        --img "$IMG_FILE" \
        --feature_base "$FEATURE_BASE" \
        --calib_file "$CALIB_FILE" \
        --output "$OUTPUT_FILE" \
        --subsample "$SUBSAMPLE"
else
    # 不使用标定文件
    python3 visual_result.py \
        --img "$IMG_FILE" \
        --feature_base "$FEATURE_BASE" \
        --output "$OUTPUT_FILE" \
        --subsample "$SUBSAMPLE"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "[Success] Visualization complete!"
    echo "Output saved to: $OUTPUT_FILE"
else
    echo ""
    echo "[Error] Visualization failed with exit code $?"
    exit 1
fi
