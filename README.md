# EdgeCalib v2.0

基于HSR场景的LiDAR-Camera外参标定系统，采用两阶段标定方案（Coarse + Fine）。

## 项目概述

本项目实现了一个鲁棒的LiDAR-相机外参标定系统，特别适用于高速铁路（HSR）等结构化场景。系统结合了语义分割（SAM）和几何特征（点云、线特征）进行标定。

### 主要特点

- **两阶段标定**：
  - **Coarse阶段**：基于点云-SAM mask的CalibScore优化
  - **Fine阶段**：基于3D-2D线特征匹配的Ceres优化
- **多模态特征**：结合点云法向量、3D线特征（铁轨/立柱）和2D线特征
- **鲁棒性强**：使用Huber损失函数，适应复杂场景

## 系统要求

### C++ 依赖
- CMake >= 3.10
- C++14 或更高
- PCL (Point Cloud Library)
- OpenCV >= 4.0
- Eigen3
- Ceres Solver

### Python 依赖
- Python >= 3.7
- 详见 `requirements.txt`

## 安装步骤

### 1. 安装C++依赖

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    cmake build-essential \
    libpcl-dev \
    libopencv-dev \
    libeigen3-dev \
    libceres-dev
```

**Windows:**
- 使用vcpkg或手动安装上述库

### 2. 安装Python依赖

```bash
# 创建虚拟环境（推荐）
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate     # Windows

# 安装依赖
pip install -r requirements.txt

# 安装 Segment Anything Model (SAM)
pip install git+https://github.com/facebookresearch/segment-anything.git
```

### 3. 下载SAM模型权重

```bash
mkdir -p checkpoints
cd checkpoints
wget https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth
cd ..
```

### 4. 编译C++程序

```bash
mkdir -p build
cd build
cmake ..
make -j4
cd ..
```

编译成功后，会在 `build/` 目录下生成两个可执行文件：
- `lidar_extractor`: 提取LiDAR特征（点+3D线）
- `optimizer`: 标定优化器

## 使用方法

### 完整流程

假设你有KITTI格式的数据：
```
data/
├── velodyne_points/data/  # LiDAR点云 (.bin)
└── image_02/data/         # 相机图像 (.png/.jpg)
```

#### 步骤1: 提取LiDAR特征

```bash
./run_lidar_raw.sh
```

该脚本会：
- 遍历所有 `.bin` 点云文件
- 提取点特征（带法向量）
- 提取3D线特征（铁轨和立柱）
- 输出到 `data/features/`

输出文件：
- `XXXXXX_points.txt`: 点特征 (x y z intensity nx ny nz)
- `XXXXXX_lines_3d.txt`: 3D线特征 (x1 y1 z1 x2 y2 z2 type)

#### 步骤2: 提取图像特征

```bash
./run_sam_raw.sh
```

该脚本会：
- 使用SAM进行语义分割
- 生成mask ID图
- 提取2D线特征

输出文件：
- `XXXXXX_mask_ids.png`: mask ID图（用于Coarse）
- `XXXXXX_lines_2d.txt`: 2D线特征 (u1 v1 u2 v2 type)
- `XXXXXX_edge_map.png`: 边缘图（调试用）

#### 步骤3: 运行标定优化

```bash
./run_opti_raw.sh
```

该脚本会：
1. **Coarse阶段**：随机搜索1000次，找到最佳初始外参
2. **Fine阶段**：使用Ceres进行精细优化

输出文件：
- `XXXXXX_calib_result.txt`: 标定结果

#### 步骤4: 可视化结果

```bash
python visual_result.py \
    --img data/image_02/data/000000.png \
    --feature_base data/features/000000 \
    --r_vec 0.01 0.02 0.03 \
    --t_vec 0.1 -0.3 1.8 \
    --output visual_result.png
```

或者读取优化结果：
```bash
# 假设标定结果在 data/features/000000_calib_result.txt
python visual_result.py \
    --img data/image_02/data/000000.png \
    --feature_base data/features/000000 \
    --r_vec $(sed -n '3p' data/features/000000_calib_result.txt) \
    --t_vec $(sed -n '5p' data/features/000000_calib_result.txt) \
    --output visual_result.png
