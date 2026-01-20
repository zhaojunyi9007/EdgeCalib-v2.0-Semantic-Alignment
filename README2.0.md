# 城市轨道交通多源融合在线标定方案

## 1. 方案概述
[cite_start]本方案针对富含铁轨、电缆、杆状物和车辆的城市轨道交通环境设计。方案融合了 **Line-based** 方法对几何线特征的捕捉能力、**EdgeCalib/Calib-Anything** 基于 SAM 的语义鲁棒性，以及 **CalibRefine** 的由粗到精优化策略 [cite: 1]。

---

## 2. 实施步骤详解

### 第一阶段：图像数据处理 (构建混合势场)
[cite_start]**目标**：从图像中提取最有利于标定的特征，并构建用于引导优化的“势场” [cite: 3, 4]。

#### 2.1 语义边缘提取 (基于 EdgeCalib/Calib-Anything)
* [cite_start]**方法**：使用 **Segment Anything Model (SAM)** 进行图像分割 [cite: 6]。
* **具体操作**：
    * 使用 16x16 网格点提示 (Prompt) 输入 SAM 生成全图掩码 (Masks)。
    * [cite_start]通过 Sobel 滤波或非极大值抑制提取掩码边界 [cite: 7]。
* [cite_start]**目的**：SAM 能极好地提取车辆轮廓，且能忽略树冠内部杂乱纹理噪声，只保留树木与天空的清晰边界 [cite: 8]。

#### 2.2 几何线特征提取 (基于 Line-based)
* [cite_start]**方法**：使用 **LSD (Line Segment Detector)** 算法 [cite: 10]。
* [cite_start]**具体操作**：将图像转为灰度图并检测直线段 [cite: 11]。
* [cite_start]**目的**：针对铁轨和架空电缆。SAM 可能忽略这些细小物体，但 LSD 能精准捕捉这些贯穿画面的长直线强几何约束 [cite: 12]。

#### 2.3 构建边缘吸引场 (Edge Attraction Field)
* [cite_start]**方法**：距离变换 (Distance Transform) [cite: 14]。
* **具体操作**：
    1.  合并 SAM 提取的边缘和 LSD 提取的直线。
    2.  [cite_start]对二值化边缘图应用距离变换，生成灰度梯度图（势场）。像素值表示该点到最近边缘的欧氏距离 [cite: 15]。
* [cite_start]**作用**：形成平滑梯度场，使优化算法可通过梯度下降找到最佳位置 [cite: 16]。

### 第二阶段：点云数据处理 (增密与特征筛选)
[cite_start]**目标**：解决细小物体（电缆/杆）点云稀疏问题，并提取对应边缘 [cite: 18]。

#### 2.1 多帧融合增密 (基于 Line-based)
* [cite_start]**方法**：**NDT (正态分布变换) 局部建图** [cite: 20]。
* [cite_start]**具体操作**：将当前帧与前 2-3 帧点云进行配准融合（Three-in-one），转换至同一坐标系 [cite: 21]。
* [cite_start]**目的**：显著增加电线杆和电缆的点云密度，形成连续线条结构以便匹配 [cite: 22]。

#### 2.2 边缘特征提取
* [cite_start]**方法**：深度不连续性 (Depth Discontinuity) 检测 [cite: 24]。
* [cite_start]**具体操作**：将点云投影为深度图，计算邻域深度差，若跳变超过阈值（如 0.3m）则标记为边缘 [cite: 25]。
* [cite_start]**属性增强**：计算点的法向量和反射强度（铁轨高反射率可作为辅助过滤）[cite: 26]。

#### 2.3 多帧加权过滤 (基于 EdgeCalib)
* [cite_start]**方法**：时空一致性加权 [cite: 28]。
* [cite_start]**具体操作**：计算点云特征在连续帧中的**位置一致性**和投影到图像势场后的**投影一致性** [cite: 29]。
* [cite_start]**目的**：给静态物体（铁轨、路灯）分配高权重，给动态物体（移动电车）分配低权重，防止干扰 [cite: 30]。

### 第三阶段：迭代优化 (由粗到精)
[cite_start]**目标**：求解最佳旋转矩阵 $R$ 和平移向量 $t$ [cite: 32]。

#### 3.1 粗标定 (Coarse Calibration)
* [cite_start]**方法**：网格搜索 / 暴力搜索 (Brute Force Search) [cite: 34]。
* **设置**：
    * 使用较宽的图像边缘（高斯模糊扩大影响范围）。
    * [cite_start]仅在旋转角度 (Roll, Pitch, Yaw) 上进行大步长（0.5°-1°）搜索 [cite: 37]。
* [cite_start]**目标函数**：最大化点云边缘投影到图像边缘吸引场上的总得分 [cite: 38]。
* [cite_start]**目的**：快速确定大致方向，防止陷入局部最优 [cite: 39]。

#### 3.2 精细优化 (Fine Optimization)
* [cite_start]**方法**：**Levenberg-Marquardt (LM)** 非线性优化 [cite: 41]。
* **具体操作**：以粗标定结果为初值，构建最小化重投影误差的优化问题。
* [cite_start]**Loss 函数设计** [cite: 43]：
    $$Loss = W_{edge} \cdot E_{dist} + W_{attr} \cdot E_{consistency}$$
    * [cite_start]**$E_{dist}$ (几何误差)**：点云边缘点投影到图像势场后的距离值 [cite: 44]。
    * [cite_start]**$E_{consistency}$ (属性误差)**：投影到 SAM 生成的同一 Mask 内的点云，其强度方差和法向量一致性应最小 [cite: 45]。

#### 3.3 结果验证与平滑 (基于 SE-Calib)
* [cite_start]**方法**：置信度检查 (CCuP) [cite: 48]。
* [cite_start]**具体操作**：检查时间序列上的平滑性。若参数突变不满足时空一致性，则沿用上一帧参数 [cite: 49]。

---

## 3. 方案总结
针对城市道路、铁轨、电缆等复杂场景，本方案优势如下：

1.  [cite_start]**抓住强特征**：利用 Line-based 方法强行锁定了场景中最稳定的铁轨和电缆特征 [cite: 52]。
2.  **利用大模型**：利用 SAM (EdgeCalib) 解决了树木纹理干扰和车辆轮廓提取的问题 [cite: 53]。
3.  **零训练**：整个流程不需要针对该场景重新训练神经网络，即插即用 [cite: 54]。