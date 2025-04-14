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

num_horiz_lines = 16;
num_vert_lines  = 15;

filteredLines = [];
angleThreshold = 1; % angle threshold

horizontal_lines= zeros(num_horiz_lines,4); 
vertical_lines= zeros(num_vert_lines,4);

h=1;
v=1;
for i = 1:length(lines)
    currentTheta = lines(i).theta;
    
    % Verify if the line tends to be horizontal
    isHorizontal = abs(mod(currentTheta, 180)) <= angleThreshold || ...
                  abs(mod(currentTheta, 180) - 180) <= angleThreshold;
    
    % Verify if the line tends to be vertical
    isVertical = abs(mod(currentTheta, 180) - 90) <= angleThreshold;
        
    % Save only the horizontal or vertical lines
    if isHorizontal
        horizontal_lines(h,:)=[lines(i).point1,lines(i).point2];
        filteredLines = [filteredLines; lines(i)];
        h=h+1;
    elseif isVertical
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



% DEBUG
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


% initialize
grid_corner_lines = struct('point1', {}, 'point2', {});

grid_corner_lines(1) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(2,:)); % upper horizontal line
grid_corner_lines(2) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(3,:)); % left vertical line
grid_corner_lines(3) = struct('point1', refined_grid_points(3,:), 'point2', refined_grid_points(4,:)); % lower horizontal line
grid_corner_lines(4) = struct('point1', refined_grid_points(2,:), 'point2', refined_grid_points(4,:)); % right vertical line


% Inizializza una variabile per raccogliere tutti i punti di intersezione
intersectionPoints = zeros(num_vert_lines * num_horiz_lines, 2);


% Search for intersection between grid corner lines and horizontal/vertical lines

k = 1;  % index to save intersections
threshold = 10; % used to filter too close points
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

k
% Identify internal intersections between horizontal and vertical lines


% k = 1;  % index to save intersection
% % internal_intersect_grid=[];


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

% Supponiamo che intersectionPoints sia la matrice ottenuta con tutte le intersezioni
% e threshold sia la soglia per la distanza
numPoints = size(intersectionPoints, 1);
isValid = true(numPoints, 1);  % Vettore logico: true se il punto va tenuto

% Ad esempio, confronta ogni punto con i suoi vicini
for i = 1:numPoints
    if ~isValid(i)
        continue; % Se il punto i è già stato contrassegnato come non valido, salta
    end
    
    % Trova i 2 nearest neighbor (il primo sarà il punto stesso)
    idx = knnsearch(intersectionPoints, intersectionPoints(i,:), 'K', 2);
    
    % Se il secondo punto (indice 2) risulta troppo vicino, marca quel punto come non valido
    if numel(idx) > 1
        neighborIdx = idx(2);
        % Calcola la distanza
        dist = norm(intersectionPoints(i,:) - intersectionPoints(neighborIdx,:));
        % remove the point
        if dist <= threshold
            isValid(neighborIdx) = false;
        end
    end
end

% Ricostruisci la matrice senza i "buchi"
intersectionPoints = intersectionPoints(isValid, :);




% Definisci la soglia per il filtering dei punti troppo vicini ai grid corner

% Inizializza un vettore logico per marcare i punti da mantenere (inizialmente tutti sono validi)
numIntersectionPoints = size(intersectionPoints, 1);
keepPoint = true(numIntersectionPoints, 1);

numCorners = size(refined_grid_points, 1);
for iCorner = 1:numCorners
    % Estrai il punto corner corrente
    cornerPoint = refined_grid_points(iCorner, :);
    
    % Calcola le distanze (in maniera vettorializzata) da cornerPoint a tutti i punti di intersectionPoints
    distances = sqrt(sum((intersectionPoints - cornerPoint).^2, 2));
    
    % Marca come false (cioè da scartare) tutti i punti che sono troppo vicini al grid corner
    keepPoint(distances <= threshold) = false;
end

% Filtra la matrice intersectionPoints eliminando i punti troppo vicini ai grid corner
intersectionPoints = intersectionPoints(keepPoint, :);


% DEGUB
figure, imshow(grayImg), hold on;

plot(intersectionPoints(:,1), intersectionPoints(:,2), 'ro', 'MarkerSize', 3, 'LineWidth', 1);

title('Grid intersection points');


for i = 1:length(grid_corner_lines)
    % Punto 1 della linea
    x_pt1 = grid_corner_lines(i).point1(1);
    y_pt1 = grid_corner_lines(i).point1(2);
    plot(x_pt1, y_pt1, 'bs', 'MarkerSize', 10, 'LineWidth', 2);    
    % Punto 2 della linea
    x_pt2 = grid_corner_lines(i).point2(1);
    y_pt2 = grid_corner_lines(i).point2(2);
    plot(x_pt2, y_pt2, 'bs', 'MarkerSize', 10, 'LineWidth', 2);
end



