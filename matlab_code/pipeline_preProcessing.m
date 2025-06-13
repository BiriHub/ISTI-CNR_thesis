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


% % DEBUG x hough result
% figure;
% imshow(img);
% hold on;
% for k = 1:length(lines)
% xy = [lines(k).point1; lines(k).point2];
% plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
% % Display the starting and ending points of the lines
% plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
% plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
% end
% title('Filtered Lines detected with the Hough Transform');
% hold off;

%%
% Filter all lines that are not neither horizontal nor vertical according
% to a threshold

max_num_horiz_lines = 16;
max_num_vert_lines  = 15;

filteredLines = [];
angleThreshold = 2; % angle threshold

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
        % Adjust x-coord with the difference between the right grid corner
        % coordinates
        lines(i).point2(1) = lines(i).point2(1) + (abs(lines(i).point2(1)-min(grid_corner_lines(4).point1(1),grid_corner_lines(4).point1(1)))); % needed for next phase

        horizontal_lines(h,:)=tmp;
        filteredLines = [filteredLines; lines(i)];
        h=h+1;
    elseif isVertical && ~checkIntersection(tmp,grid_corner_lines(2),grid_corner_lines(4))
        % Adjust y-coord with the difference between the upper grid corner
        % coordinates
        lines(i).point1(2) = lines(i).point1(2) - (abs(lines(i).point1(2)-min(grid_corner_lines(1).point1(2),grid_corner_lines(1).point2(2)))); % needed for next phase

        vertical_lines(v,:) = [lines(i).point1,lines(i).point2];
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

for i = 1:size(horizontal_lines,1)

    % Horizontal segment
    seg1_x = [horizontal_lines(i,1), horizontal_lines(i,3)];
    seg1_y = [horizontal_lines(i,2), horizontal_lines(i,4)];
    
    for j=1:size(vertical_lines,1)
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
% figure; imshow(grayImg), hold on;
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

freq_points= zeros(size(intersectionPoints(idx,:),1),3);
freq_points(:,1:2) = sortrows(intersectionPoints(idx,:));

if size(freq_points,1) ~= 13
    throw(MException('sizeError:Error','The number of points is not sufficient'));
end

% Initialize array to store OCR results for the frequency axis
freq_ocr_results = cell(size(freq_points,1), 1);

% Prepare the image for the ocr
adj_img = imadjust(grayImg);

% Applica filtro per ridurre rumore
filt_adj_img = medfilt2(adj_img, [3 3]);

% Binarizzazione adattiva
BW_adj_img = imbinarize(filt_adj_img);

% Rimuovi piccoli oggetti (rumore)
improved_ocr_img = bwareaopen(BW_adj_img, 50);

% %DEBUG
figure, imshow(improved_ocr_img);

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
    freq_ocr_results{i} = ocr(improved_ocr_img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "0124568k");
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

dB_points= zeros(size(intersectionPoints(idx,:),1),3);
dB_points(:,1:2) = sortrows(intersectionPoints(idx,:));

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
    dB_ocr_results{i} = ocr(improved_ocr_img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "-0123456789k");
    dB_ocr_results{i}.Text
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


% Remove noise in the ocr results

% Frequencies 
[freq_ocr_results, freq_labeled_list]= ocrTextNoisyRemove(freq_ocr_results);
freq_points(:,3)=freq_labeled_list;

% Decibels
[dB_ocr_results, dB_labeled_list]= ocrTextNoisyRemove(dB_ocr_results);
dB_points(:,3)=dB_labeled_list;

%% % FINAL PART
% 1. Extract information with Hough
close all;

x = max(refined_grid_points(1,1), refined_grid_points(3,1));
y = max(refined_grid_points(1,2), refined_grid_points(2,2));
cropped_img = imcrop (grayImg, [x,y,refined_grid_points(2,1)- x, refined_grid_points(3,2)-y]);

filtered_img = imadjust(cropped_img);


