%% 1. Image pre-processing script in MATLAB

clc; clear; close all;

% Load image
img = imread('Noah_01_01_02.jpg');
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
% % DEGUB
% figure, imshow(grayImg), hold on;
% 
% plot(intersectionPoints(:,1), intersectionPoints(:,2), 'ro', 'MarkerSize', 4, 'LineWidth', 1);
% 
% title('Grid intersection points');
% 
% 
% for i = 1:length(grid_corner_lines)
%     % Punto 1 della linea
%     x_pt1 = grid_corner_lines(i).point1(1);
%     y_pt1 = grid_corner_lines(i).point1(2);
%     plot(x_pt1, y_pt1, 'bs', 'MarkerSize', 4, 'LineWidth', 1);    
%     % Punto 2 della linea
%     x_pt2 = grid_corner_lines(i).point2(1);
%     y_pt2 = grid_corner_lines(i).point2(2);
%     plot(x_pt2, y_pt2, 'bs', 'MarkerSize', 4, 'LineWidth', 1);
% end

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
close all;

x = max(refined_grid_points(1,1), refined_grid_points(3,1));
y = max(refined_grid_points(1,2), refined_grid_points(2,2));
cropped_img = imcrop (grayImg, [x,y,refined_grid_points(2,1)- x, refined_grid_points(3,2)-y]);

filtered_img = imadjust(cropped_img);

% Apply the Canny operator to obtain the binary edge map
BW = edge(filtered_img, 'Canny');

BW = imdilate(BW, strel('line',3,0)) | imdilate(BW,strel('line',3,90));

BW = imdilate(BW, strel("rectangle",[2 6])); % square = 2 non va bene per alcune immagini con O
% Da testare una via di mezzo che vadi bene per tutti, tipo un disk o
% diamond

% BW= bwmorph(BW,'skeleton');
BW = bwskel(BW);

% nhood_size = floor(size(H)/25) * 2 + 1; % Dimensione dell'intorno più piccola
figure ; imshow(BW);
% Compute the Hough Transform
[H, theta, rho] = hough(BW,'Theta',-85:-5);

threshold = ceil(0.6 * max(H(:))); % Soglia più bassa per includere picchi meno prominenti

peaks = houghpeaks(H, 60,'Theta',-85:-5,'Threshold',threshold); % 40 for the maximum possible measurement case
% Extract the detected lines based on the found peaks
lines1 = houghlines(BW, theta, rho, peaks,"MinLength",50,"FillGap",20);

[H, theta, rho] = hough(BW,'Theta',5:85);
threshold = ceil(0.6 * max(H(:))); % Soglia più bassa per includere picchi meno prominenti

peaks = houghpeaks(H, 60,'Theta',5:85,'Threshold',threshold);
% Extract the detected lines based on the found peaks
lines2 = houghlines(BW, theta, rho, peaks,"MinLength",50,"FillGap",20);

% all_lines = [lines1 lines2];
% % Calculate centroids for all detected lines
% centroids = zeros(length(all_lines), 2);
% thetas = zeros(length(all_lines), 1);
% rhos = zeros(length(all_lines), 1);
% 
% for k = 1:length(all_lines)
%     % Calculate midpoint of each line
%     pt1 = all_lines(k).point1;
%     pt2 = all_lines(k).point2;
%     centroids(k,:) = [(pt1(1) + pt2(1))/2, (pt1(2) + pt2(2))/2];
% 
%     % Store theta and rho values
%     thetas(k) = all_lines(k).theta;
%     rhos(k) = all_lines(k).rho;
% end
% 
% 
% 




%% Recognizing the segments ( by identify the cluster with BDSCAN)

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
epsilon = 0.3; % Epsilon per dati normalizzati (0-1)

% Confronta diverse configurazioni di DBSCAN
% Test con minPts = 1
minPts1 = 1;
idx1 = dbscan(data_norm, epsilon, minPts1);
num_clusters1 = max(idx1);
noise_points1 = sum(idx1 == -1);

% Test con minPts = 2
minPts2 = 2;
idx2 = dbscan(data_norm, epsilon, minPts2);
num_clusters2 = max(idx2);
noise_points2 = sum(idx2 == -1);

% Calcola metriche di valutazione
silhouette_scores = zeros(2, 1);

