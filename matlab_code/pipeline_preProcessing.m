%% Image pre-processing script in MATLAB

% clc; clear; close all;

% Load image
img = imread('Noah_01_02_01.jpg');
grayImg = rgb2gray(img);
grayImg = medfilt2(grayImg); % median filter to reduce errors (3 by 3)

%% 2. Edge-detection with Canny's algorithm
% Apply the Canny operator to obtain the binary edge map
edgeMap = edge(grayImg, 'Canny');

% Debug
% figure;
% imshow(edgeMap);
% title('Edge Map (Canny)');

% Dilation
edgeMap = imdilate(edgeMap, strel('line',3,0)) | imdilate(edgeMap, strel('line',3,90));

% Debug
% figure;
% imshow(edgeMap);
% title('After imdilate');
% 
% % After dilation
% edgeMap = imclose(edgeMap, strel('disk', 1));
% % edgeMap = bwmorph(edgeMap, 'bridge');
% edgeMap = bwmorph(edgeMap, 'clean');
% 
% edgeMap = bwmorph(edgeMap, 'thicken');
% 
% figure;
% imshow(edgeMap);
% title('Clean + Thicken');
% 
% edgeMap = bwmorph(edgeMap, 'spur');
% 
% figure;
% imshow(edgeMap);
% title('+ Spur');

edgeMap = imfill(edgeMap, 4, 'holes');

% Visualization
% figure;
% imshow(edgeMap);
% title('After Morphological Smoothing');

% Extract the perimeter of the grid
edgeMap = bwmorph(edgeMap, 'remove');

% figure;
% imshow(edgeMap);
% title('After remove');

% Increase line size preparing for Hough transformation
edgeMap = imdilate(edgeMap, strel("square", 3));

% Debug
% figure;
% imshow(edgeMap);
% title('After imdilate');

%% 3. Application of the Hough Transform for Line Detection
% Compute the Hough Transform
[H, theta, rho] = hough(edgeMap);

% Identify the peaks in the Hough transform (number and threshold can be adjusted)
peaks = houghpeaks(H, 4);

% Extract the detected lines based on the found peaks
lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 40);

%% 4. Visualization of the Results
figure;
imshow(img);
hold on;
for k = 1:length(lines)
    xy = [lines(k).point1; lines(k).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
    % Display the starting and ending points of the lines
    plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
    plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end

title('Lines detected with the Hough Transform');
hold off;

%% Identify intersection points between detected segments

num_lines = 4;

% List of x coordinates of intersection points
point_intersec_x = [];
% List of y coordinates of intersection points
point_intersec_y = [];

for i = 1:num_lines
    % First line
    line1_p1 = lines(i).point1;
    line1_p2 = lines(i).point2;

    % Check all intersections between line1 and the other lines
    for j = i+1:num_lines

        if j ~= i 
            % Second line
            line2_p1 = lines(j).point1;
            line2_p2 = lines(j).point2;
    
            [intersec_X, intersec_Y] = intersectLines(line1_p1(1), line1_p1(2), line1_p2(1), line1_p2(2), line2_p1(1), line2_p1(2), line2_p2(1), line2_p2(2));
    
            if not(isnan(intersec_X) || isnan(intersec_Y))
                point_intersec_x = [point_intersec_x, intersec_X];
                point_intersec_y = [point_intersec_y, intersec_Y];
            end
        end

    end
end

figure;
imshow(img);
hold on;
title('Grid Intersection Points');

% Draw the points on the image
plot(point_intersec_x, point_intersec_y, 'ro', 'MarkerSize', 5, 'MarkerFaceColor', 'r');

hold off;

grid_points= [point_intersec_x(:),point_intersec_y(:);];

% % Otsu's method for binarization
% thresh = graythresh(grayImg);
% bwImg = imbinarize(grayImg, thresh);
% 
% % % Recognition of horizontal and vertical lines
% % hLines = imopen(~bwImg, strel('line', 30, 0));
% % vLines = imopen(~bwImg, strel('line', 30, 90));
% % smallerHLines = imopen(~bwImg, strel('line', 10, 0));
% % smallerVLines = imopen(~bwImg, strel('line', 10, 90));
% % %Plot visualization
% % gridMask = hLines | vLines | smallerHLines | smallerVLines;
% 
% % Extract data by removing grid
% figure, imshow(gridMask);
% title('Grid mask');
% 
% 
% % % Dilatation of smaller points
% bwImg = imdilate(bwImg,strel("square",1));
% 
% bwImg = bwmorph(bwImg,'bridge',Inf);

% 
% figure, imshow(bwImg);
% title('Binary image');
% 
% dataOnly = bwImg & ~gridMask;

function [xI, yI] = intersectLines(x1,y1,x2,y2,x3,y3,x4,y4)
% Computes the intersection point (xI, yI) of two lines defined by
% the points (x1,y1)-(x2,y2) and (x3,y3)-(x4,y4).
% If the lines are parallel (i.e., they have no intersection), 
% the function returns NaN values.
% parameters: 

    % Compute coefficients for the implicit line equation Ax + By = C
    % Line 1 passing through (x1, y1) and (x2, y2)
    A1 = y2 - y1;    % Change in y
    B1 = x1 - x2;    % Negative change in x
    C1 = A1*x1 + B1*y1;  % Compute C1 based on one point of the line

    % Line 2 passing through (x3, y3) and (x4, y4)
    A2 = y4 - y3;    % Change in y for second line
    B2 = x3 - x4;    % Negative change in x for second line
    C2 = A2*x3 + B2*y3;  % Compute C2 based on one point of the line

    % Compute the determinant of the coefficient matrix
    det = A1*B2 - A2*B1;

    if abs(det) < 1e-9  % Check if determinant is close to zero (parallel lines)
        % The lines are parallel (or nearly parallel), no intersection
        xI = NaN; 
        yI = NaN;
        return
    end

    % Compute the intersection point using Cramer's rule
    xI = (B2*C1 - B1*C2) / det;
    yI = (A1*C2 - A2*C1) / det;
end