BW_binarized = imbinarize(filtered_img);



BW_complem=imcomplement(BW_binarized);
BW_binarized = bwskel(BW_complem);


[centers, radii, metric] = imfindcircles(BW_binarized,[6 25],"ObjectPolarity","dark","Method","PhaseCode");

[centers2, radii2, metric2] = imfindcircles(BW_binarized,[6 25],"ObjectPolarity","bright","Method","PhaseCode");

% DEBUG
% figure; imshow(BW_binarized);
% figure; imshow(BW_complem);

% DEBUG
figure ; imshow(BW_binarized);
hold on;
% Disegna i cerchi rilevati
viscircles(centers, radii,'EdgeColor','b', 'LineWidth', 2);
viscircles(centers2, radii2,'EdgeColor','r', 'LineWidth', 2);

hold off;


 % List of the point coordinates in the grid
 cropped_exam_points=[];

% Inizializza array per i centri dei cerchi bianchi sovrapposti
overlapping_bright_centers = [];

% Verifica se ci sono cerchi di entrambi i tipi
if ~isempty(centers) && ~isempty(centers2) 
    
    % Per ogni cerchio bianco, controlla se si sovrappone con almeno un cerchio scuro
    for i = 1:size(centers2, 1)
        center_bright = centers2(i, :);
        radius_bright = radii2(i);
        
        is_overlapping = false;
        
        % Controlla sovrapposizione con tutti i cerchi scuri
        for j = 1:size(centers, 1)
            center_dark = centers(j, :);
            radius_dark = radii(j);
            
            % Calcola la distanza tra i centri
            distance = sqrt(sum((center_bright - center_dark).^2));
            
            % Verifica se i cerchi si sovrappongono
            % Due cerchi si sovrappongono se la distanza tra i centri è minore
            % della somma dei loro raggi
            if distance<3
                overlapping_bright_centers = [overlapping_bright_centers; center_bright];
                break; % Non serve controllare altri cerchi scuri
            end
        end
    end
end


% % DEBUG
% % Risultato: overlapping_bright_centers contiene le coordinate dei centri
% % dei cerchi bianchi che si sovrappongono con almeno un cerchio scuro
% if ~isempty(overlapping_bright_centers)
%     fprintf('Trovati %d cerchi bianchi sovrapposti\n', size(overlapping_bright_centers, 1));
%     fprintf('Coordinate dei centri:\n');
%     disp(overlapping_bright_centers);
% else
%     fprintf('Nessun cerchio bianco sovrapposto trovato\n');
% end

cropped_exam_points=[];

