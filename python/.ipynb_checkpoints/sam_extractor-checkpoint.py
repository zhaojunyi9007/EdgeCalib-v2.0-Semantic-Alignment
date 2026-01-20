import numpy as np
import cv2
import torch
import os
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

class FeatureExtractor:
    """
    统一的特征提取器：使用SAM进行分割，提取mask、2D线特征等
    """
    def __init__(self, checkpoint_path, model_type="vit_h", device=None):
        # 加载 SAM 模型
        if device is None:
            self.device = "cuda" if torch.cuda.is_available() else "cpu"
        else:
            self.device = device

        print(f"[SAM] Initializing model ({model_type}) on {self.device}...")
        
        # 检查checkpoint文件是否存在
        if not os.path.exists(checkpoint_path):
            raise FileNotFoundError(f"Checkpoint not found: {checkpoint_path}")
        
        # 加载SAM模型
        sam = sam_model_registry[model_type](checkpoint=checkpoint_path)
        sam.to(device=self.device)
        
        # 设置 16x16 的网格提示生成掩码
        self.mask_generator = SamAutomaticMaskGenerator(
            sam, 
            points_per_side=16,
            pred_iou_thresh=0.86,
            stability_score_thresh=0.92,
            crop_n_layers=1,
            crop_n_points_downscale_factor=2,
        )
        
        print(f"[SAM] Model loaded successfully")

    def extract_edges(self, image):
        """
        提取边缘，返回二值边缘图和权重图
        """
        # 1. 生成原始掩码
        print("[SAM] Generating masks...")
        masks = self.mask_generator.generate(image)
        print(f"[SAM] Generated {len(masks)} masks")
        
        # 2. 初始化最终边缘图
        h, w = image.shape[:2]
        final_edge_map = np.zeros((h, w), dtype=np.uint8)
        # 引入注意力权重图，记录每个边缘点的质量
        weight_map = np.zeros((h, w), dtype=np.float32)
        
        # 3. 循环处理每个mask
        for mask in masks:
            # 提取掩码元数据
            m_bool = mask['segmentation']
            stability = mask['stability_score'] # SAM 的边缘稳定性得分
            bbox = mask['bbox'] # [x, y, w, h]
        
            # 几何过滤逻辑 (空旷场景优先保留长条形结构如护栏、轨道)
            bw, bh = bbox[2], bbox[3]
            aspect_ratio = max(bw, bh) / (min(bw, bh) + 1e-6)
            # 长宽比较大的 mask 通常代表道路边界或护栏
            is_structural = aspect_ratio > 3.0 

            m = m_bool.astype(np.uint8)
            if not m.flags['C_CONTIGUOUS']:
                m = np.ascontiguousarray(m)

            # 提取物体轮廓
            contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            for cnt in contours:
                # 绘制当前轮廓的临时掩码
                edge_mask = np.zeros((h, w), dtype=np.uint8)
                cv2.drawContours(edge_mask, [cnt], -1, 255, 1)
            
                # 使用 mask 提取原图像素计算标准差(自适应滤波)
                pixels = image[edge_mask == 255]
            
                if len(pixels) == 0: 
                    continue

                # 仅保留高置信度的边界
                if np.std(pixels) > 10:
                    # 计算注意力权重：稳定性 * 几何先验加权
                    # 如果是结构化长边缘，赋予更高的注意力权重
                    weight = stability * (1.5 if is_structural else 1.0)
                    
                    cv2.drawContours(final_edge_map, [cnt], -1, 255, 1)
                    # 将权重绘制到权重图中，供后续优化器使用
                    cv2.drawContours(weight_map, [cnt], -1, float(weight), 1)
        
        return final_edge_map, weight_map

    def get_distance_transform(self, edge_map):
        """
        计算距离变换，使用固定尺度而非自适应归一化
        这样可以保证多帧之间的残差尺度一致
        """
        print("[SAM] Computing Distance Transform...")
        # dist_map 的每个像素值代表该点到最近边缘的距离（单位：像素）
        # 输入要求：边缘是白色(255)，背景是黑色(0) -> 需要反转一下给 distanceTransform
        # distanceTransform 计算的是"到零像素的距离"，所以我们要把边缘变成0
        dist_map = cv2.distanceTransform(255 - edge_map, cv2.DIST_L2, 5)
        
        # 使用固定的最大距离进行归一化（单位：像素）
        # KITTI图像尺寸约 1242x375，选择200像素作为最大有效距离
        # 这样可以保证不同帧之间的残差尺度一致
        FIXED_MAX_DIST = 200.0  # 像素
        dist_map = np.clip(dist_map, 0, FIXED_MAX_DIST) / FIXED_MAX_DIST
        
        actual_max = np.max(dist_map * FIXED_MAX_DIST)
        print(f"[SAM] Distance map normalized with fixed scale")
        print(f"      Fixed max: {FIXED_MAX_DIST}px, Actual max: {actual_max:.2f}px, Range: [0, 1]")
        return dist_map

    def extract_distance_map(self, image_rgb):
        """
        返回距离场和与之对应的权重图
        """
        # 1. 提取边缘
        edge_map, weight_map = self.extract_edges(image_rgb)
        dist_map = self.get_distance_transform(edge_map)
        
        # 将权重图平滑处理，扩展注意力影响范围
        weight_map = cv2.GaussianBlur(weight_map, (5, 5), 0)
        
        return dist_map, weight_map

    def extract_mask_ids(self, image):
        """
        生成mask ID图，每个mask分配唯一ID
        用于Coarse阶段的CalibScore计算
        """
        print("[SAM] Generating mask IDs...")
        masks = self.mask_generator.generate(image)
        
        h, w = image.shape[:2]
        mask_ids = np.zeros((h, w), dtype=np.uint16)
        
        # 按面积排序，大的mask先绘制（防止小mask被覆盖）
        masks_sorted = sorted(masks, key=lambda x: x['area'], reverse=True)
        
        for idx, mask in enumerate(masks_sorted):
            mask_id = idx + 1  # ID从1开始，0表示背景
            m = mask['segmentation'].astype(np.uint8)
            mask_ids[m > 0] = mask_id
        
        print(f"[SAM] Created mask ID map with {len(masks_sorted)} masks")
        return mask_ids

    def extract_lines_2d(self, image, edge_map=None):
        """
        使用LSD (Line Segment Detector) 提取2D线特征
        返回格式: [(u1, v1, u2, v2, type), ...]
        type: 0=Horizontal, 1=Vertical
        """
        print("[SAM] Extracting 2D line features...")
        
        # 如果没有提供edge_map，先提取边缘
        if edge_map is None:
            edge_map, _ = self.extract_edges(image)
        
        # 使用OpenCV的LSD检测器
        lsd = cv2.createLineSegmentDetector(0)
        lines, _, _, _ = lsd.detect(edge_map)
        
        if lines is None:
            print("[SAM] No lines detected")
            return []
        
        # 过滤和分类线段
        lines_2d = []
        min_length = 20  # 最小线段长度（像素）
        
        for line in lines:
            x1, y1, x2, y2 = line[0]
            
            # 计算线段长度
            length = np.sqrt((x2 - x1)**2 + (y2 - y1)**2)
            if length < min_length:
                continue
            
            # 计算线段方向，判断水平/垂直
            dx = abs(x2 - x1)
            dy = abs(y2 - y1)
            
            # 判断类型：dy/dx > 2 为垂直，dx/dy > 2 为水平
            if dy > dx * 2:
                line_type = 1  # Vertical
            elif dx > dy * 2:
                line_type = 0  # Horizontal
            else:
                continue  # 跳过斜线
            
            lines_2d.append((x1, y1, x2, y2, line_type))
        
        print(f"[SAM] Extracted {len(lines_2d)} 2D line features")
        return lines_2d

    def process_image(self, image_path, output_dir):
        """
        处理单张图像，生成所有必要的特征文件
        生成文件：
        - xxx_mask_ids.png: mask ID图 (用于Coarse)
        - xxx_lines_2d.txt: 2D线特征 (用于Fine)
        - xxx_edge_map.png: 边缘图 (可选，用于调试)
        """
        print(f"\n[Processing] {image_path}")
        
        # 读取图像
        image = cv2.imread(image_path)
        if image is None:
            print(f"[Error] Cannot read image: {image_path}")
            return False
        
        # 提取文件名（不含扩展名）
        filename = os.path.splitext(os.path.basename(image_path))[0]
        output_base = os.path.join(output_dir, filename)
        
        # 1. 生成mask ID图
        mask_ids = self.extract_mask_ids(image)
        cv2.imwrite(output_base + "_mask_ids.png", mask_ids)
        print(f"[Saved] {output_base}_mask_ids.png")
        
        # 2. 提取边缘图（用于线段检测）
        edge_map, weight_map = self.extract_edges(image)
        cv2.imwrite(output_base + "_edge_map.png", edge_map)
        print(f"[Saved] {output_base}_edge_map.png")
        
        # 3. 提取2D线特征
        lines_2d = self.extract_lines_2d(image, edge_map)
        with open(output_base + "_lines_2d.txt", 'w') as f:
            f.write("# 2D Line Features: u1 v1 u2 v2 type (0=Horizontal, 1=Vertical)\n")
            for line in lines_2d:
                f.write(f"{line[0]:.2f} {line[1]:.2f} {line[2]:.2f} {line[3]:.2f} {line[4]}\n")
        print(f"[Saved] {output_base}_lines_2d.txt ({len(lines_2d)} lines)")
        
        print(f"[Complete] {filename}")
        return True


# 保持向后兼容性的别名
SAMEdgeExtractor = FeatureExtractor
