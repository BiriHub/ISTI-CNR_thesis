%% Image pre-processing script in MATLAB

clc; clear; close all;

% Load image
img = imread('Noah_01_01_01.jpg');
grayImg = rgb2gray(img);
grayImg = medfilt2(grayImg); % median filter to reduce errors (3 by 3)

% Edge-detection with Canny's algorithm + Morphologycal operations

% Apply the Canny operator to obtain the binary edge map
bin_img = edge(grayImg, 'Canny');

% Preparing the image before applying th Hough transformation to identify
% an approxymation of grid corners

% Dilation
edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img, strel('line',3,90));

edgeMap = imfill(edgeMap, 4, 'holes');

% Extract the perimeter of the grid
edgeMap = bwmorph(edgeMap, 'remove');

% Increase line size preparing for Hough transformation
edgeMap = imdilate(edgeMap, strel("square", 3));

% Compute the Hough Transform to extract an approssimation of the grid
% points
[H, theta, rho] = hough(edgeMap);

% Identify the peaks in the Hough transform (number and threshold can be adjusted)
peaks = houghpeaks(H, 4);

% Extract the detected lines based on the found peaks
lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 40,'MinLength',150);

% DEBUG
% figure;
% imshow(img);
% hold on;
% for k = 1:length(lines)
%     xy = [lines(k).point1; lines(k).point2];
%     plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
%     % Display the starting and ending points of the lines
%     plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
%     plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
% end
% 
% title('Lines detected with the Hough Transform');
% hold off;

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

% Combine coordinates in a new matrix 
points = [point_intersec_x(:) point_intersec_y(:)];

% Sort rows in an ascending order on coordinate Y
points_sorted = sortrows(points, 2);  

% Separate the points in two different groups based on their location on
% the image
top_points = points_sorted(1:2, :);
bottom_points = points_sorted(3:4, :);

% Tra i top_points, il punto con x minore è top-left, con x maggiore è top-right
if top_points(1,1) < top_points(2,1)
    top_left = top_points(1,:);
    top_right = top_points(2,:);
else
    top_left = top_points(2,:);
    top_right = top_points(1,:);
end

% Tra i bottom_points, il punto con x minore è bottom-left, con x maggiore è bottom-right
if bottom_points(1,1) < bottom_points(2,1)
    bottom_left = bottom_points(1,:);
    bottom_right = bottom_points(2,:);
else
    bottom_left = bottom_points(2,:);
    bottom_right = bottom_points(1,:);
end

%DEBUG
figure;
imshow(img);
hold on;
plot(top_left(1), top_left(2), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
plot(top_right(1), top_right(2), 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot(bottom_left(1), bottom_left(2), 'co', 'MarkerSize', 10, 'LineWidth', 2);
plot(bottom_right(1), bottom_right(2), 'mo', 'MarkerSize', 10, 'LineWidth', 2);
legend('Top Left', 'Top Right', 'Bottom Left', 'Bottom Right');
hold off;

grid_points= [top_left(1) top_left(2);top_right(1) top_right(2);
              bottom_left(1) bottom_left(2); bottom_right(1) bottom_right(2)];


%% OCR
[img_max_height,img_max_width]= size(grayImg);


% Frequencies axis

% Width of the upper OCR area
upper_area_width = abs(grid_points(1,1) - img_max_width);

% Height of the upper OCR area
upper_area_height = grid_points(1,2) - 1;


% Perform OCR
ocr_frequency_results = ocr(img, [grid_points(1,1), 1, upper_area_width, upper_area_height], ...
    'LayoutAnalysis', 'Block', 'CharacterSet', "0124568k");



% Decibel axis

% Width of the left OCR area
left_area_width = grid_points(1,1) - 1;

% Height of the left OCR area
left_area_height = abs(grid_points(1,2) - img_max_height);

% Perform OCR
ocr_decibel_results = ocr(img, [1,grid_points(1,2), left_area_width, left_area_height], ...
    'LayoutAnalysis', 'Block', 'CharacterSet', "01234546789-");


%% Extraction of grid intersections only with Hough transformation


bin_img = edge(grayImg, 'Canny');
% Dilation
edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img, strel('line',3,90));

edgeMap = imfill(edgeMap, 4, 'holes');

% Extract the perimeter of the grid
edgeMap = bwmorph(edgeMap, 'remove');

% Increase line size preparing for Hough transformation
edgeMap = imdilate(edgeMap, strel("square", 3));


% Apply Hough transformation to identify the grid axis
[H, theta, rho] = hough(edgeMap);
peaks = houghpeaks(H, 4, 'threshold', ceil(0.01 * max(H(:))));
hough_grid_lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 150, 'MinLength',150); 