% Silhouette score per minPts = 1 (se ci sono almeno 2 cluster)
if num_clusters1 > 1
    valid_points = idx1 ~= -1;
    if sum(valid_points) > 0 && length(unique(idx1(valid_points))) > 1
        try
            silhouette_scores(1) = mean(silhouette(data_norm(valid_points,:), idx1(valid_points)));
        catch
            silhouette_scores(1) = NaN;
            disp('Impossibile calcolare Silhouette per minPts=1');
        end
    else
        silhouette_scores(1) = NaN;
    end
else
    silhouette_scores(1) = NaN;
end

% Silhouette score per minPts = 2 (se ci sono almeno 2 cluster)
if num_clusters2 > 1
    valid_points = idx2 ~= -1;
    if sum(valid_points) > 0 && length(unique(idx2(valid_points))) > 1
        try
            silhouette_scores(2) = mean(silhouette(data_norm(valid_points,:), idx2(valid_points)));
        catch
            silhouette_scores(2) = NaN;
            disp('Impossibile calcolare Silhouette per minPts=2');
        end
    else
        silhouette_scores(2) = NaN;
    end
else
    silhouette_scores(2) = NaN;
end

% Visualizza i risultati di confronto
fprintf('Valutazione dei cluster:\n');
fprintf('minPts=1: %d cluster, %d punti rumore, Silhouette=%.4f\n', ...
        num_clusters1, noise_points1, silhouette_scores(1));
fprintf('minPts=2: %d cluster, %d punti rumore, Silhouette=%.4f\n', ...
        num_clusters2, noise_points2, silhouette_scores(2));

% Davies-Bouldin Index (più basso è meglio)
if num_clusters1 > 1
    valid_points = idx1 ~= -1;
    if sum(valid_points) > 0 && length(unique(idx1(valid_points))) > 1
        try
            db_index1 = evalclusters(data_norm(valid_points,:), idx1(valid_points), 'DaviesBouldin').CriterionValues;
            fprintf('Davies-Bouldin Index (minPts=1): %.4f\n', db_index1);
        catch
            fprintf('Impossibile calcolare Davies-Bouldin per minPts=1\n');
        end
    end
end

if num_clusters2 > 1
    valid_points = idx2 ~= -1;
    if sum(valid_points) > 0 && length(unique(idx2(valid_points))) > 1
        try
            db_index2 = evalclusters(data_norm(valid_points,:), idx2(valid_points), 'DaviesBouldin').CriterionValues;
            fprintf('Davies-Bouldin Index (minPts=2): %.4f\n', db_index2);
        catch
            fprintf('Impossibile calcolare Davies-Bouldin per minPts=2\n');
        end
    end
end

% Visualizzazione dei risultati di clustering

% Impostazione colori per visualizzazione
colors1 = hsv(num_clusters1);
colors2 = hsv(num_clusters2);

% Visualizzazione dei cluster con minPts=1
figure;
subplot(1,2,1);
imshow(BW);
hold on;
title(['Clustering con minPts=1: ', num2str(num_clusters1), ' cluster']);

