%% 1. Image pre-processing script in MATLAB

clc; clear; close all;

% Load image
img = imread('Noah_01_01_02.jpg');
grayImg = rgb2gray(img);


%% 2. Preparing the image before applying th Hough transformation to identify an APPROXIMATION of grid corners
% Idea: It aims to identify a possible approximation of where the grid corners are in the image, in next steps there will be found the exact points 

% Edge-detection with Canny's algorithm + Morphologycal operations

% Apply the Canny operator to obtain the binary edge map
bin_img = edge(grayImg, 'Canny');

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
hough_grid_lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 40,'MinLength',150);

% % DEBUG
% figure;
% imshow(img);
% hold on;
% for k = 1:length(hough_grid_lines)
%     xy = [hough_grid_lines(k).point1; hough_grid_lines(k).point2];
%     plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
%     % Display the starting and ending points of the lines
%     plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
%     plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
% end
% 
% title('Lines detected with the Hough Transform');
% hold off;

%% 2.2 Identify digital intersection points between detected segments

num_lines = 4;

% List of x coordinates of intersection points
point_intersec_x = [];
% List of y coordinates of intersection points
point_intersec_y = [];

for i = 1:num_lines
    % First line
    line1_p1 = hough_grid_lines(i).point1;
    line1_p2 = hough_grid_lines(i).point2;

    % Check all intersections between line1 and the other lines
    for j = i+1:num_lines

        if j ~= i 
            % Second line
            line2_p1 = hough_grid_lines(j).point1;
            line2_p2 = hough_grid_lines(j).point2;
    
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

% %DEBUG
% figure;
% imshow(img);
% hold on;
% plot(top_left(1), top_left(2), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
% plot(top_right(1), top_right(2), 'go', 'MarkerSize', 10, 'LineWidth', 2);
% plot(bottom_left(1), bottom_left(2), 'co', 'MarkerSize', 10, 'LineWidth', 2);
% plot(bottom_right(1), bottom_right(2), 'mo', 'MarkerSize', 10, 'LineWidth', 2);
% legend('Top Left', 'Top Right', 'Bottom Left', 'Bottom Right');
% hold off;

% Containts the digital approximation of grid corners
grid_points= [top_left(1) top_left(2);top_right(1) top_right(2);
              bottom_left(1) bottom_left(2); bottom_right(1) bottom_right(2)];


% 1. Filter points in the OCR area 
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


%% Find the closest point to digital grid corners


% Extract as much information as possible from the binary image excluding
% the ocr text area which can lead to ouliers in the grid corner
% coordinates
x = min(grid_points(1,1), grid_points(3,1));
y = min(grid_points(1,2), grid_points(2,2));
cropped_bin_img = imcrop(bin_img, [x, y, img_max_width, img_max_height]);

% Save the positive pixel in the binary image
[bin_x, bin_y] = find(cropped_bin_img==1);
points = [bin_y, bin_x];

% Transform grid_points to cropped image coordinates for processing
grid_points_cropped = grid_points - [x, y];


% Initialize refined points in cropped coordinates
refined_grid_points_cropped = zeros(4, 2);

for i = 1:4
    % Extract the closest point equal to 1 in the binary image near to the
    % digital grid corner
    
    [ind2, ~] = knnsearch(points, grid_points_cropped(i,:),"Distance","cityblock");
    refined_grid_points_cropped(i,:) = points(ind2,:);
end

% Transform refined points back to original coordinates for display/output
refined_grid_points = refined_grid_points_cropped + [x-1, y-1];


% % DEBUG
% figure;
% imshow(cropped_bin_img);
% hold on;
% plot(refined_grid_points_cropped(:,1), refined_grid_points_cropped(:,2), 'rx', 'MarkerSize', 8, 'LineWidth', 2);
% hold off;
% % Display in original image coordinates
% figure;
% imshow(bin_img);
% hold on;
% plot(grid_points(:,1), grid_points(:,2), 'mo', 'MarkerSize', 8, 'LineWidth', 2);
% plot(refined_grid_points(:,1), refined_grid_points(:,2), 'rx', 'MarkerSize', 8, 'LineWidth', 2);
% % Transform points back to original coordinates for display
% points_original = points + [x-1, y-1];
% plot(points_original(:,1), points_original(:,2), 'gx', 'MarkerSize', 1, 'LineWidth', 2);
% title('Adjusted grid corners');

% Initialize the adjusted grid corner segment variables
grid_corner_lines = struct('point1', {}, 'point2', {});

grid_corner_lines(1) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(2,:)); % upper horizontal line
grid_corner_lines(2) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(3,:)); % left vertical line
grid_corner_lines(3) = struct('point1', refined_grid_points(3,:), 'point2', refined_grid_points(4,:)); % lower horizontal line
grid_corner_lines(4) = struct('point1', refined_grid_points(2,:), 'point2', refined_grid_points(4,:)); % right vertical line




