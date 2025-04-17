%% 1. Image pre-processing script in MATLAB

clc; clear; close all;

% Load image
img = imread('Noah_01_02_01.jpg');
grayImg = rgb2gray(img);
grayImg = medfilt2(grayImg); % median filter to reduce errors (3 by 3)


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

% if the ocr does not detect the frequency text, then throws an exception
if ocr_frequency_results.Words(1)~="125"
    throw(MException('ocrDetection:firstFrequencyNotFound','OCR is not valid: first frequency axis value has not been detected (125Hz)'));
end
left_lower_boundingBox_first_freq = [ocr_frequency_results.WordBoundingBoxes(1,1), ocr_frequency_results.WordBoundingBoxes(1,2)+ocr_frequency_results.WordBoundingBoxes(1,4)];


% Get the right-lower corner of the last frequency number (16k)
% [x +width, y+height]
%Note : this is used as a double check to be completely sure that the
%points are valid

% % if the ocr does not detect the frequency text, then throws an exception
% if ocr_frequency_results.Words(end)~="16k"
%     throw(MException('ocrDetection:lastFrequencyNotFound','OCR is not valid: last frequency axis value has not been detected (16kHz)'));
% end
right_lower_boundingBox_last_freq = [ocr_frequency_results.WordBoundingBoxes(end,1)+ocr_frequency_results.WordBoundingBoxes(end,3), ocr_frequency_results.WordBoundingBoxes(end,2)+ocr_frequency_results.WordBoundingBoxes(end,4)];

% Get the right-upper corner of the first decibel number (-10)
% [x+weight , y]

% if the ocr does not detect the decibel text, then throws an exception
if ocr_decibel_results.Words(1)~="-10"
    throw(MException('ocrDetection:firstDecibelNotFound','OCR is not valid: first decibel axis value has not been detected (-10db)'));
end
right_upper_boundingBox_first_dec = [ocr_decibel_results.WordBoundingBoxes(1,1)+ocr_decibel_results.WordBoundingBoxes(1,3), ocr_decibel_results.WordBoundingBoxes(1,2)];

% Get the right-lower corner of the last decibel number (120)
% [x +width, y+height]
%Note : this is used as a double check to be completely sure that the
%points are valid

% % if the ocr does not detect the decibel text, then throws an exception
% if ocr_decibel_results.Words(end)~="120"
%     throw(MException('ocrDetection:lastDecibelNotFound','OCR is not valid: last decibel axis value has not been detected (120db)'));
% end
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

%% DEBUG
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

% DEGUB
figure, imshow(grayImg), hold on;

plot(intersectionPoints(:,1), intersectionPoints(:,2), 'ro', 'MarkerSize', 3, 'LineWidth', 1);

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
idx = find(intersectionPoints(:,2) <= grid_corner_lines(1).point1(2));
freq_points = sortrows(intersectionPoints(idx,:));
if size(freq_points,1) ~= 13
    throw(MException('sizeError:Error','The number of points is not sufficient'));
end

% Create a vector of indices
indices = 1:size(freq_points,1);

% Keep points where index is odd OR index is == 2
keep_indices = mod(indices, 2) ~= 0 | indices == 2;

% Apply the filter to get the filtered freq_points
freq_points = freq_points(keep_indices, :);


% Initialize array to store OCR results
ocr_results = cell(size(freq_points,1), 1);



% Process OCR for each point in freq_points
for i = 1:size(freq_points,1)
    % Calculate bounding points for OCR area
    if i == 1
        % For the first point, use the original approach since there's no previous point
        a = abs(freq_points(i,1) - 1) / 2;
    else
        % For other points, calculate 'a' based on the difference with the previous point
        a = abs(freq_points(i,1) - freq_points(i-1,1)) / 2;
    end
    
    point1 = [freq_points(i,1) - a, freq_points(i,2)];
    point2 = [freq_points(i,1) + a, freq_points(i,2)];
    
    % Define rectangular area for OCR
    % [x, y, width, height]

    width_ocr_area=point1(1)+(point2(1) - point1(1));
    if width_ocr_area>img_max_height
        width_ocr_area=img_max_width-point1(1)-1;
    end
    ocr_area = [point1(1), 1, width_ocr_area, point1(2) - 1];
    
    % Perform OCR
    ocr_results{i} = ocr(img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "0124568k");

end

% TODO: Decibel ax






