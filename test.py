import cv2, numpy as np


m = cv2.imread("result/sam/0000000000_mask_ids.png", -1)
print(m.dtype, m.min(), m.max())