for k = 1:length(all_lines)
    if idx1(k) > 0  % Escludi punti rumore (-1)
        cluster_color = colors1(idx1(k),:);
        xy = [all_lines(k).point1; all_lines(k).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', cluster_color);
        % Visualizza i centroidi
        plot(centroids(k,1), centroids(k,2), 'o', 'MarkerSize', 6, ...
             'MarkerEdgeColor', cluster_color, 'MarkerFaceColor', cluster_color);
    else
        % Punti rumore in grigio
        xy = [all_lines(k).point1; all_lines(k).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 1, 'Color', [0.7 0.7 0.7]);
    end
end
hold off;

% Visualizzazione dei cluster con minPts=2
subplot(1,2,2);
imshow(BW);
hold on;
title(['Clustering con minPts=2: ', num2str(num_clusters2), ' cluster']);

for k = 1:length(all_lines)
    if idx2(k) > 0  % Escludi punti rumore (-1)
        cluster_color = colors2(idx2(k),:);
        xy = [all_lines(k).point1; all_lines(k).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', cluster_color);
        % Visualizza i centroidi
        plot(centroids(k,1), centroids(k,2), 'o', 'MarkerSize', 6, ...
             'MarkerEdgeColor', cluster_color, 'MarkerFaceColor', cluster_color);
    else
        % Punti rumore in grigio
        xy = [all_lines(k).point1; all_lines(k).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 1, 'Color', [0.7 0.7 0.7]);
    end
end
hold off;

% Visualizzazione dello spazio delle caratteristiche
figure;
subplot(1,2,1);
scatter3(centroid_x_norm, centroid_y_norm, thetas_norm, 50, idx1, 'filled');
title('Spazio delle caratteristiche (minPts=1)');
xlabel('Centroide X (norm)');
ylabel('Centroide Y (norm)');
zlabel('Theta (norm)');
colormap(jet);
colorbar;

subplot(1,2,2);
scatter3(centroid_x_norm, centroid_y_norm, thetas_norm, 50, idx2, 'filled');
title('Spazio delle caratteristiche (minPts=2)');
xlabel('Centroide X (norm)');
ylabel('Centroide Y (norm)');
zlabel('Theta (norm)');
colormap(jet);
colorbar;

% Calcolo statistiche intra-cluster per valutare la coerenza
% Calcola statistiche per ogni cluster (deviazione standard delle caratteristiche)

% Per minPts=1
cluster_stats1 = struct('mean_theta', {}, 'std_theta', {}, 'mean_rho', {}, 'std_rho', {}, 'size', {});
for i = 1:num_clusters1
    cluster_idx = find(idx1 == i);
    cluster_stats1(i).mean_theta = mean(thetas(cluster_idx));
    cluster_stats1(i).std_theta = std(thetas(cluster_idx));
    cluster_stats1(i).mean_rho = mean(rhos(cluster_idx));
    cluster_stats1(i).std_rho = std(rhos(cluster_idx));
    cluster_stats1(i).size = length(cluster_idx);
end

% Per minPts=2
cluster_stats2 = struct('mean_theta', {}, 'std_theta', {}, 'mean_rho', {}, 'std_rho', {}, 'size', {});
for i = 1:num_clusters2
    cluster_idx = find(idx2 == i);
    cluster_stats2(i).mean_theta = mean(thetas(cluster_idx));
    cluster_stats2(i).std_theta = std(thetas(cluster_idx));
    cluster_stats2(i).mean_rho = mean(rhos(cluster_idx));
    cluster_stats2(i).std_rho = std(rhos(cluster_idx));
    cluster_stats2(i).size = length(cluster_idx);
end

% Visualizza statistiche dei cluster
fprintf('\nStatistiche dei cluster con minPts=1:\n');
for i = 1:num_clusters1
    fprintf('Cluster %d (size=%d): mean_theta=%.2f°, std_theta=%.2f°, mean_rho=%.2f, std_rho=%.2f\n', ...
            i, cluster_stats1(i).size, cluster_stats1(i).mean_theta, cluster_stats1(i).std_theta, ...
            cluster_stats1(i).mean_rho, cluster_stats1(i).std_rho);
end

fprintf('\nStatistiche dei cluster con minPts=2:\n');
for i = 1:num_clusters2
    fprintf('Cluster %d (size=%d): mean_theta=%.2f°, std_theta=%.2f°, mean_rho=%.2f, std_rho=%.2f\n', ...
            i, cluster_stats2(i).size, cluster_stats2(i).mean_theta, cluster_stats2(i).std_theta, ...
            cluster_stats2(i).mean_rho, cluster_stats2(i).std_rho);
end

% Calcola coerenza media dei cluster (media delle deviazioni standard normalizzate)
% Un valore più basso indica cluster più coerenti
if num_clusters1 > 0
    std_thetas1 = arrayfun(@(x) x.std_theta, cluster_stats1);
    std_rhos1 = arrayfun(@(x) x.std_rho, cluster_stats1);
    cluster_sizes1 = arrayfun(@(x) x.size, cluster_stats1);
    
    % Media ponderata delle deviazioni standard
    coherence1 = sum((std_thetas1 ./ max(thetas) + std_rhos1 ./ max(rhos)) .* cluster_sizes1) / sum(cluster_sizes1);
    fprintf('\nCoerenza media dei cluster (minPts=1): %.4f (più basso è meglio)\n', coherence1);
end

if num_clusters2 > 0
    std_thetas2 = arrayfun(@(x) x.std_theta, cluster_stats2);
    std_rhos2 = arrayfun(@(x) x.std_rho, cluster_stats2);
    cluster_sizes2 = arrayfun(@(x) x.size, cluster_stats2);
    
    % Media ponderata delle deviazioni standard
    coherence2 = sum((std_thetas2 ./ max(thetas) + std_rhos2 ./ max(rhos)) .* cluster_sizes2) / sum(cluster_sizes2);
    fprintf('Coerenza media dei cluster (minPts=2): %.4f (più basso è meglio)\n', coherence2);
end

% Plot finale dei cluster individuati con rappresentazione dell'immagine originale
figure('Name', 'Confronto dei Cluster individuati', 'Position', [100, 100, 1200, 600]);

% Subplot per minPts=1
subplot(1, 2, 1);
imshow(cropped_img); % Mostra l'immagine originale crop
hold on;
title(['Cluster individuati con minPts=1 (', num2str(num_clusters1), ' cluster)'], 'FontSize', 12);

% Disegna ogni cluster con un colore diverso
for i = 1:num_clusters1
    cluster_lines = find(idx1 == i);
    cluster_color = colors1(i,:);
    
    % Disegna tutte le linee appartenenti al cluster
    for j = 1:length(cluster_lines)
        line_idx = cluster_lines(j);
        xy = [all_lines(line_idx).point1; all_lines(line_idx).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 3, 'Color', cluster_color);
    end
    
    % Aggiungi un'etichetta per il cluster
    cluster_center_x = mean(centroids(cluster_lines,1));
    cluster_center_y = mean(centroids(cluster_lines,2));
    text(cluster_center_x, cluster_center_y, num2str(i), ...
         'FontSize', 14, 'FontWeight', 'bold', 'Color', 'white', ...
         'BackgroundColor', cluster_color, 'HorizontalAlignment', 'center');
end

% Disegna i punti rumore in grigio
noise_lines = find(idx1 == -1);
for j = 1:length(noise_lines)
    line_idx = noise_lines(j);
    xy = [all_lines(line_idx).point1; all_lines(line_idx).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 1, 'Color', [0.7 0.7 0.7], 'LineStyle', '--');
end
hold off;

% Subplot per minPts=2
subplot(1, 2, 2);
imshow(cropped_img); % Mostra l'immagine originale crop
hold on;
title(['Cluster individuati con minPts=2 (', num2str(num_clusters2), ' cluster)'], 'FontSize', 12);

% Disegna ogni cluster con un colore diverso
for i = 1:num_clusters2
    cluster_lines = find(idx2 == i);
    cluster_color = colors2(i,:);
    
    % Disegna tutte le linee appartenenti al cluster
    for j = 1:length(cluster_lines)
        line_idx = cluster_lines(j);
        xy = [all_lines(line_idx).point1; all_lines(line_idx).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 3, 'Color', cluster_color);
    end
    
    % Aggiungi un'etichetta per il cluster
    cluster_center_x = mean(centroids(cluster_lines,1));
    cluster_center_y = mean(centroids(cluster_lines,2));
    text(cluster_center_x, cluster_center_y, num2str(i), ...
         'FontSize', 14, 'FontWeight', 'bold', 'Color', 'white', ...
         'BackgroundColor', cluster_color, 'HorizontalAlignment', 'center');
end

% Disegna i punti rumore in grigio
noise_lines = find(idx2 == -1);
for j = 1:length(noise_lines)
    line_idx = noise_lines(j);
    xy = [all_lines(line_idx).point1; all_lines(line_idx).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 1, 'Color', [0.7 0.7 0.7], 'LineStyle', '--');
end
hold off;

%% Plot dei cluster nel piano theta-rho
figure('Name', 'Rappresentazione dei Cluster nello spazio theta-rho', 'Position', [100, 100, 1200, 600]);

% Subplot per minPts=1 nel piano theta-rho
subplot(1, 2, 1);
hold on;
title(['Cluster in spazio theta-rho con minPts=1 (', num2str(num_clusters1), ' cluster)'], 'FontSize', 12);
grid on;

% Disegna ogni cluster con un colore diverso
for i = 1:num_clusters1
    cluster_points = find(idx1 == i);
    cluster_color = colors1(i,:);
    scatter(thetas(cluster_points), rhos(cluster_points), 100, 'filled', ...
            'MarkerFaceColor', cluster_color, 'MarkerEdgeColor', 'black');
    
    % Aggiungi etichetta del cluster
    cluster_center_theta = mean(thetas(cluster_points));
    cluster_center_rho = mean(rhos(cluster_points));
    text(cluster_center_theta, cluster_center_rho, num2str(i), ...
         'FontSize', 14, 'FontWeight', 'bold', 'Color', 'black', ...
         'HorizontalAlignment', 'center');
end

% Disegna i punti rumore in grigio
noise_points = find(idx1 == -1);
if ~isempty(noise_points)
    scatter(thetas(noise_points), rhos(noise_points), 50, 'filled', ...
            'MarkerFaceColor', [0.7 0.7 0.7], 'MarkerEdgeColor', 'black', 'Marker', 'x');
end

xlabel('\theta [gradi]', 'FontSize', 12);
ylabel('\rho', 'FontSize', 12);
hold off;

% Subplot per minPts=2 nel piano theta-rho
subplot(1, 2, 2);
hold on;
title(['Cluster in spazio theta-rho con minPts=2 (', num2str(num_clusters2), ' cluster)'], 'FontSize', 12);
grid on;

% Disegna ogni cluster con un colore diverso
for i = 1:num_clusters2
    cluster_points = find(idx2 == i);
    cluster_color = colors2(i,:);
    scatter(thetas(cluster_points), rhos(cluster_points), 100, 'filled', ...
            'MarkerFaceColor', cluster_color, 'MarkerEdgeColor', 'black');
    
    % Aggiungi etichetta del cluster
    cluster_center_theta = mean(thetas(cluster_points));
    cluster_center_rho = mean(rhos(cluster_points));
    text(cluster_center_theta, cluster_center_rho, num2str(i), ...
         'FontSize', 14, 'FontWeight', 'bold', 'Color', 'black', ...
         'HorizontalAlignment', 'center');
end

% Disegna i punti rumore in grigio
noise_points = find(idx2 == -1);
if ~isempty(noise_points)
    scatter(thetas(noise_points), rhos(noise_points), 50, 'filled', ...
            'MarkerFaceColor', [0.7 0.7 0.7], 'MarkerEdgeColor', 'black', 'Marker', 'x');
end

xlabel('\theta [gradi]', 'FontSize', 12);
ylabel('\rho', 'FontSize', 12);
hold off;


% Visualization of clustered lines
figure;
imshow(BW);
hold on;

% Define a colormap for different clusters
colors = hsv(max(idx));

for k = 1:length(all_lines)
    if idx(k) > 0 % Exclude noise points (-1)
        xy = [all_lines(k).point1; all_lines(k).point2];
        plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', colors(idx(k),:));
        % Plot centroids
        plot(centroids(k,1), centroids(k,2), 'o', 'MarkerSize', 8, ...
             'MarkerEdgeColor', colors(idx(k),:), 'MarkerFaceColor', colors(idx(k),:));
    end
end

title('Line Clusters based on Centroids and Parameters');
hold off;

 %%

% %% 
% % 1. Caricamento e preprocessing
% close all;
% % 1) Soglia e crea la maschera logica
% BW = bwareaopen(BW, 10); % rimuove piccoli "punti" di area < 5 px (opzionale)
% % BW = imdilate(BW, strel("disk",6));
% BW = bwskel(BW);
% 
% BW = BW & ~bwmorph(BW,'branchpoints');
% BW = bwmorph(BW,'spur');
% 
% figure; imshow(BW);
% 
% % 2) Calcolo delle proprietà dei blob originali
% original_stats = regionprops(BW, 'Centroid', 'Area', 'Orientation', "ConvexHull", "Eccentricity", "Solidity", "Circularity", "ConvexArea");
% 
% % Estrai tutti i valori di ConvexArea
% convexAreas = [original_stats.ConvexArea];
% 
% % Trova gli indici di quelli che sono almeno 10, exclude 
% valid_idx = convexAreas < 10;
% 
% % Costruisci un nuovo array di struct con solo i blob validi
% filtered_stats = original_stats(valid_idx);
% 
% filtered_centroids = cat(1, filtered_stats.Centroid);
% 
% % Visualizza
% figure;
% imshow(BW, []), hold on
% plot(filtered_centroids(:,1), filtered_centroids(:,2), 'go', ...
%      'MarkerSize', 10, 'LineWidth', 1.5)
% hold off
% title('Centroidi con ConvexArea >= 10');
% 
% % Centroidi in Nx2
% C = filtered_centroids;  
% 
% % Parametri di DBSCAN
% epsilon = 30;   % raggio di vicinanza
% minPts  = 2;    % numero minimo di punti per considerare un cluster
% 
% % clusterIdx: 1,2,3,... per i cluster; -1 per i rumori (punti isolati)
% [clusterIdx,corepts] = dbscan(C, epsilon, minPts);
% 
% % Trova i cluster numerati (escludendo il rumore = -1)
% uc = unique(clusterIdx);
% uc(uc==-1) = [];
% nClusters = numel(uc);
% 
% 
% % Dopo aver eseguito DBSCAN e identificato i cluster
% figure; imshow(BW, []); hold on
% 
% % Prepara una mappa di colori
% colors = lines(nClusters);
% 
% % Inizializza un array per memorizzare i centroidi dei cluster
% cluster_centroids = zeros(nClusters, 2);
% 
% % Plot dei cluster e calcolo dei loro centroidi
% for i = 1:nClusters
%     k = uc(i);
%     pts = C(clusterIdx==k, :);
% 
%     % Calcola il centroide del cluster come media dei punti
%     cluster_centroid = mean(pts, 1);
%     cluster_centroids(i,:) = cluster_centroid;
% 
%     % Plot dei punti del cluster
%     plot(pts(:,1), pts(:,2),  'o', ...
% 'MarkerSize', 10, 'LineWidth', 1.5);
% 
%     % Plot del centroide del cluster con un marker diverso e più grande
%     plot(cluster_centroid(1), cluster_centroid(2), 'yo', ...
% 'MarkerSize', 10, 'LineWidth', 1.5);
% end
% 
% 
% title('Distribuzione dei centroidi per cluster con centroidi dei cluster')
% hold off
% 
% figure; imshow(cropped_img); hold on; 
% plot(cluster_centroids(:,1), cluster_centroids(:,2), 'yo', ...
% 'MarkerSize', 10, 'LineWidth', 1.5);
% hold off;


