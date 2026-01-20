#!/bin/bash

# ===============================
# HSR Lidar-Camera 标定完整流程
# ===============================
# 此脚本按顺序执行所有步骤：
# 1. SAM分割和2D线提取
# 2. LiDAR特征提取
# 3. 优化器标定
# 4. 结果可视化
# ===============================

set -e  # 遇到错误立即退出

echo "======================================"
echo "  HSR Lidar-Camera Calibration"
echo "  Complete Pipeline"
echo "======================================"
echo ""

# ===============================
# Step 1: SAM分割和2D线提取
# ===============================
echo ">>> Step 1/4: SAM Segmentation & 2D Line Extraction"
echo ""

if [ ! -f "run_sam_raw.sh" ]; then
    echo "[Error] run_sam_raw.sh not found"
    exit 1
fi

bash run_sam_raw.sh

echo ""
echo ">>> Step 1 Complete"
echo ""
sleep 2

# ===============================
# Step 2: LiDAR特征提取
# ===============================
echo ">>> Step 2/4: LiDAR Feature Extraction"
echo ""

if [ ! -f "run_lidar_raw.sh" ]; then
    echo "[Error] run_lidar_raw.sh not found"
    exit 1
fi

bash run_lidar_raw.sh

echo ""
echo ">>> Step 2 Complete"
echo ""
sleep 2

# ===============================
# Step 3: 优化器标定
# ===============================
echo ">>> Step 3/4: Optimization"
echo ""

if [ ! -f "run_opti_raw.sh" ]; then
    echo "[Error] run_opti_raw.sh not found"
    exit 1
fi

bash run_opti_raw.sh

echo ""
echo ">>> Step 3 Complete"
echo ""
sleep 2

# ===============================
# Step 4: 结果可视化
# ===============================
echo ">>> Step 4/4: Visualization"
echo ""

if [ ! -f "run_visual_raw.sh" ]; then
    echo "[Error] run_visual_raw.sh not found"
    exit 1
fi

bash run_visual_raw.sh

echo ""
echo ">>> Step 4 Complete"
echo ""

# ===============================
# 完成
# ===============================
echo "======================================"
echo "  Pipeline Complete!"
echo "======================================"
echo ""
echo "All results are saved under the 'result' directory:"
echo "  - SAM outputs: result/sam/*_mask_ids.png, result/sam/*_lines_2d.txt"
echo "  - LiDAR outputs: result/lidar/*_points.txt, result/lidar/*_lines_3d.txt"
echo "  - Optimizer outputs: result/opti/*_calib_result.txt"
echo "  - Visualization: result/opti/visual_*.png"
echo ""
echo "Check the result subdirectories for all output files."
