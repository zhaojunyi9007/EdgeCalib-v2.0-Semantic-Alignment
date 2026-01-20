#!/bin/bash
# EdgeCalib v2.0 快速示例脚本
# 使用Python主控程序运行完整流程

echo "=========================================="
echo "EdgeCalib v2.0 - 快速示例"
echo "=========================================="
echo ""

# 检查配置文件
if [ ! -f "config.yaml" ]; then
    echo "[Error] 配置文件 config.yaml 不存在！"
    exit 1
fi

# 检查build目录
if [ ! -d "build" ]; then
    echo "[Error] build 目录不存在，请先编译 C++ 程序："
    echo "  mkdir -p build && cd build && cmake .. && make && cd .."
    exit 1
fi

# 检查可执行文件
if [ ! -f "build/lidar_extractor" ] || [ ! -f "build/optimizer" ]; then
    echo "[Error] C++ 程序未编译，请运行："
    echo "  cd build && make && cd .."
    exit 1
fi

echo "[提示] 请确保已修改 config.yaml 中的数据路径和要处理的帧ID"
echo ""
read -p "是否继续运行完整流程？(y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 0
fi

echo ""
echo "=========================================="
echo "开始执行完整标定流程..."
echo "=========================================="
echo ""

# 运行主程序
python run_pipeline.py --config config.yaml

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ 流程执行成功!"
    echo "=========================================="
    echo "结果保存在 result/ 目录下："
    echo "  - result/sam_features/      : SAM特征"
    echo "  - result/lidar_features/    : LiDAR特征"
    echo "  - result/calibration/       : 标定结果"
    echo "  - result/visualization/     : 可视化结果"
else
    echo ""
    echo "=========================================="
    echo "❌ 流程执行失败，请检查错误信息"
    echo "=========================================="
    exit 1
fi