%% Dynamic and improved solution to find grid internal intersections
% given the lines detected by the Hough transformation, after checked the
% validity,it aims to identify the



% Apply the Canny operator to obtain the binary edge map
bin_img = edge(grayImg, 'Canny');

edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img,strel('line',3,90));


edgeMap = imdilate(edgeMap, strel("square", 3));

edgeMap= bwmorph(edgeMap,'skeleton');


% Compute the Hough Transform
[H, theta, rho] = hough(edgeMap);

peaks = houghpeaks(H, 31, 'threshold', ceil(0.01 * max(H(:))));
% Extract the detected lines based on the found peaks
lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 150, 'MinLength', 150);


% Filter all lines that are not neither horizontal nor vertical according
% to a threshold

max_num_horiz_lines = 16;
max_num_vert_lines  = 15;

filteredLines = [];
angleThreshold = 1; % angle threshold

horizontal_lines= zeros(max_num_horiz_lines,4); 
vertical_lines= zeros(max_num_vert_lines,4);

h=1;
v=1;
for i = 1:length(lines)
    currentTheta = lines(i).theta;
    
    % Verify if the line tends to be vertical
    isVertical = abs(mod(currentTheta, 180)) <= angleThreshold || ...
                  abs(mod(currentTheta, 180) - 180) <= angleThreshold;

    % Verify if the line tends to be horizontal
    isHorizontal = abs(mod(currentTheta, 180) - 90) <= angleThreshold;
        
    tmp= [lines(i).point1,lines(i).point2];
    % Save only the horizontal or vertical lines
    if isHorizontal && ~checkIntersection(tmp,grid_corner_lines(1),grid_corner_lines(3))
        horizontal_lines(h,:)=tmp;
        filteredLines = [filteredLines; lines(i)];
        h=h+1;
    elseif isVertical && ~checkIntersection(tmp,grid_corner_lines(2),grid_corner_lines(4))
        vertical_lines(v,:) = tmp;
        filteredLines = [filteredLines; lines(i)];
        v=v+1;
    end
end



% Remove empty rows in the structures

firstEmptyRowIdx= find(all(horizontal_lines == 0, 2), 1);
if not(isempty(firstEmptyRowIdx))
    horizontal_lines = horizontal_lines(1:firstEmptyRowIdx-1,:);
end

firstEmptyRowIdx= find(all(vertical_lines == 0, 2), 1);
% If there is a empty line
if not(isempty(firstEmptyRowIdx))
    vertical_lines = vertical_lines(1:firstEmptyRowIdx-1,:);
end



% % DEBUG
% figure;
% imshow(img);
% hold on;
% for k = 1:length(filteredLines)
% xy = [filteredLines(k).point1; filteredLines(k).point2];
% plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
% % Display the starting and ending points of the lines
% plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
% plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
% end
% title('Filtered Lines detected with the Hough Transform');
% hold off;



%% Look for the intersection between grid corner lines


% Inizializza una variabile per raccogliere tutti i punti di intersezione
intersectionPoints = zeros(max_num_vert_lines * max_num_horiz_lines, 2);


% Search for intersection between grid corner lines and horizontal/vertical lines

k = 1;  % index to save intersections
for i = 1:length(grid_corner_lines)

    x1 = grid_corner_lines(i).point1(1);
    x2 = grid_corner_lines(i).point2(1);
    y1 = grid_corner_lines(i).point1(2);
    y2 = grid_corner_lines(i).point2(2);
    seg1_x = [x1, x2];
    seg1_y = [y1, y2];
    
    % Per ogni linea in filteredLines
    for j = 1:length(filteredLines)
        % Estrai le coordinate dalla j-esima linea di filteredLines
        xx1 = filteredLines(j).point1(1);
        xx2 = filteredLines(j).point2(1);
        yy1 = filteredLines(j).point1(2);
        yy2 = filteredLines(j).point2(2);
        seg2_x = [xx1, xx2];
        seg2_y = [yy1, yy2];
        
        % Calcola l'intersezione tra le due linee
        [xi, yi] = polyxpoly(seg1_x, seg1_y, seg2_x, seg2_y);
        
        if ~isempty(xi)
            % Salva l'intersezione (se polyxpoly restituisce più punti, prendi il primo)
            intersectionPoints(k, :) = [xi(1), yi(1)];
            k = k + 1;
        end
    end
end

% Identify internal intersections between horizontal and vertical lines


% Idea: for each horizontal line I look for the intersection points between
% the vertical segments that pass through it

for i = 1:length(horizontal_lines)

    % Horizontal segment
    seg1_x = [horizontal_lines(i,1), horizontal_lines(i,3)];
    seg1_y = [horizontal_lines(i,2), horizontal_lines(i,4)];
    
    for j=1:length(vertical_lines)
        % All vertical segments
        seg2_x = [vertical_lines(j,1), vertical_lines(j,3)];
        seg2_y = [vertical_lines(j,2),vertical_lines(j,4)];
        
        % For each vertical line it compute the polyline
        [xi, yi] = polyxpoly(seg1_x, seg1_y, seg2_x, seg2_y);
        
        if ~isempty(xi)
            % Salva l'intersezione (se polyxpoly restituisce più punti, prendi il primo)
            intersectionPoints(k, :) = [xi(1), yi(1)];
            k = k + 1;
        end
    end