```

## 文件结构

```
EdgeCalib v2.0/
├── CMakeLists.txt           # CMake构建配置
├── requirements.txt         # Python依赖
├── README.md               # 本文件
├── include/
│   └── common.h            # 数据结构定义
├── cpp/
│   ├── io_utils.cpp        # 文件I/O工具
│   ├── lidar_extractor.cpp # LiDAR特征提取
│   └── optimizer.cpp       # 标定优化器
├── python/
│   ├── sam_extractor.py    # SAM特征提取
│   └── run_sam.py          # SAM运行脚本
├── run_lidar_raw.sh        # LiDAR特征提取脚本
├── run_sam_raw.sh          # 图像特征提取脚本
├── run_opti_raw.sh         # 标定优化脚本
└── visual_result.py        # 结果可视化
```

## 代码修复记录

本版本（v2.0）修复了以下问题：

### 1. 数据结构一致性
- ✅ 统一所有模块使用 `common.h` 中定义的数据结构
- ✅ 删除重复的结构定义
- ✅ 添加构造函数，提升代码可读性

### 2. 接口一致性
- ✅ 修复 `optimizer.cpp` 的命令行参数接口（从4个参数改为8个）
- ✅ 修复 `run_opti_raw.sh` 的参数传递方式
- ✅ 统一 Python 类名为 `FeatureExtractor`

### 3. 功能完整性
- ✅ 补全 `sam_extractor.py` 的 `process_image()` 方法
- ✅ 实现 `extract_mask_ids()` 生成mask ID图
- ✅ 实现 `extract_lines_2d()` 提取2D线特征

### 4. 错误处理
- ✅ 所有文件I/O操作添加错误检查
- ✅ 添加数据有效性检查（NaN、Inf等）
- ✅ 添加除零保护
- ✅ 完善日志输出

### 5. 工程质量
- ✅ 修复 `CMakeLists.txt` 的include路径配置
- ✅ 添加 `requirements.txt` 管理Python依赖
- ✅ 增强 `visual_result.py` 的可视化效果
- ✅ 添加详细的README文档

### 6. 安全性
- ✅ 修复内存读取越界风险
- ✅ 添加线段长度合理性检查
- ✅ 添加投影范围检查

## 参数说明

### LiDAR特征提取参数

在 `lidar_extractor.cpp` 中可调整：
- **降采样体素大小**：`0.3m`（第81行）
- **法向量邻域**：`K=20`（第87行）
- **地面区域z范围**：`[-3.0, -1.2]m`（第105行）
- **铁轨提取阈值**：`0.15m`（第112行）
- **立柱垂直度容差**：`0.2 rad (~11°)`（第169行）

### 标定优化参数

在 `optimizer.cpp` 中可调整：
- **Coarse搜索次数**：`1000`（第224行）
- **角度搜索范围**：`±0.1 rad (~5.7°)`（第218行）
- **位置搜索范围**：`±0.5m`（第219行）
- **线匹配阈值**：`50 pixels`（第157行）
- **Huber损失阈值**：`5.0`（第280行）

## 常见问题

### Q1: 编译时找不到 `common.h`
**A:** 确保CMakeLists.txt中正确设置了include路径：
```cmake
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
```

### Q2: Python导入 segment_anything 失败
**A:** 确保已安装SAM：
```bash
pip install git+https://github.com/facebookresearch/segment-anything.git
```

### Q3: 优化结果不理想
**A:** 可能原因：
1. 初始外参偏差过大，调整 `run_opti_raw.sh` 中的初始值
2. 场景特征不明显，尝试选择特征更丰富的帧
3. 3D/2D线特征匹配错误，检查 `_lines_3d.txt` 和 `_lines_2d.txt`

### Q4: 找不到3D线特征
**A:** 调整 `lidar_extractor.cpp` 中的滤波参数：
- 地面区域z范围（第105行）
- RANSAC阈值（第112、169行）

## 许可证

本项目为研究/教学用途。使用前请确保遵守相关依赖库的许可证。

## 致谢

- [Segment Anything (SAM)](https://github.com/facebookresearch/segment-anything) - Meta AI
- [Ceres Solver](http://ceres-solver.org/) - Google
- [Point Cloud Library (PCL)](https://pointclouds.org/)

## 引用

如果本项目对你的研究有帮助，请引用：
```bibtex
@misc{edgecalib2024,
  title={EdgeCalib v2.0: Robust LiDAR-Camera Calibration for HSR Scenes},
  author={Your Name},
  year={2024}
}
```

## 联系方式

如有问题或建议，请提交Issue或Pull Request。