% Apply the Canny operator to obtain the binary edge map
bin_img = edge(grayImg, 'Canny');

edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img,strel('line',3,90));


edgeMap = imdilate(edgeMap, strel("square", 3));

edgeMap= bwmorph(edgeMap,'skeleton');


% Compute the Hough Transform
[H, theta, rho] = hough(edgeMap);
% Identify the peaks in the Hough transform (number and threshold can beadjusted)
%peaks = houghpeaks(H, 4);
peaks = houghpeaks(H, 30, 'threshold', ceil(0.01 * max(H(:))));
% Extract the detected lines based on the found peaks
hough_internal_lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 150, 'MinLength', 150);


% Filtra le linee non orizzontali e verticali secondo un certo limite
filteredLines = [];
angleThreshold = 1; % soglia in gradi (puoi regolarla)

for k = 1:length(hough_internal_lines)
    % Ottieni l'angolo theta per questa linea
    currentTheta = hough_internal_lines(k).theta;
    
    % Verifica se la linea è quasi orizzontale (vicino a 0° o 180°)
    isHorizontal = abs(mod(currentTheta, 180)) <= angleThreshold || ...
                  abs(mod(currentTheta, 180) - 180) <= angleThreshold;
    
    % Verifica se la linea è quasi verticale (vicino a 90°)
    isVertical = abs(mod(currentTheta, 180) - 90) <= angleThreshold;
    
    % Conserva solo le linee orizzontali o verticali
    if isHorizontal || isVertical
        filteredLines = [filteredLines; hough_internal_lines(k)];
    end
end


% DEBUG %
figure;
imshow(img);
hold on;
for k = 1:length(hough_grid_lines)
xy = [hough_grid_lines(k).point1; hough_grid_lines(k).point2];
plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'blue');
% Display the starting and ending points of the lines
plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end
hold on;
for k = 1:length(filteredLines)
xy = [filteredLines(k).point1; filteredLines(k).point2];
plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
% Display the starting and ending points of the lines
plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end
title('ALL Lines detected by the Hough Transform');
hold off;




%% Estimation of Grid corners
% calculated on the mean between detected points with Hough and digital
% intersection points 


hough_points = [];
for i = 1:length(lines)
    hough_points = [hough_points; 
                   lines(i).point1;
                   lines(i).point2];
end

% 1. Filter points in the OCR area

% Get the left-lower corner of the first frequency number (125)
% [x , y+height]
left_lower_boundingBox_first_freq = [ocr_frequency_results.WordBoundingBoxes(1,1), ocr_frequency_results.WordBoundingBoxes(1,2)+ocr_frequency_results.WordBoundingBoxes(1,4)];


% Get the right-lower corner of the last frequency number (16k)
% [x +width, y+height]
%Note : this is used as a double check to be completely sure that the
%points are valid
right_lower_boundingBox_last_freq = [ocr_frequency_results.WordBoundingBoxes(end,1)+ocr_frequency_results.WordBoundingBoxes(end,3), ocr_frequency_results.WordBoundingBoxes(end,2)+ocr_frequency_results.WordBoundingBoxes(end,4)];

% Get the right-upper corner of the first decibel number (-10)
% [x+weight , y]
right_upper_boundingBox_first_dec = [ocr_decibel_results.WordBoundingBoxes(1,1)+ocr_decibel_results.WordBoundingBoxes(1,3), ocr_decibel_results.WordBoundingBoxes(1,2)];

% Get the right-lower corner of the last decibel number (120)
% [x +width, y+height]
%Note : this is used as a double check to be completely sure that the
%points are valid
right_lower_boundingBox_last_dec = [ocr_decibel_results.WordBoundingBoxes(end,1)+ocr_decibel_results.WordBoundingBoxes(end,3), ocr_decibel_results.WordBoundingBoxes(end,2)+ocr_decibel_results.WordBoundingBoxes(end,4)];


