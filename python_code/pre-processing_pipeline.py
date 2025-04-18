import cv2
import numpy as np
import matplotlib.pyplot as plt

def intersect_lines(line1, line2):
    x1, y1, x2, y2 = line1
    x3, y3, x4, y4 = line2

    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if den == 0:
        return (np.nan, np.nan)

    t_num = (x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)
    u_num = (x1 - x3) * (y1 - y2) - (y1 - y3) * (x1 - x2)

    t = t_num / den
    u = -u_num / den

    x = x1 + t * (x2 - x1)
    y = y1 + t * (y2 - y1)
    return (x, y)

# 1. Image preprocessing
img = cv2.imread('Noah_01_01_01.jpg')
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
gray = cv2.medianBlur(gray, 3)

# 2. Edge detection and morphological operations
med_val = np.median(gray)
lower = int(max(0, 0.7 * med_val))
upper = int(min(255, 1.3 * med_val))
edges = cv2.Canny(gray, lower, upper)

# Dilation with horizontal/vertical lines
kernel_h = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 1))
kernel_v = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 3))
dilated = cv2.bitwise_or(cv2.dilate(edges, kernel_h), 
                         cv2.dilate(edges, kernel_v))

# Plot the image for debugging
plt.imshow(dilated, cmap='gray')
plt.title('Dilated Image')
plt.show()




# Fill holes
h, w = dilated.shape
mask = np.zeros((h+2, w+2), np.uint8)
flood_filled = dilated.copy()
cv2.floodFill(flood_filled, mask, (0, 0), 255)
filled = cv2.bitwise_or(dilated, cv2.bitwise_not(flood_filled))

# Extract perimeter
kernel = np.ones((3, 3), np.uint8)
eroded = cv2.erode(filled, kernel)
perimeter = cv2.subtract(filled, eroded)

# Final dilation
edgeMap = cv2.dilate(perimeter, kernel)

# Plot the image for debugging
plt.figure()
plt.imshow(edgeMap, cmap='gray')
plt.title('Edge map Image')
plt.show()

# 3. Hough Transform
lines = cv2.HoughLinesP(edgeMap, 1, np.pi/180, threshold=100,
                        minLineLength=150, maxLineGap=40)

if lines is None:
    raise ValueError("No lines detected")

lines = lines[:, 0, :].tolist()
lines.sort(key=lambda line: np.linalg.norm(np.array(line[2:]) - np.array(line[:2])),reverse=True)
hough_lines = lines[:4]
# Plot the hough lines for debugging
plt.figure()
plt.imshow(edgeMap, cmap='gray')
plt.title('Hough Lines')
for line in hough_lines:
    x1, y1, x2, y2 = line
    plt.plot([x1, x2], [y1, y2], 'r-')
plt.xlim(0, edgeMap.shape[1])
plt.ylim(edgeMap.shape[0], 0)
plt.show()



# 4. Find intersections
points = []
for i in range(len(hough_lines)):
    for j in range(i+1, len(hough_lines)):
        x, y = intersect_lines(hough_lines[i], hough_lines[j])
        if not (np.isnan(x) or np.isnan(y)):
            points.append((x, y))

points = np.array(points)

if len(points) < 4:
    raise ValueError("Not enough intersection points found")

# 5. Sort points
points = points[points[:, 1].argsort()]
top_points = points[:2][points[:2, 0].argsort()]
bottom_points = points[2:4][points[2:4, 0].argsort()]

grid_points = np.array([
    top_points[0],    # Top-left
    top_points[1],    # Top-right
    bottom_points[0], # Bottom-left
    bottom_points[1]  # Bottom-right
], dtype=np.int32)