end

% % DEBUG
% % Crea una nuova figura
% figure;
% imshow(grayImg);
% hold on;  % Abilita la sovrapposizione dei plot
% 
% % Plot delle linee orizzontali (in rosso)
% numHorizLines = size(horizontal_lines, 1);
% for i = 1:numHorizLines
%     x_coords = [horizontal_lines(i,1), horizontal_lines(i,3)];
%     y_coords = [horizontal_lines(i,2), horizontal_lines(i,4)];
%     plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
% end
% 
% % Plot delle linee verticali (in blu)
% numVertLines = size(vertical_lines, 1);
% for i = 1:numVertLines
%     x_coords = [vertical_lines(i,1), vertical_lines(i,3)];
%     y_coords = [vertical_lines(i,2), vertical_lines(i,4)];
%     plot(x_coords, y_coords, 'b-', 'LineWidth', 2);
% end
% 
% 
% title('Linee Grid e Punti di Intersezione');
% 
% hold off;


% Optimize the size
intersectionPoints = intersectionPoints(1:k-1, :);
% 
% DEGUB
figure, imshow(grayImg), hold on;

plot(intersectionPoints(:,1), intersectionPoints(:,2), 'ro', 'MarkerSize', 4, 'LineWidth', 1);

title('Grid intersection points');


for i = 1:length(grid_corner_lines)
    % Punto 1 della linea
    x_pt1 = grid_corner_lines(i).point1(1);
    y_pt1 = grid_corner_lines(i).point1(2);
    plot(x_pt1, y_pt1, 'bs', 'MarkerSize', 4, 'LineWidth', 1);    
    % Punto 2 della linea
    x_pt2 = grid_corner_lines(i).point2(1);
    y_pt2 = grid_corner_lines(i).point2(2);
    plot(x_pt2, y_pt2, 'bs', 'MarkerSize', 4, 'LineWidth', 1);
end

%% OCR IMPROVEMENT

%1.  List points over the frequency text area by extracting coordinates 
% that are above the upper-left grid corner

% Frequency
upper_corner=max(grid_corner_lines(1).point1(2),grid_corner_lines(1).point2(2));
idx = intersectionPoints(:,2) <= upper_corner;
freq_points = sortrows(intersectionPoints(idx,:));
if size(freq_points,1) ~= 13
    throw(MException('sizeError:Error','The number of points is not sufficient'));
end

% Initialize array to store OCR results for the frequency axis
freq_ocr_results = cell(size(freq_points,1), 1);
%DEBUG
figure, imshow(grayImg);