valid_points = [];
for i = 1:size(hough_points, 1)
    point = hough_points(i, :);
    
    % Check if the point is below the frequency text area
    in_upper_ocr = (point(1) > left_lower_boundingBox_first_freq(1) && point(2) < left_lower_boundingBox_first_freq(2));
    
    % Check if the point is on the right of decibel text area
    in_left_ocr = (point(1) <= right_upper_boundingBox_first_dec(1) && point(2) >= right_upper_boundingBox_first_dec(2));
    
    % Check if the point is valid
    if ~in_upper_ocr && ~in_left_ocr
        valid_points = [valid_points; point];
    end
end




% Find the closest point to grid corners

%Threshold
max_point_distance=5 ; % 5 pixels

% Save the positive pixel in the binary image
[bin_x, bin_y] = find(bin_img==1); 
points=[bin_y,bin_x];

refined_grid_points = zeros(4, 2);
for i = 1:4
    
    % Extract the closest point
    idx = knnsearch(valid_points, grid_points(i,:));

    % If the valid closest hough point is too far from the estimated digital grid
    % point
    if(norm(valid_points(idx, :) - grid_points(i,:))>max_point_distance)
        refined_grid_points(i,:) = grid_points(i,:);
        continue;
    end
        
    % Select best point between valid and digital one

    % First point : extract the distance between the valid point and the closest
    % pixel of the grid corner
    [ind1 , distance1]= knnsearch(points, valid_points(idx, :));

    % Second point : extract the distance between the digital point and the closest
    % pixel of the grid corner
    [ind2, distance2]= knnsearch(points, grid_points(i,:));

    % Hough valid point is too far from the grid, so digital value is the best
    % approximation of the image grid
    if(distance1>max_point_distance )
        refined_grid_points(i,:) = grid_points(i,:);
    continue;

    % Digital point is too far from the grid, so hough point is the best
    % approximation of the image grid
    elseif(distance2>max_point_distance)
        refined_grid_points(i,:) = valid_points(idx, :);
    continue;

    end

    % Whether both points are valid according to the threshold, following
    % instructions verify which is the best choice to take into account

    % Extract the hough detected point given it iz
    if(distance1==distance2)
        refined_grid_points(i,:) = valid_points(idx, :);
        continue;
    end

    % Extract the minor distance
    switch(min(distance1,distance2))
        case distance1
            refined_grid_points(i,:) = valid_points(idx, :);
        case distance2
            refined_grid_points(i,:) = grid_points(i,:);
    end

end


%% 
% % DEBUG
% figure;
% imshow(bin_img);
% hold on;
% 
% % % Plot digital grid corner points
% plot(grid_points(:,1), grid_points(:,2), 'mo', 'MarkerSize', 8, 'LineWidth', 2);
% 
% % Plot refined points 
% plot(refined_grid_points(:,1), refined_grid_points(:,2), 'rx', 'MarkerSize', 8, 'LineWidth', 2);
% 
% plot(points(ind1,1), points(ind1,2), 'bx', 'MarkerSize', 8, 'LineWidth', 2);
% plot(points(ind2,1), points(ind2,2), 'bx', 'MarkerSize', 8, 'LineWidth', 2);
% 
% plot(points(:,1), points(:,2), 'gx', 'MarkerSize', 1, 'LineWidth', 2);
% 
% 
% 
% % legend('Digital Grid corners', 'Punti raffinati');
% title('Adjusted grid corners');


%% Dynamic and improved solution to find grid internal intersections

%% 

% Apply the Canny operator to obtain the binary edge map
bin_img = edge(grayImg, 'Canny');

edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img,strel('line',3,90));


edgeMap = imdilate(edgeMap, strel("square", 3));

edgeMap= bwmorph(edgeMap,'skeleton');


% Compute the Hough Transform
[H, theta, rho] = hough(edgeMap);

peaks = houghpeaks(H, 30, 'threshold', ceil(0.01 * max(H(:))));
% Extract the detected lines based on the found peaks
lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 150, 'MinLength', 150);


% Filtra le linee non orizzontali e verticali secondo un certo limite
filteredLines = [];
angleThreshold = 1; % soglia in gradi (puoi regolarla)

for k = 1:length(lines)
    % Ottieni l'angolo theta per questa linea
    currentTheta = lines(k).theta;
    
    % Verifica se la linea è quasi orizzontale (vicino a 0° o 180°)
    isHorizontal = abs(mod(currentTheta, 180)) <= angleThreshold || ...
                  abs(mod(currentTheta, 180) - 180) <= angleThreshold;
    
    % Verifica se la linea è quasi verticale (vicino a 90°)
    isVertical = abs(mod(currentTheta, 180) - 90) <= angleThreshold;
        
    % Conserva solo le linee orizzontali o verticali
    if isHorizontal || isVertical
        filteredLines = [filteredLines; lines(k)];
    end
