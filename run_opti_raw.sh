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

# 特征所在目录（从result子目录读取）
SAM_DIR="${SAM_DIR:-${RESULT_DIR:-result}/sam}"
LIDAR_DIR="${LIDAR_DIR:-${RESULT_DIR:-result}/lidar}"
OPTI_DIR="${OPTI_DIR:-${RESULT_DIR:-result}/opti}"

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



# ===============================
# 运行优化器
# ===============================

echo "=== HSR Lidar-Camera Calibration Optimizer ==="
echo "Data Directory: $OPTI_DIR"
echo "Frame ID: $FRAME_ID"
echo "Initial Rotation (rx, ry, rz): $INIT_RX, $INIT_RY, $INIT_RZ"
echo "Initial Translation (tx, ty, tz): $INIT_TX, $INIT_TY, $INIT_TZ"
echo ""

# 相机标定文件（可选）
# KITTI RAW数据集的标定文件通常在 ${DATA_ROOT}/../calib_cam_to_cam.txt
CALIB_FILE="${CALIB_FILE:-${DATA_ROOT:-/gz-data/dataset/${RAW_DATE:-2011_09_26}/${RAW_DRIVE:-2011_09_26_drive_0001_sync}}/../calib_cam_to_cam.txt}"

# 构造数据的基础路径
INPUT_BASE="$OPTI_DIR/$FRAME_ID"
LIDAR_BASE="$LIDAR_DIR/$FRAME_ID"
SAM_BASE="$SAM_DIR/$FRAME_ID"

# 检查输入目录是否存在
if [ ! -d "$LIDAR_DIR" ]; then
    echo "[Error] Lidar result directory not found: $LIDAR_DIR"
    echo "Please run run_sam_raw.sh and run_lidar_raw.sh first."
    exit 1
fi
if [ ! -d "$SAM_DIR" ]; then
    echo "[Error] SAM result directory not found: $SAM_DIR"
    echo "Please run run_sam_raw.sh first."
    exit 1
fi

# 创建优化输出目录
mkdir -p "$OPTI_DIR"
echo "[Info] Output directory: $OPTI_DIR"

# 检查输入文件是否存在
if [ ! -f "${LIDAR_BASE}_points.txt" ]; then
    echo "[Error] Point features not found: ${LIDAR_BASE}_points.txt"
    echo "Please run run_lidar_raw.sh first."
    echo ""
    echo "Available frames in $LIDAR_DIR:"
    ls -1 "$LIDAR_DIR"/*_points.txt 2>/dev/null | xargs -n 1 basename | sed 's/_points.txt//'
    exit 1
fi

if [ ! -f "${LIDAR_BASE}_lines_3d.txt" ]; then
    echo "[Warning] 3D line features not found: ${LIDAR_BASE}_lines_3d.txt"
fi

if [ ! -f "${SAM_BASE}_mask_ids.png" ]; then
    echo "[Warning] Mask IDs not found: ${SAM_BASE}_mask_ids.png"
    echo "Coarse stage will be skipped."
fi

# 检查相机标定文件
if [ ! -f "$CALIB_FILE" ]; then
    echo "[Warning] Camera calibration file not found: $CALIB_FILE"
    echo "Will use default camera intrinsics."
    CALIB_FILE=""
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

ln -sf "${LIDAR_BASE}_points.txt" "${INPUT_BASE}_points.txt"
if [ -f "${LIDAR_BASE}_lines_3d.txt" ]; then
    ln -sf "${LIDAR_BASE}_lines_3d.txt" "${INPUT_BASE}_lines_3d.txt"
fi
if [ -f "${SAM_BASE}_lines_2d.txt" ]; then
    ln -sf "${SAM_BASE}_lines_2d.txt" "${INPUT_BASE}_lines_2d.txt"
fi
if [ -f "${SAM_BASE}_mask_ids.png" ]; then
    ln -sf "${SAM_BASE}_mask_ids.png" "${INPUT_BASE}_mask_ids.png"
fi

#if [ -n "$CALIB_FILE" ]; then
 #   ./build/optimizer "$INPUT_BASE" "$CALIB_FILE" \
  #      $INIT_RX $INIT_RY $INIT_RZ \
 #       $INIT_TX $INIT_TY $INIT_TZ \
#        "$CALIB_FILE"
#else
 #   ./build/optimizer "$INPUT_BASE" "" \
#        $INIT_RX $INIT_RY $INIT_RZ \
#        $INIT_TX $INIT_TY $INIT_TZ
#fi

optimizer_args=("$INPUT_BASE" "${CALIB_FILE:-}")
optimizer_args+=("$INIT_RX" "$INIT_RY" "$INIT_RZ" "$INIT_TX" "$INIT_TY" "$INIT_TZ")

./build/optimizer "${optimizer_args[@]}"
optimizer_status=$?

if [ $optimizer_status -eq 0 ]; then
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
