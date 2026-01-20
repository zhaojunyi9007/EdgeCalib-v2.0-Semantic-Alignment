#!/bin/bash

# ===============================
# HSR Lidar-Camera 标定系统配置文件
# ===============================
# 所有脚本将从此文件读取配置参数
# 修改此文件后，所有脚本自动使用新配置
# ===============================

# ===============================
# KITTI RAW 数据集配置
# ===============================

# 数据集日期和序列名称
export RAW_DATE="2011_09_26"
export RAW_DRIVE="2011_09_26_drive_0001_sync"

# 数据集根目录
export DATA_ROOT="/gz-data/dataset/${RAW_DATE}/${RAW_DRIVE}"

# 图像目录（RAW数据集的image_02/data子目录）
export IMG_DIR="${DATA_ROOT}/image_02/data"

# 点云目录（RAW数据集的velodyne_points/data子目录）
export BIN_DIR="${DATA_ROOT}/velodyne_points/data"

# 相机标定文件（可选）
# 通常在数据集根目录的上一级
export CALIB_FILE="${DATA_ROOT}/../calib_cam_to_cam.txt"

# ===============================
# 模型配置
# ===============================

# SAM模型权重文件路径
export SAM_CHECKPOINT="/gz-data/model/sam_vit_h_4b8939.pth"

# SAM模型类型
export SAM_MODEL_TYPE="vit_h"

# ===============================
# 输出配置
# ===============================

# 结果输出目录（所有结果统一保存在此目录）
export RESULT_DIR="result"

# ===============================
# 标定参数配置
# ===============================

# 关键帧ID（用于标定的帧）
# KITTI RAW数据集通常使用10位数字，如 "0000000000"
# 请根据实际数据修改
export FRAME_ID="0000000000"

# 初始外参猜测值（弧度和米）
# 这是Velodyne到Camera的典型初始值
export INIT_RX=0.0      # 旋转向量 x (弧度)
export INIT_RY=0.0      # 旋转向量 y (弧度)
export INIT_RZ=0.0      # 旋转向量 z (弧度)
export INIT_TX=0.0      # 平移 x (米)
export INIT_TY=-0.3     # 平移 y (米)
export INIT_TZ=1.8      # 平移 z (米)

# ===============================
# 可视化参数
# ===============================

# 点云子采样因子（每隔N个点绘制一次）
export SUBSAMPLE=5

# ===============================
# 设备配置
# ===============================

# CUDA设备（用于SAM）
export CUDA_DEVICE="cuda"

# 编译并行数（用于make -j）
export MAKE_JOBS=4

# ===============================
# 提示信息
# ===============================

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # 直接运行此脚本时显示配置信息
    echo "=== HSR Lidar-Camera 标定系统配置 ==="
    echo ""
    echo "数据集配置:"
    echo "  日期: $RAW_DATE"
    echo "  序列: $RAW_DRIVE"
    echo "  数据根目录: $DATA_ROOT"
    echo "  图像目录: $IMG_DIR"
    echo "  点云目录: $BIN_DIR"
    echo "  相机标定: $CALIB_FILE"
    echo ""
    echo "模型配置:"
    echo "  SAM权重: $SAM_CHECKPOINT"
    echo "  SAM类型: $SAM_MODEL_TYPE"
    echo ""
    echo "输出配置:"
    echo "  结果目录: $RESULT_DIR"
    echo ""
    echo "标定配置:"
    echo "  关键帧ID: $FRAME_ID"
    echo "  初始旋转 (rx,ry,rz): $INIT_RX, $INIT_RY, $INIT_RZ"
    echo "  初始平移 (tx,ty,tz): $INIT_TX, $INIT_TY, $INIT_TZ"
    echo ""
    echo "使用方法:"
    echo "  1. 修改本文件中的配置参数"
    echo "  2. 运行: source config_kitti_raw.sh"
    echo "  3. 或直接运行使用此配置的脚本"
    echo ""
fi