%%




% 
% % 7) Visualizza solo i ConvexHull filtrati
% figure;
% imshow(BW);
% hold on;
% for k = valid_hulls
%     hull = hull_stats(k).ConvexHull;
%     plot(hull(:,1), hull(:,2), 'g-', 'LineWidth', 2);
%     patch(hull(:,1), hull(:,2), 'g', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
% 
%     % Mostra anche i centroidi dei ConvexHull validi
%     plot(hull_stats(k).Centroid(1), hull_stats(k).Centroid(2), 'r+', 'MarkerSize', 10, 'LineWidth', 2);
% 
%     % Etichetta ogni ConvexHull
%     text(hull_stats(k).Centroid(1), hull_stats(k).Centroid(2) + 15, ...
%         sprintf('%d', k), 'Color', 'y', 'FontSize', 12, 'FontWeight', 'bold', ...
%         'HorizontalAlignment', 'center');
% end
% hold off;
% title('ConvexHull filtrati per Eccentricità, Circolarità e Area');
% 
% % 8) Stampa le proprietà dei ConvexHull validi
% fprintf('Proprietà dei ConvexHull validi:\n');
% fprintf('ID\tArea\tConvexArea\tSolidity\tEccentricity\tCircularity\tOrientation\n');
% fprintf('--\t----\t----------\t--------\t-----------\t-----------\t----------\n');
% for k = valid_hulls
%     fprintf('%d\t%.1f\t%.1f\t\t%.3f\t\t%.3f\t\t%.3f\t\t%.1f\n', ...
%         k, hull_stats(k).Area, hull_stats(k).ConvexArea, hull_stats(k).Solidity, ...
%         hull_stats(k).Eccentricity, hull_stats(k).Circularity, hull_stats(k).Orientation);
% end
% 
% % 9) Crea una maschera finale che include solo le regioni ConvexHull valide
% final_mask = false(size(BW));
% for k = valid_hulls
%     hull = hull_stats(k).ConvexHull;
%     hull_poly = polyshape(hull(:,1), hull(:,2));
%     [y, x] = meshgrid(1:size(BW,2), 1:size(BW,1));
%     in_poly = isinterior(hull_poly, y(:), x(:));
%     final_mask(in_poly) = true;
% end
% 
% % Visualizza la maschera finale
% figure;
% imshow(final_mask);
% title('Maschera finale con solo i ConvexHull validi');
% 
% % Opzionale: applica la maschera finale all'immagine originale per isolare le regioni di interesse
% filtered_result = BW & final_mask;
% figure;
% imshow(filtered_result);
% title('Risultato finale: solo le regioni di interesse');