end



figure;
imshow(img);
hold on;
for k = 1:length(filteredLines)
xy = [filteredLines(k).point1; filteredLines(k).point2];
plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
% Display the starting and ending points of the lines
plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end
title('Filteresd Lines detected with the Hough Transform');
hold off;

%% Look for the intersection between grid corner lines
num_horiz_lines = 16;
num_vert_lines  = 15;



% 
% 
% 
% %% Static version
% % extract intersection coordinates with the grid lines
% 
% num_horiz_lines=14;
% num_vert_lines=8;
% 
% horizontal_lines=zeros(num_horiz_lines,4);
% 
% for i=1:num_horiz_lines
% 
%     point1.x=ocr_decibel_results.WordBoundingBoxes(i,1) + ocr_decibel_results.WordBoundingBoxes(i,3);
%     point1.y= ocr_decibel_results.WordBoundingBoxes(i,2) + (ocr_decibel_results.WordBoundingBoxes(i,4)/2);
% 
%     point2.x=grid_points(2,1);
%     point2.y=point1.y;
% 
%     [intersec_X,intersec_Y]= intersectLines(point1.x,point1.y, point2.x,point2.y, grid_points(1,1),grid_points(1,2),grid_points(3,1),grid_points(3,2));
% 
%     horizontal_lines(i,:)=[intersec_X,intersec_Y,point2.x,point2.y];
% 
% 
%     plot(point1.x,point1.y, 'go', 'MarkerSize', 5, 'LineWidth', 2);
%     plot(intersec_X,intersec_Y, 'ro', 'MarkerSize', 5, 'LineWidth', 2);
%     plot(point2.x,point2.y, 'go', 'MarkerSize', 5, 'LineWidth', 2);
% 
% end
% 
% % Vertical lines
% 
% vertical_lines=zeros(num_vert_lines,4);
% 
% for i=1:num_vert_lines
% 
%     point1.x=ocr_frequency_results.WordBoundingBoxes(i,1) + (ocr_frequency_results.WordBoundingBoxes(i,3)/2);
%     point1.y= ocr_frequency_results.WordBoundingBoxes(i,2) + ocr_frequency_results.WordBoundingBoxes(i,4);
% 
%     point2.x=point1.x;
%     point2.y=grid_points(3,2);
% 
%     [intersec_X,intersec_Y]= intersectLines(point1.x,point1.y, point2.x,point2.y, grid_points(1,1),grid_points(1,2),grid_points(2,1),grid_points(2,2));
% 
%     vertical_lines(i,:)=[intersec_X,intersec_Y,point2.x,point2.y];
% 
% 
%     plot(point1.x,point1.y, 'go', 'MarkerSize', 5, 'LineWidth', 2);
%     plot(intersec_X,intersec_Y, 'ro', 'MarkerSize', 5, 'LineWidth', 2);
%     plot(point2.x,point2.y, 'go', 'MarkerSize', 5, 'LineWidth', 2);
% 
% end
% 
% 
% 
% % Find intersections between all grid lines
% grid_lines_intersections= zeros(num_horiz_lines * num_vert_lines,2);
% 
% k = 1;
% % For each horizontal line identifies the intersection points for each
% % vertical line that pass through it
% for i = 1:num_horiz_lines    
%     for j = 1:num_vert_lines
% 
%         % compute point
%         [xi, yi] = intersectLines(horizontal_lines(i, 1),horizontal_lines(i, 2),horizontal_lines(i, 3),horizontal_lines(i, 4), ...
%             vertical_lines(j, 1),vertical_lines(j, 2),vertical_lines(j, 3),vertical_lines(j, 4));
% 
%         grid_lines_intersections(k,1) = xi;
%         grid_lines_intersections(k,2) = yi;
% 
% 
%         k = k + 1;
%     end
% end
% 
% % Print the grid intersection points
% for k = 1:size(grid_lines_intersections,1)
%     plot(grid_lines_intersections(k,1),grid_lines_intersections(k,2), 'yo', 'MarkerSize', 2, 'LineWidth', 2);
% end
% 
% hold off;


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
    
    % Check for invalid point coordinates
    if abs(xI) > 1e3 || abs(yI) > 1e3
        xI = NaN;
        yI = NaN;
    end

end