if isempty(overlapping_bright_centers) || size(overlapping_bright_centers,1)< 4 % According to the minimum number of frequencies 
    % The image contains X, not O

    line_length = 20;     
    threshold   = 14;     
    
    % 4. Lancio la funzione
    matches = crossPatternMatchingBinary(BW_binarized, line_length, threshold);
    
    % 5. Visualizzo le coordinate trovate
    disp('Coordinate (x,y) dei centri delle croci rilevate:');
    disp(matches);
    
    
    epsilon = 10;    % raggio massimo (in pixel) per considerare due punti 1vicini"
    MinPts  = 1;    % numero minimo di punti per formare un cluster
    
    % --- STEP 3: Esegui DBSCAN sui punti `matches` ---
    [idx, isCorePoint] = dbscan(matches, epsilon, MinPts);
    
    % --- STEP 4: Analisi dei risultati ---
    % Visualizziamo a video quanti cluster sono stati trovati (escludendo il -1)
    clusterLabels = unique(idx);
    clusterLabels(clusterLabels == -1) = [];   % togliamo il rumore (-1)
    nClusters = numel(clusterLabels);
    fprintf('Trovati %d cluster (con almeno %d punti ciascuno).\n', nClusters, MinPts);
    
    % Per ciascun cluster, estraiamo le coordinate:
    clusters = cell(nClusters,1);
    for k = 1:nClusters
        label = clusterLabels(k);
        clusters{k} = matches(idx == label, :);
        fprintf('Cluster %d: %d punti\n', label, size(clusters{k},1));
    end
    
    % nNoisy = sum(idx == -1);
    % fprintf('Punti considerati rumore (non assegnati a nessun cluster): %d\n', nNoisy);
    
    % 1. Trova i cluster effettivi (escludendo l’etichetta -1)
    allLabels = unique(idx);
    clusterLabels = allLabels(allLabels ~= -1);   % togliamo -1
    nClusters = numel(clusterLabels);
    
    % 2. Prealloca la matrice per i centroidi
    %    Ogni riga conterrà [centroide_x, centroide_y] di un cluster
    centroids = zeros(nClusters, 2);
    
    % 3. Calcola il centroide per ogni cluster
    for k = 1:nClusters
        label = clusterLabels(k);
        
        % Estrai i punti del cluster k
        pts = matches(idx == label, :);
        
        % Centroide = media delle coordinate (colonna 1 = x, colonna 2 = y)
        centroids(k,1) = mean(pts(:,1));   % centroide x
        centroids(k,2) = mean(pts(:,2));   % centroide y
    end

    % Assign result
    cropped_exam_points = zeros(size(centroids,1),4);
    cropped_exam_points(:,1:2)=centroids;
    
    % DEBUG
    fprintf('Centroide di ciascun cluster trovato:\n');
    for k = 1:nClusters
        fprintf('  Cluster %d → Centroide (x,y) = (%.2f, %.2f)\n', ...
                clusterLabels(k), centroids(k,1), centroids(k,2));
    end
    
    % % DEBUG
    % figure; 
    % imshow(BW_binarized); hold on;
    % 
    % % Plotta tutti i punti dei cluster (come prima)
    % colors = hsv(nClusters);
    % for k = 1:nClusters
    %     label = clusterLabels(k);
    %     clusterPts = matches(idx == label, :);
    %     scatter(clusterPts(:,1), clusterPts(:,2), 50, ...
    %             'MarkerEdgeColor', colors(k,:), ...
    %             'MarkerFaceColor', colors(k,:), ...
    %             'DisplayName', sprintf('Cluster %d', label));
    % end
    % 
    % % Plotta i centroidi con un marker a croce rosso più grande
    % scatter(centroids(:,1), centroids(:,2), 100, ...
    %         'r', 'x', 'LineWidth', 2, ...
    %         'DisplayName', 'Centroidi');
    % 
    % axis ij;  % per far corrispondere gli assi alle coordinate immagine
    % xlabel('X [pixel]');
    % ylabel('Y [pixel]');
    % legend('Location','bestoutside');
    % title('Cluster e relativi centroidi');
    % hold off;

else
    % Assign result
    cropped_exam_points = zeros(size(overlapping_bright_centers,1),4);
    cropped_exam_points(:,1:2) = overlapping_bright_centers;
end


%%

% Restore the coordinates to the original image
exam_points = cropped_exam_points;
exam_points(:,1) = exam_points(:,1) + x;
exam_points(:,2) = exam_points(:,2) + y;