%%
%  % 1) Estrai i punti dell'immagine originale che appartengono alle regioni valide
% [filtered_y, filtered_x] = find(BW & final_mask);
% filtered_points = [filtered_x, filtered_y];  % Matrice Nx2 di coordinate [x,y]
% 
% % 2) Applica K-means solo a questi punti filtrati
% k = 8;  % Numero di cluster desiderato - modificalo in base alle tue esigenze
% [idxK, C_kmeans] = kmeans(filtered_points, k, 'Replicates', 5, 'Distance', 'sqeuclidean');
% 
% % 3) Visualizza i risultati
% figure;
% imshow(filtered_img, []);
% hold on;
% 
% % Centroidi originali (prima del filtro) - in giallo
% plot(centroids(:,1), centroids(:,2), 'yo', 'MarkerSize', 6, 'LineWidth', 1);
% 
% % ConvexHull validi - in verde trasparente
% for i = valid_hulls
%     hull = hull_stats(i).ConvexHull;
%     patch(hull(:,1), hull(:,2), 'g', 'FaceAlpha', 0.2, 'EdgeColor', 'g', 'LineWidth', 1);
% end
% 
% % Centri dei cluster K-means - in rosso
% plot(C_kmeans(:,1), C_kmeans(:,2), 'r*', 'MarkerSize', 12, 'LineWidth', 2);
% 
% % % 4) Visualizza i punti colorati in base al cluster a cui appartengono
% % colors = hsv(k);  % Genera una palette di colori per i cluster
% % for i = 1:k
% %     cluster_points = filtered_points(idxK == i, :);
% %     plot(cluster_points(:,1), cluster_points(:,2), '.', 'Color', colors(i,:), 'MarkerSize', 10);
% % 
% %     % Opzionale: aggiungi etichette ai centri dei cluster
% %     text(C_kmeans(i,1), C_kmeans(i,2) - 15, sprintf('C%d', i), ...
% %         'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold', ...
% %         'HorizontalAlignment', 'center', 'BackgroundColor', [0 0 0 0.5]);
% % end
% 
% hold off;
% title('K-means applicato alle regioni filtrate');



