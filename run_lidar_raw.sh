#!/bin/bash

# ===============================
# 加载配置文件（如果存在）
# ===============================
if [ -f "config_kitti_raw.sh" ]; then
    source config_kitti_raw.sh
    echo "[Info] Configuration loaded from config_kitti_raw.sh"
fi

# ===============================
# KITTI RAW数据集配置
# ===============================
RAW_DATE="${RAW_DATE:-2011_09_26}"
RAW_DRIVE="${RAW_DRIVE:-2011_09_26_drive_0001_sync}"
DATA_ROOT="${DATA_ROOT:-/gz-data/dataset/${RAW_DATE}/${RAW_DRIVE}}"

# 输入点云目录（KITTI RAW数据集结构）
BIN_DIR="${BIN_DIR:-${DATA_ROOT}/velodyne_points/data}"

# 输出目录（统一保存到result/lidar文件夹）
OUT_DIR="${LIDAR_DIR:-${RESULT_DIR:-result}/lidar}"

# 帧选择（可选，默认沿用SAM配置）
FRAME_START="${LIDAR_FRAME_START:-${SAM_FRAME_START:-}}"
FRAME_END="${LIDAR_FRAME_END:-${SAM_FRAME_END:-}}"

# 编译并行数
MAKE_JOBS="${MAKE_JOBS:-4}"

# ===============================
# 路径检查与创建
# ===============================

# 创建result目录
mkdir -p "$OUT_DIR"
echo "[Info] Output directory: $OUT_DIR"

# 检查点云目录是否存在
if [ ! -d "$BIN_DIR" ]; then
    echo "[Error] Velodyne point cloud directory not found: $BIN_DIR"
    echo "Please check the KITTI dataset path."
    exit 1
fi

# 检查是否有.bin文件
bin_count=$(ls -1 "$BIN_DIR"/*.bin 2>/dev/null | wc -l)
if [ $bin_count -eq 0 ]; then
    echo "[Error] No .bin files found in $BIN_DIR"
    exit 1
fi

echo "[Info] Found $bin_count point cloud files"

# ===============================
# 编译C++代码
# ===============================
echo "=== Compiling Lidar Extractor ==="
mkdir -p build
cd build
cmake .. || { echo "[Error] CMake failed"; exit 1; }
make -j${MAKE_JOBS} || { echo "[Error] Make failed"; exit 1; }
cd ..

if [ ! -f "./build/lidar_extractor" ]; then
    echo "[Error] lidar_extractor executable not found after compilation"
    exit 1
fi

echo "[Success] Compilation done."
echo ""

# ===============================
# 运行LiDAR特征提取
# ===============================
echo "=== Running Lidar Feature Extraction ==="
echo "Dataset: ${RAW_DRIVE}"
echo "Point Cloud Directory: $BIN_DIR"
echo "Output Directory: $OUT_DIR"
if [ -n "$FRAME_START" ] || [ -n "$FRAME_END" ]; then
    echo "Frame Range: ${FRAME_START:-start} ~ ${FRAME_END:-end}"
fi
echo ""

processed_count=0
failed_count=0
selected_count=0

# 收集并筛选 bin 文件
mapfile -t bin_files < <(ls -1 "$BIN_DIR"/*.bin 2>/dev/null | sort)

start_num=""
end_num=""
if [ -n "$FRAME_START" ]; then
    start_num=$((10#$FRAME_START))
fi
if [ -n "$FRAME_END" ]; then
    end_num=$((10#$FRAME_END))
fi

# 遍历所有 bin 文件
for bin_file in "${bin_files[@]}"; do
    # 提取文件名 (不带扩展名)，例如 0000000000
    filename=$(basename "$bin_file" .bin)
        if ! [[ "$filename" =~ ^[0-9]+$ ]]; then
        continue
    fi
    frame_num=$((10#$filename))
    if [ -n "$start_num" ] && [ "$frame_num" -lt "$start_num" ]; then
        continue
    fi
    if [ -n "$end_num" ] && [ "$frame_num" -gt "$end_num" ]; then
        continue
    fi
    ((selected_count++))
    
    # 构造输出的基础路径 (例如 result/0000000000)
    # C++ 程序会自动生成 0000000000_points.txt 和 0000000000_lines_3d.txt
    output_base="$OUT_DIR/$filename"
    
    echo "Processing $filename ..."
    
    if ./build/lidar_extractor "$bin_file" "$output_base"; then
        ((processed_count++))
    else
        echo "[Warning] Failed to process $filename"
        ((failed_count++))
    fi
done

if [ $selected_count -eq 0 ]; then
    echo ""
    echo "[Warning] No frames selected for processing."
    echo "Please check LIDAR_FRAME_START/LIDAR_FRAME_END (or SAM_FRAME_START/SAM_FRAME_END)."
    exit 1
fi

echo ""
echo "=== Lidar Extraction Complete ==="
echo "Processed: $processed_count files"
echo "Failed: $failed_count files"
echo "Results saved to: $OUT_DIR"