% Process OCR for each point in freq_points
for i = 1:size(freq_points,1)
    % Calculate bounding points for OCR area
    if i == 1
        % For the first point, use the original approach since there's no previous point
        a = abs(freq_points(i,1) - 1) / 2.5;
    elseif i == 13
        % Given the last text results to be longer, the ocr requires a bigger
        % area to correctly detect the string
          a =abs(freq_points(i,1) - freq_points(i-1,1)) /2;
    else
        % For other points, calculate 'a' based on the difference with the previous point
        a = abs(freq_points(i,1) - freq_points(i-1,1)) / 2.5;
    end
    
    point1 = [freq_points(i,1) - a, freq_points(i,2)];
    point2 = [freq_points(i,1) + a, freq_points(i,2)];
    
    % Define rectangular area for OCR
    % [x, y, width, height]

    width_ocr_area=point2(1)-point1(1);
    if point1(1)+width_ocr_area>img_max_width
        width_ocr_area=img_max_width-point1(1)-1;
    end
    
    ocr_area = [point1(1), 1, width_ocr_area, point1(2) - 1];
    
    % Perform OCR
    freq_ocr_results{i} = ocr(img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "0124568k");
    if length(freq_ocr_results{i}.Words)<1 
        continue;
    end

    % Plot corners of the OCR area
    hold on;
    % Top-left corner
    plot(ocr_area(1), ocr_area(2), 'bs', 'MarkerSize', 4, 'LineWidth', 1);
    % Top-right corner
    plot(ocr_area(1) + ocr_area(3), ocr_area(2), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
    % Bottom-right corner
    plot(ocr_area(1) + ocr_area(3), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
    % Bottom-left corner
    plot(ocr_area(1), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);

    % Optional: Draw the rectangle connecting the corners
    rectangle('Position', ocr_area, 'EdgeColor', 'r');
end

% Decibel axis
left_corner=max(grid_corner_lines(2).point1(1),grid_corner_lines(2).point2(1));
idx = intersectionPoints(:,1) <= left_corner;
dB_points = sortrows(intersectionPoints(idx,:));
if size(dB_points,1) ~= 14
    throw(MException('sizeError:Error','The number of points is not sufficient'));
end

% Initialize array to store OCR results for the frequency axis
dB_ocr_results = cell(size(dB_points,1), 1);

% Process OCR for each point in dB_points
for i = 1:size(dB_points,1)
    % Calculate bounding points for OCR area
    if i == 1
        % For the first point, use the original approach since there's no previous point
        a = abs(dB_points(i,2) - 1) / 2;
    else
        % For other points, calculate 'a' based on the difference with the previous point
        a = abs(dB_points(i,2) - dB_points(i-1,2)) / 2;
    end
    
    point1 = [dB_points(i,1) , dB_points(i,2)-a];
    point2 = [dB_points(i,1) , dB_points(i,2)+a];
    

    % check if the area is not out the image's y-axis boundary
    height_ocr_area=point2(2)-point1(2);
    if point1(2)+height_ocr_area>img_max_height
        height_ocr_area=img_max_height-point1(2)-1;
    end
    
    % Define rectangular area for OCR
    % [x, y, width, height]
    ocr_area = [1, point1(2), point1(1) - 1,height_ocr_area];
        rectangle('Position', ocr_area, 'EdgeColor', 'r');

    % Perform OCR
    dB_ocr_results{i} = ocr(img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "0124568k");

    % Plot corners of the OCR area
    % Top-left corner
    plot(ocr_area(1), ocr_area(2), 'bs', 'MarkerSize', 4, 'LineWidth', 1);
    % Top-right corner
    plot(ocr_area(1) + ocr_area(3), ocr_area(2), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
    % Bottom-right corner
    plot(ocr_area(1) + ocr_area(3), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
    % Bottom-left corner
    plot(ocr_area(1), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);

    % Optional: Draw the rectangle connecting the corners
    rectangle('Position', ocr_area, 'EdgeColor', 'r');

end

% Ensure the figure is updated
hold off;






%% % FINAL PART
% 1. Extract information with Hough
close all;

x = max(refined_grid_points(1,1), refined_grid_points(3,1));
y = max(refined_grid_points(1,2), refined_grid_points(2,2));
cropped_img = imcrop (grayImg, [x,y,refined_grid_points(2,1)- x, refined_grid_points(3,2)-y]);

filtered_img = imadjust(cropped_img);

% Apply the Canny operator to obtain the binary edge map
BW = edge(filtered_img, 'Canny');

BW = imdilate(BW, strel('line',3,0)) | imdilate(BW,strel('line',3,90));

BW = imdilate(BW, strel("rectangle",[2 6]));% Ottimale per trovare i O e X

% BW= bwmorph(BW,'skeleton');
BW = bwskel(BW);

% DEBUG
% figure ; imshow(BW);
% Compute the Hough Transform
[H, theta, rho] = hough(BW,'Theta',-85:-5);

threshold = ceil(0.6 * max(H(:))); % Soglia più bassa per includere picchi meno prominenti

peaks = houghpeaks(H, 60,'Theta',-85:-5,'Threshold',threshold); % 40 for the maximum possible measurement case
% Extract the detected lines based on the found peaks
lines1 = houghlines(BW, theta, rho, peaks,"MinLength",50,"FillGap",20);

[H, theta, rho] = hough(BW,'Theta',5:85);

peaks = houghpeaks(H, 60,'Theta',5:85,'Threshold',threshold);
% Extract the detected lines based on the found peaks
lines2 = houghlines(BW, theta, rho, peaks,"MinLength",50,"FillGap",20);

lines=[lines1, lines2];
% DEBUG
figure;
imshow(BW);
hold on;
for k = 1:length(lines)
    xy = [lines(k).point1; lines(k).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
    % Display the starting and ending points of the lines
    plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
    plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end
title('Filtered Lines detected with the Hough Transform');
hold off;


%% 
% 2. Recognizing the segments ( by identify the cluster with BDSCAN)

% Apply DBSCAN on the combined features
% Confronto tra diverse configurazioni di DBSCAN
% Calcolo dei centroidi delle linee rilevate
all_lines = [lines1 lines2];
centroids = zeros(length(all_lines), 2);
thetas = zeros(length(all_lines), 1);
rhos = zeros(length(all_lines), 1);

for k = 1:length(all_lines)
    % Calcola punto medio di ogni linea
    pt1 = all_lines(k).point1;
    pt2 = all_lines(k).point2;
    centroids(k,:) = [(pt1(1) + pt2(1))/2, (pt1(2) + pt2(2))/2];
    
    % Memorizza valori di theta e rho
    thetas(k) = all_lines(k).theta;
    rhos(k) = all_lines(k).rho;
end

% Crea matrice delle caratteristiche per il clustering
% Normalizza le caratteristiche per dare uguale importanza
centroid_x_norm = (centroids(:,1) - min(centroids(:,1))) / (max(centroids(:,1)) - min(centroids(:,1)));
centroid_y_norm = (centroids(:,2) - min(centroids(:,2))) / (max(centroids(:,2)) - min(centroids(:,2)));
thetas_norm = (thetas - min(thetas)) / (max(thetas) - min(thetas));
rhos_norm = (rhos - min(rhos)) / (max(rhos) - min(rhos));

% Matrice delle caratteristiche normalizzate
data_norm = [centroid_x_norm, centroid_y_norm, thetas_norm, rhos_norm];

% Parametri per DBSCAN
epsilon = 0.25; % Epsilon per dati normalizzati (0-1)

minPts = 1;
idx1 = dbscan(data_norm, epsilon, minPts);
num_clusters = max(idx1);
noise_points1 = sum(idx1 == -1);


% 3. optimize the cluster information by reducing the number of lines

% Find the optimal theta for each cluster
% Inizializza array per memorizzare theta ottimale per ogni cluster
% Find the optimal theta and rho for each cluster
theta_ottimali = zeros(num_clusters, 1);
rho_ottimali = zeros(num_clusters, 1);
punti_rette = zeros(num_clusters, 4);

new_centroids= zeros(num_clusters,2);

segment_length = 10; 
for i = 1:num_clusters
    cluster_indices = find(idx1 == i);
    cluster_centroids = centroids(cluster_indices, :);
    cluster_thetas = thetas(cluster_indices);  % Theta in gradi
    
    % Compute the average theta (computing circular mean)
    x_sum = sum(cosd(cluster_thetas));
    y_sum = sum(sind(cluster_thetas));
    theta_avg_rad = atan2(y_sum, x_sum); 
    theta_avg_deg = rad2deg(theta_avg_rad); %convert result in degrees
    
    % Compute average rho
    rhos_i = cluster_centroids(:,1) * cosd(theta_avg_deg) + cluster_centroids(:,2) * sind(theta_avg_deg);
    rho_avg = mean(rhos_i);
    
    theta_ottimali(i) = theta_avg_deg;
    rho_ottimali(i) = rho_avg;

    % 1. Trova l'elemento del cluster con theta più vicino alla media
    [~, idx_min] = min(abs(cluster_thetas - theta_avg_deg)); % Indice del theta più vicino
    selected_centroid = cluster_centroids(idx_min, :); % Centroide selezionato
    new_centroids(i,:)=selected_centroid;
    % 2. Proietta il centroide selezionato sulla retta ottimale
    x_proj = selected_centroid(1) - (selected_centroid(1)*cosd(theta_avg_deg) + selected_centroid(2)*sind(theta_avg_deg) - rho_avg) * cosd(theta_avg_deg);
    y_proj = selected_centroid(2) - (selected_centroid(1)*cosd(theta_avg_deg) + selected_centroid(2)*sind(theta_avg_deg) - rho_avg) * sind(theta_avg_deg);

    % 3. Calcola la direzione della retta
    direction = [-sind(theta_avg_deg), cosd(theta_avg_deg)];
    
    % 4. Calcola i punti estremi del segmento

    x1 = x_proj - segment_length * direction(1);
    y1 = y_proj - segment_length * direction(2);
    x2 = x_proj + segment_length * direction(1);
    y2 = y_proj + segment_length * direction(2);
    
    punti_rette(i, :) = [x1, y1, x2, y2];
end

% TODO da sistemare
% Rimuovi linee con la stessa pendenza che siano troppo vicine tra loro

% Array per tracciare i cluster fusi
cluster_merged = false(num_clusters, 1); % Flag per cluster uniti
merged_info = cell(num_clusters, 1);     % Informazioni sui cluster uniti

% Parametri di tolleranza (regolabili)
angle_threshold = 3;   % Gradi per differenza angolare massima
distance_threshold = 100; % Pixel per distanza massima tra centroidi

% Calcola l'angolo effettivo delle linee (dalla normale di Hough)
theta_line = theta_ottimali + 90; % Converti theta della normale in angolo della linea

% Normalizza gli angoli nell'intervallo [0, 180) per gestire la periodicità
theta_line = mod(theta_line, 180);
% Inizializza vettore logico per linee da mantenere
keep = true(num_clusters, 1);

% Confronta tutte le coppie di linee
for i = 1:num_clusters
    if ~keep(i), continue; end % Salta linee già marcate per la rimozione

    for j = i+1:num_clusters
        if ~keep(j), continue; end

        % Calcola differenza angolare (considerando la periodicità 180°)
        angle_diff = abs(theta_line(i) - theta_line(j));
        angle_diff = min(angle_diff, 180 - angle_diff); % Prendi il minimo tra diff e 180-diff
        centroid_dist = norm(new_centroids(i,:) - new_centroids(j,:));


        % Criterio di controllo sovrapposizione e vicinanza tra due linee
        if angle_diff <= angle_threshold || centroid_dist<=distance_threshold

            % TRACCIA LA FUSIONE
            cluster_merged(i) = true;
            if isempty(merged_info{i})
                merged_info{i} = j; % Prima fusione
            else
                merged_info{i} = [merged_info{i}, j]; % Aggiungi alla lista
            end
            
            updated_centroid = mean([new_centroids(i,:); new_centroids(j,:)]);

            theta_ottimali(i) = mean([theta_ottimali(i),theta_ottimali(j)]); % aggiorno   

                % 2. Ricalcola rho_ottimali usando il centroide
                rho_ottimali(i) = updated_centroid(1) * cosd(theta_ottimali(i)) + updated_centroid(2) * sind(theta_ottimali(i));

                % Proietta il centroide sulla nuova retta
                x_proj = updated_centroid(1) - (updated_centroid(1)*cosd(theta_ottimali(i)) + updated_centroid(2)*sind(theta_ottimali(i)) - rho_ottimali(i)) * cosd(theta_ottimali(i));
                y_proj = updated_centroid(2) - (updated_centroid(1)*cosd(theta_ottimali(i)) + updated_centroid(2)*sind(theta_ottimali(i)) - rho_ottimali(i)) * sind(theta_ottimali(i));

                % Calcola direzione aggiornata
                direction = [-sind(theta_ottimali(i)), cosd(theta_ottimali(i))];

                % Calcola nuovi punti estremi
                x1 = x_proj - segment_length * direction(1);
                y1 = y_proj - segment_length * direction(2);
                x2 = x_proj + segment_length * direction(1);
                y2 = y_proj + segment_length * direction(2);

                punti_rette(i, :) = [x1, y1, x2, y2];

                new_centroids(i,:)=updated_centroid;
                keep(j) = false; % Rimuovi la linea j (mantieni la linea i)
        end
    end
end


% Filtra le strutture dati mantenendo solo le linee non ridondanti
merged_flags = cluster_merged(keep);  % Mantieni i flag di fusione
merged_info_filtered = merged_info(keep);  % Mantieni le informazioni di fusione

new_centroids = new_centroids(keep, :);
punti_rette = punti_rette(keep, :);
theta_ottimali = theta_ottimali(keep);
rho_ottimali = rho_ottimali(keep);
num_clusters = sum(keep); % Aggiorna il numero di cluster


% Ordinamento

% Riordina nuovamente per mantenere la coerenza spaziale
[~, sorted_indices] = sortrows(new_centroids, [1 2]);
new_centroids = new_centroids(sorted_indices, :);
punti_rette = punti_rette(sorted_indices, :);
theta_ottimali = theta_ottimali(sorted_indices);

% Trova i cerchi nell'immagine binaria (per le verifiche successive)
[centers, radii, metric] = imfindcircles(BW,[7 25],"ObjectPolarity","bright","Method","PhaseCode");


% Verifica cerchi nei centroidi dei cluster uniti
tolerance_centroid = 15; % Tolleranza per cerchi nei centroidi
centroid_circles = [];

fprintf('\n=== VERIFICA CERCHI NEI CENTROIDI DEI CLUSTER UNITI ===\n');
for i = 1:num_clusters
    if merged_flags(i)
        [found, circle_idx, dist] = checkCircleAtPosition(new_centroids(i,1), new_centroids(i,2), centers, radii, tolerance_centroid);
        if found
            fprintf('Cluster %d (unito): CERCHIO TROVATO nel centroide - Cerchio %d a distanza %.2f\n', i, circle_idx, dist);
            centroid_circles = [centroid_circles; i, circle_idx, dist, new_centroids(i,:)];
        else
            % Ricerca del cerchio più vicino usando knnsearch
            [closest_idx, closest_dist] = knnsearch(centers, new_centroids(i,:));
            
            % Verifica se la distanza è ragionevole (opzionale)
            if closest_dist <= 30  % soglia di distanza massima
                fprintf('Cluster %d (unito): Cerchio più vicino %d a distanza %.2f dal centroide\n', i, closest_idx, closest_dist);
                centroid_circles = [centroid_circles; i, closest_idx, closest_dist, new_centroids(i,:)];
            else
                fprintf('Cluster %d (unito): NESSUN CERCHIO trovato vicino al centroide (distanza minima: %.2f)\n', i, closest_dist);
            end
        end
    end
end



% %DEBUG
% % Visualizzazione con colori distinti
% figure; 
% imshow(BW); 
% hold on;
% 
% % Genera una matrice di colori unici (una riga per cluster)
% colors = hsv(num_clusters); % Usa la mappa di colori "hsv"
% 
% for i = 1:num_clusters
%     % Estrai il colore per il cluster corrente
%     current_color = colors(i, :);
% 
%     % Disegna la linea del cluster
%     plot(punti_rette(i, [1 3]), punti_rette(i, [2 4]), ...
%         'LineWidth', 2, 'Color', current_color);
% 
%     % Disegna il centroide selezionato
%     plot(new_centroids(i,1), new_centroids(i,2), ...
%         'o', 'MarkerFaceColor', current_color, 'MarkerEdgeColor', 'k');
% end
% 
% hold off;
% title('Cluster con colori distinti');
% 


%% Trovo le intersezioni tra le linee dei cluster
% Prima finire le parti precedenti

% Offset della regione ritagliata
offset_x = x;
offset_y = y;

% Mappa e ordina vertical_lines 
adjusted_vertical_lines = vertical_lines;
adjusted_vertical_lines(:, [1,3]) = vertical_lines(:, [1,3]) - offset_x;
adjusted_vertical_lines(:, [2,4]) = vertical_lines(:, [2,4]) - offset_y;

[~, sorted_indices] = sortrows(adjusted_vertical_lines);
adjusted_vertical_lines = adjusted_vertical_lines(sorted_indices, :);

% Mappa e ordina horizontal_lines
adjusted_horizontal_lines = horizontal_lines;
adjusted_horizontal_lines(:, [1,3]) = horizontal_lines(:, [1,3]) - offset_x;
adjusted_horizontal_lines(:, [2,4]) = horizontal_lines(:, [2,4]) - offset_y;

[~, sorted_indices] = sortrows(adjusted_horizontal_lines);
adjusted_horizontal_lines = adjusted_horizontal_lines(sorted_indices, :);

% List of x coordinates of intersection points
point_intersec_x = [];
% List of y coordinates of intersection points
point_intersec_y = [];

% DEBUG
figure;
imshow(BW);
hold on;
% =============================================
% 1. Plot delle linee orizzontali e verticali
% =============================================
% Linee orizzontali in blu
for i = 1:size(adjusted_horizontal_lines, 1)
    line = adjusted_horizontal_lines(i,:);
    plot([line(1), line(3)], [line(2), line(4)], 'b-', 'LineWidth', 1.5);
end

% Linee verticali in verde
for i = 1:size(adjusted_vertical_lines, 1)
    line = adjusted_vertical_lines(i,:);
    plot([line(1), line(3)], [line(2), line(4)], 'g-', 'LineWidth', 1.5);
end


% Disegna i cerchi rilevati
viscircles(centers, radii,'EdgeColor','b', 'LineWidth', 2);

intersection_points = [];

for i = 1:num_clusters
    % First line
    line1_p1 = punti_rette(i,1:2);
    line1_p2 = punti_rette(i,3:4);

    % Compute intersection with the first left vertical grid line 
    if i==1
            line2_p1 = adjusted_vertical_lines(i,1:2);
            line2_p2 = adjusted_vertical_lines(i,3:4);
            [intersec_X, intersec_Y] = intersectLines(line1_p1(1), line1_p1(2), line1_p2(1), line1_p2(2), line2_p1(1), line2_p1(2), line2_p2(1), line2_p2(2));
            intersection_points = [intersection_points; intersec_X, intersec_Y, 0, i];
                plot(intersec_X, intersec_Y, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
                % plot(line2_p1(i,1), line2_p1(i,2), 'LineWidth', 2, 'Color', 'blue');
                % plot(line2_p1(i,1), line2_p1(i,2), 'LineWidth', 2, 'Color', 'blue');

    end

    if i ==num_clusters
        break;
    end

    % Check intersections between line1 and the next line
    j = i+1;
    % Second line
    line2_p1 = punti_rette(j,1:2);
    line2_p2 = punti_rette(j,3:4);
    
    [intersec_X, intersec_Y] = intersectLines(line1_p1(1), line1_p1(2), line1_p2(1), line1_p2(2), line2_p1(1), line2_p1(2), line2_p2(1), line2_p2(2));

    if not(isnan(intersec_X) || isnan(intersec_Y))
        intersection_points = [intersection_points; intersec_X, intersec_Y, i, j];
        plot(intersec_X, intersec_Y, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');
    end

end
hold off;
title('Punti di intersezione tra le linee dei cluster');


%% Identificazione dei cerchi vicini o sovrapposti alle intersezioni

% Verifica cerchi agli estremi delle intersezioni
tolerance_intersection = 20; % Tolleranza per cerchi alle intersezioni
max_search_radius = 100; % Raggio massimo di ricerca locale
intersection_circles = [];
fprintf('\n=== VERIFICA CERCHI ALLE INTERSEZIONI ===\n');
for i = 1:size(intersection_points, 1)
    int_x = intersection_points(i, 1);
    int_y = intersection_points(i, 2);
    line1_idx = intersection_points(i, 3);
    line2_idx = intersection_points(i, 4);
    
    [found, circle_idx, dist] = checkCircleAtPosition(int_x, int_y, centers, radii, tolerance_intersection);
    if found
        fprintf('Intersezione %d: CERCHIO TROVATO - Cerchio %d a distanza %.2f\n', i, circle_idx, dist);
        intersection_circles = [intersection_circles; i, circle_idx, dist, int_x, int_y, line1_idx, line2_idx];
    else
        % Ricerca del cerchio più vicino usando knnsearch
        [closest_idx, closest_dist] = knnsearch(centers, [int_x, int_y]);

        % Update the intersection point with the center of the closest circle
        circle_point= centers(closest_idx,:);

        intersection_points(i,:) = [circle_point(1), circle_point(2), intersection_points(i,3), intersection_points(i,4)];

        fprintf('Intersezione %d: Cerchio più vicino %d a distanza %.2f\n', i, closest_idx, closest_dist);
        intersection_circles = [intersection_circles; i, closest_idx, closest_dist, int_x, int_y, line1_idx, line2_idx];
    end
end



% % DEBUG
% % Visualizzazione completa
% figure;
% imshow(BW);
% hold on;
% 
% % Disegna le rette con colori distinti
% colors = hsv(num_clusters);
% for i = 1:num_clusters
%     current_color = colors(i, :);
% 
%     % Linea più spessa se è stata unita
%     line_width =1;
%     if merged_flags(i)
%         line_width =3;
%     else 
%         line_width = 2;
%     end
%     plot(punti_rette(i, [1 3]), punti_rette(i, [2 4]), ...
%         'LineWidth', line_width, 'Color', current_color);
% 
%     % Centroide con marcatore speciale se unito
%     if merged_flags(i)
%         plot(new_centroids(i,1), new_centroids(i,2), ...
%             's', 'MarkerSize', 10, 'MarkerFaceColor', current_color, 'MarkerEdgeColor', 'k', 'LineWidth', 2);
%     else
%         plot(new_centroids(i,1), new_centroids(i,2), ...
%             'o', 'MarkerFaceColor', current_color, 'MarkerEdgeColor', 'k');
%     end
% end
% 
% % Disegna tutti i cerchi in blu chiaro
% viscircles(centers, radii,'EdgeColor',[0.7 0.7 1], 'LineWidth', 1);
% 
% % Evidenzia cerchi trovati nei centroidi
% for i = 1:size(centroid_circles, 1)
%     cluster_idx = centroid_circles(i, 1);
%     circle_idx = centroid_circles(i, 2);
%     center_pos = centers(circle_idx, :);
%     radius = radii(circle_idx);
% 
%     viscircles(center_pos, radius, 'EdgeColor', 'red', 'LineWidth', 3);
%     text(center_pos(1)+radius+5, center_pos(2), sprintf('C%d', cluster_idx), 'Color', 'red', 'FontWeight', 'bold');
% end
% 
% % Evidenzia intersezioni e cerchi associati
% for i = 1:size(intersection_points, 1)
%     int_x = intersection_points(i, 1);
%     int_y = intersection_points(i, 2);
% 
%     % Punto di intersezione
%     plot(int_x, int_y, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'yellow', 'MarkerEdgeColor', 'red', 'LineWidth', 2);
% 
%     % Se c'è un cerchio associato, evidenzialo
%     circle_row = intersection_circles(intersection_circles(:,1) == i, :);
%     if ~isempty(circle_row)
%         circle_idx = circle_row(2);
%         center_pos = centers(circle_idx, :);
%         radius = radii(circle_idx);
% 
%         viscircles(center_pos, radius, 'EdgeColor', 'green', 'LineWidth', 3);
%         plot([int_x, center_pos(1)], [int_y, center_pos(2)], 'g--', 'LineWidth', 1);
%         text(center_pos(1)+radius+5, center_pos(2)-10, sprintf('I%d', i), 'Color', 'green', 'FontWeight', 'bold');
%     end
% end
% 
% hold off;
% title('Analisi completa: Cluster uniti, Centroidi e Intersezioni con Cerchi');
% legend('Rette', 'Centroidi', 'Tutti i cerchi', 'Cerchi nei centroidi', 'Intersezioni', 'Cerchi alle intersezioni', 'Location', 'best');
% 
% % Riepilogo risultati
% fprintf('\n=== RIEPILOGO RISULTATI ===\n');
% fprintf('Cluster totali: %d\n', num_clusters);
% fprintf('Cluster uniti: %d\n', sum(merged_flags));
% fprintf('Cerchi trovati nei centroidi: %d\n', size(centroid_circles, 1));
% fprintf('Intersezioni calcolate: %d\n', size(intersection_points, 1));
% fprintf('Cerchi trovati alle intersezioni: %d\n', size(intersection_circles, 1));
% 

%%



%%



% Funzione per verificare se c'è un cerchio in una posizione specifica
% TODO: da ricontrollare la metrica di valutazione (non è meglio controllare che rientri nella grandezza del raggio ?)
function [found, circle_idx, distance] = checkCircleAtPosition(pos_x, pos_y, centers, radii, tolerance)
    if isempty(centers)
        found = false;
        circle_idx = -1;
        distance = inf;
        return;
    end
    
    distances = sqrt((centers(:,1) - pos_x).^2 + (centers(:,2) - pos_y).^2);
    [min_dist, min_idx] = min(distances);
    
    if min_dist <= tolerance
        found = true;
        circle_idx = min_idx;
        distance = min_dist;
    else
        found = false;
        circle_idx = -1;
        distance = min_dist;
    end
end