% k = 8;  % esempio: tre gruppi; modificalo o calcolalo dinamicamente
%     [idxK, C_kmeans] = kmeans(centroids, k, ...
%                               'Replicates', 5, ...
%                               'Distance',   'sqeuclidean');

% % 7) Rimuovo i centroidi troppo isolati
% D = pdist2(centroids, centroids);      % matrice distanze
% D(1:size(D,1)+1:end) = inf;           % ignoro distanza zero su diagonale
% minDist = min(D, [], 2);              % distanza al vicino più prossimo
% 
% dThresh = 15;                         % soglia in pixel (regola a piacere)
% keepIdx = minDist > dThresh;         % true per i centroidi >vicini” ad almeno un altro
% filteredC = centroids(keepIdx, :);
% 
% % 8) Raggruppamento via k-means
% % (scegli k in base a quante regioni ti aspetti o in funzione di filteredC)
% if size(filteredC,1) > 1
%     k = 8;  % esempio: tre gruppi; modificalo o calcolalo dinamicamente
%     [idxK, C_kmeans] = kmeans(filteredC, k, ...
%                               'Replicates', 5, ...
%                               'Distance',   'sqeuclidean');
% else
%     C_kmeans = filteredC;  % troppo pochi punti: nessun clustering
% end

% % 9) Visualizzo tutti i passi
% figure; imshow(filtered_img, []); hold on
% 
%   % centroidi iniziali (prima del filtro) – in giallo
%   plot(centroids(:,1), centroids(:,2), ...
%        'yo', 'MarkerSize', 6, 'LineWidth', 1)
% 
%   % centroidi “vicini” sopravvissuti al filtro – in blu
%   % plot(filteredC(:,1), filteredC(:,2), ...
%   %      'bs', 'MarkerSize', 8, 'LineWidth', 1.5)
% 
%   % centri finali dei cluster k-means – in verde
%   plot(C_kmeans(:,1), C_kmeans(:,2), ...
%        'g*', 'MarkerSize', 12, 'LineWidth', 2)
% hold off
% title('pixel>40 (rosso), tutti i centroidi (giallo), filtrati (blu), kmeans (verde)');