% Identify examination frequency values
freq_values = freq_points(:,3);
% Assign the closest frequency value to each point
[~, idx_freq] = min(abs(exam_points(:,1) - freq_points(:,1)'), [], 2);

exam_points(:,3) = freq_values(idx_freq);


% Identify examination decibel values
[~, sort_idx] = sort(dB_points(:,2));
dB_values_sorted = dB_points(sort_idx, 3);

% Create a new list of dB points with intermediate values
new_dB_points = dB_points(sort_idx, :);  % Start with the original sorted points
new_dB_values = dB_values_sorted;

% Insert intermediate points between each pair
dataCount = size(new_dB_points, 1);
for i = dataCount:-1:2
    % Compute midpoint for y-coordinate
    mid_y = (new_dB_points(i,2) + new_dB_points(i-1,2)) / 2;
    % Compute midpoint for dB value
    mid_value = (new_dB_points(i,3) + new_dB_points(i-1,3)) / 2;
    
    % Add the new point (also interpolate x for completeness)
    mid_x = (new_dB_points(i,1) + new_dB_points(i-1,1)) / 2;
    new_point = [mid_x, mid_y, mid_value];
    
    % Insert into the list
    new_dB_points = [new_dB_points(1:i-1, :); 
                     new_point; 
                     new_dB_points(i:end, :)];
end

% Update variables
dB_points = new_dB_points;
dB_values = dB_points(:,3);

% Assign the nearest dB value to each exam point based on y-coordinate
[~, idx_dB] = min(abs(exam_points(:,2) - dB_points(:,2)'), [], 2);
exam_points(:,4) = dB_values(idx_dB);





function matchesCross = crossPatternMatchingBinary(binaryImg, line_length, threshold)
    % crossPatternMatchingBinary   Rileva pattern a forma di croce (X) in un'immagine binaria con controllo diagonale aggiuntivo
    % Input:
    %   - binaryImg: immagine 2D già binaria (valori 0 o 1). Se non è logica, viene binarizzata tramite imbinarize.
    %   - line_length: lunghezza (in pixel) del lato del quadrato che forma la croce.
    %   - threshold: soglia minima di somma dei pixel sovrapposti.     
    % Output:
    %   - matchesCross: matrice Nx2 con le coordinate (x, y) dei punti in cui il template a croce ha risposto ≥ threshold 
    %                   e entrambe le diagonali superano il controllo individuale.

    % Verifica dimensione e binarità
    if ~islogical(binaryImg)
        binaryImg = imbinarize(binaryImg);
    end

    % Costruisci il template a forma di croce (X)
    e = eye(line_length);
    templateCross = (e + fliplr(e)) > 0;  
    
    % Convoluzione 2D
    corrCross = conv2(double(binaryImg), double(templateCross), 'same');

    % Trova coordinate candidate
    [yC, xC] = find(corrCross >= threshold);
    matchesCross = [xC, yC];
    
    % Prepara template per le diagonali singole (doppia precisione)
    template45 = double(e);
    template135 = double(fliplr(e));
    
    % Calcola offset per il centraggio
    half = floor(line_length/2);
    offset = floor((line_length-1)/2);
    
    % Filtraggio avanzato: controlla ogni candidato
    validMatches = [];
    [h, w] = size(binaryImg);
    
    for i = 1:size(matchesCross,1)
        x = matchesCross(i,1);
        y = matchesCross(i,2);
        
        % Calcola regione di interesse (ROI) centrata
        rStart = max(1, y - offset);
        rEnd = min(h, y + offset);
        cStart = max(1, x - offset);
        cEnd = min(w, x + offset);
        
        % Estrai finestra corrente
        win = binaryImg(rStart:rEnd, cStart:cEnd);
        winSize = size(win);
        
        % Adatta i template se la finestra è ai bordi
        temp45 = template45(1:winSize(1), 1:winSize(2));
        temp135 = template135(1:winSize(1), 1:winSize(2));
        
        % Calcola punteggi individuali
        score45 = sum(sum(win .* temp45));
        score135 = sum(sum(win .* temp135));
        
        % Applica soglie separate
        minDiagScore = max(1, ceil(0.2 * line_length)); % Soglia adattiva
        if score45 >= minDiagScore && score135 >= minDiagScore
            validMatches = [validMatches; x, y];
        end
    end
    
    matchesCross = validMatches;

    % % DEBUG
    % if ~isempty(matchesCross)
    %     figure; 
    %     imshow(binaryImg); 
    %     hold on;
    %     plot(matchesCross(:,1), matchesCross(:,2), 'md', 'MarkerSize', 10, 'LineWidth', 2);
    %     legend('Croce verificata');
    %     title(sprintf('Rilevate %d croci (soglia: %d)', size(matchesCross,1), threshold));
    % end
end
