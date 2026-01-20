#!/bin/bash

# ===============================
# 加载配置文件（如果存在）
# ===============================
if [ -f "config_kitti_raw.sh" ]; then
    source config_kitti_raw.sh
    echo "[Info] Configuration loaded from config_kitti_raw.sh"
fi

# ===============================
# 配置参数（默认值）
# ===============================

# 特征所在目录（从result文件夹读取）
DATA_BASE="${RESULT_DIR:-result}"

# 指定用于标定的关键帧 ID
# KITTI RAW数据集的帧ID格式通常是10位数字，例如 0000000000
# 请根据实际数据修改此值
FRAME_ID="${FRAME_ID:-0000000000}"

# 初始外参猜测 (Initial Guess)
# 格式: rx ry rz tx ty tz (弧度, 米)
# 这是一个典型的 Velodyne 到 Camera 的粗略值
INIT_RX="${INIT_RX:-0.0}"
INIT_RY="${INIT_RY:-0.0}"
INIT_RZ="${INIT_RZ:-0.0}"
INIT_TX="${INIT_TX:-0.0}"
INIT_TY="${INIT_TY:--0.3}"
INIT_TZ="${INIT_TZ:-1.8}"


# 相机标定文件
CALIB_CAM_FILE="${CALIB_CAM_FILE:-${CALIB_FILE:-}}"

# ===============================
# 运行优化器
# ===============================

echo "=== HSR Lidar-Camera Calibration Optimizer ==="
echo "Data Directory: $DATA_BASE"
echo "Frame ID: $FRAME_ID"
echo "Initial Rotation (rx, ry, rz): $INIT_RX, $INIT_RY, $INIT_RZ"
echo "Initial Translation (tx, ty, tz): $INIT_TX, $INIT_TY, $INIT_TZ"
echo ""

# 构造数据的基础路径
INPUT_BASE="$DATA_BASE/$FRAME_ID"

# 检查result目录是否存在
if [ ! -d "$DATA_BASE" ]; then
    echo "[Error] Result directory not found: $DATA_BASE"
    echo "Please run run_sam_raw.sh and run_lidar_raw.sh first."
    exit 1
fi

# 检查输入文件是否存在
if [ ! -f "${INPUT_BASE}_points.txt" ]; then
    echo "[Error] Point features not found: ${INPUT_BASE}_points.txt"
    echo "Please run run_lidar_raw.sh first."
    echo ""
    echo "Available frames in $DATA_BASE:"
    ls -1 "$DATA_BASE"/*_points.txt 2>/dev/null | xargs -n 1 basename | sed 's/_points.txt//'
    exit 1
fi

if [ ! -f "${INPUT_BASE}_lines_3d.txt" ]; then
    echo "[Warning] 3D line features not found: ${INPUT_BASE}_lines_3d.txt"
fi

if [ ! -f "${INPUT_BASE}_mask_ids.png" ]; then
    echo "[Warning] Mask IDs not found: ${INPUT_BASE}_mask_ids.png"
    echo "Coarse stage will be skipped."
fi

# 检查optimizer可执行文件
if [ ! -f "./build/optimizer" ]; then
    echo "[Error] Optimizer executable not found: ./build/optimizer"
    echo "Please compile the project first."
    exit 1
fi

# 运行优化器
# 参数顺序: <data_base_path> <calib_file> <rx> <ry> <rz> <tx> <ty> <tz>
echo "[Running] ./build/optimizer..."
echo ""

./build/optimizer "$INPUT_BASE" \
    "$CALIB_CAM_FILE" \
    $INIT_RX $INIT_RY $INIT_RZ \
    $INIT_TX $INIT_TY $INIT_TZ

if [ $? -eq 0 ]; then
    echo ""
    echo "=== Optimization Finished Successfully ==="
    
    # 检查结果文件
    if [ -f "${INPUT_BASE}_calib_result.txt" ]; then
        echo "Result saved to: ${INPUT_BASE}_calib_result.txt"
        echo ""
        echo "--- Calibration Result ---"
        cat "${INPUT_BASE}_calib_result.txt"
        echo ""
        echo "[Info] Use visual_result.py to visualize the calibration result"
    else
        echo "[Warning] Calibration result file not found: ${INPUT_BASE}_calib_result.txt"
    fi
else
    echo ""
    echo "[Error] Optimization failed with exit code $?"
    exit 1
fi