% %% ALTRO APPROCCIo FUNZIONANTE, DA MIGLIORARE MA OK
% % Optimal approach for X exams
%  close all;
% [centers, radii, metric] = imfindcircles(BW, [10 40], ...
%     'Sensitivity', 0.95, 'ObjectPolarity', 'bright',"Method","TwoStage");
% k = 8; 
% [idxK, C_kmeans] = kmeans(centers, k, ...
%                               'Replicates', 5, ...
%                               'Distance',   'sqeuclidean');
% 
% 
% % % TODO: Optimal approach for O exams
% % [centers, radii, metric] = imfindcircles(filtered_img, [10 40], ...
% %     'Sensitivity', 0.95, 'ObjectPolarity', 'dark');
% % k = 7; 
% % [idxK, C_kmeans] = kmeans(centers, k, ...
% %                               'Replicates', 5, ...
% %                               'Distance',   'sqeuclidean');
% 
% 
% 
% % 3. Visualizzo
% figure;
% imshow(filtered_img,[]), hold on
% viscircles(centers, radii,'EdgeColor','y');
% % plot(centers(:,1), centers(:,2), 'r+');
%  % centri finali dei cluster k-means – in verde
%   plot(C_kmeans(:,1), C_kmeans(:,2), ...
%        'g*', 'MarkerSize', 12, 'LineWidth', 2)
% 
% % Numero di cerchi trovati
% N = size(centers, 1);
% 
% % 2. Preparo i rettangoli [x y w h] e croppo i patch
% rects = zeros(N, 4);
% patches = cell(N, 1);
% variances = zeros(N, 1);
% for i = 1:N
%     xC = centers(i, 1);
%     yC = centers(i, 2);
%     r = radii(i);
%     % Rettangolo centrato sul cerchio
%     x = round(xC - r);
%     y = round(yC - r);
%     w = round(2*r);
%     h = round(2*r);
%     rects(i, :) = [x, y, w, h];
%     patches{i} = imcrop(filtered_img, rects(i, :));
%     % Calcola la varianza del patch
%     variances(i) = var(double(patches{i}(:)));
% 
%     % Colora il rettangolo in base alla varianza (rosso = alta varianza)
%     rectangle('Position', rects(i,:), 'EdgeColor', 'r', 'LineWidth', 2);
% 
% 
% end
%  hold off;
% 
% % 4. Filtro i cerchi in base alla varianza
% % Determina una soglia di varianza per distinguere aree di interesse
% threshold = mean(variances); % Puoi aggiustare questo valore
% valid_idx = variances < threshold;
% 
% % Visualizza solo i cerchi validi
% figure;
% imshow(filtered_img);
% hold on;
% viscircles(centers(valid_idx,:), radii(valid_idx), 'EdgeColor', 'g');
% title('Cerchi selezionati dopo filtro varianza');
% hold off;
% 
% % Estrai i centroidi finali
% final_centers = centers(valid_idx,:);

% T = adaptthresh(filtered_img, 0.95, 'ForegroundPolarity','dark');
% BW = imbinarize(filtered_img, T);
% % 2. Pulisci con apertura
% 
% % filtered_img=imdilate(BW,strel("square",2 ));
% 
% se = strel('square',2);
% filtered_img = imopen(filtered_img, se);


% filtered_img = imcomplement(filtered_img);
% filtered_img = edge(filtered_img, 'Canny',[0.12 0.15]);
% 
% filtered_img=imdilate(filtered_img,strel("square",2 ));

% filtered_img = imerode(filtered_img,strel("diamond",4));

% filled_img = imfill(filtered_img, 'holes');

% filtered_img = imclose (filtered_img,strel("disk",5));


% filtered_img = bwareaopen (filtered_img,15);



% stats = regionprops(filtered_img, 'Centroid', 'Area');
% areas = [stats.Area];
% valid_idx = find(areas > 100 & areas < 200); % Esclude rumore e sfondo
% centroids = vertcat(stats(valid_idx).Centroid);
% hold on;
% % plot(centroids(:,1), centroids(:,2), 'r+', 'MarkerSize', 20, 'LineWidth', 2);
% title('Centroidi delle aree rilevate', 'FontSize', 14);


% 
% %% 2. Binarizzazione e pulizia
% % Binarizza l'immagine (soglia adattiva)
% % binary_img = imcomplement(bin_img); % Inverti se le "X" sono scure
% 
% % Operazioni morfologiche
% cleaned_img = bwareaopen(bin_img, 30); % Rimuovi oggetti <30 pixel
% se = strel('disk', 2);
% cleaned_img = imdilate(cleaned_img, se); % Rafforza le forme
