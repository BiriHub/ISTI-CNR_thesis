%% 1. Image pre-processing script in MATLAB

clc; clear; close all;

a_file_list = [
    dir(fullfile('dataset\', '*.png'));
    dir(fullfile('dataset\', '*.jpg'));
    dir(fullfile('dataset\TestDataset\', '*.jpg'));
    ];
csv_output_folder = 'csv_results';
main_output_folder = 'audiogram_reports';
if ~exist(main_output_folder, 'dir')
    mkdir(main_output_folder);
end
mean_execution_time=[];

for i = 1:length(a_file_list)
    close all;
    disp(a_file_list(i).name);
    img_filename= a_file_list(i).name;
    
    % Load image
    img = imread(strcat(a_file_list(i).folder,'\',img_filename));
    [~, img_name, ext] = fileparts(img_filename);
    
    img_report_folder = fullfile(main_output_folder, img_name);
    img_subfolder = fullfile(img_report_folder, 'img');
    
    tic;
    grayImg = rgb2gray(img);
    
    % Get image width and height
    [img_max_height,img_max_width]= size(grayImg);
    
    
    %% 2. Preparing the image before applying th Hough transformation to identify an APPROXIMATION of grid corners
    % Idea: It aims to identify a possible approximation of where the grid corners are in the image, in next steps there will be found the exact points 
    
    % Edge-detection with Canny's algorithm + Morphologycal operations
    
    % Apply the Canny operator to obtain the binary edge map
    bin_img = edge(grayImg, 'Canny');
    
    % figure;
    % imshow(bin_img);
    
    % Dilation
    edgeMap = imdilate(bin_img, strel('line',3,0)) | imdilate(bin_img, strel('line',3,90));
    
    % figure;
    % imshow(edgeMap);
    
    edgeMap = imfill(edgeMap, 4, 'holes');
    
    % figure;
    % imshow(edgeMap);
    
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
    hough_grid_lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 600,'MinLength',300);
    
    % % DEBUG
    % figure;
    % imshow(edgeMap);
    % hold on;
    % for k = 1:length(hough_grid_lines)
    %     xy = [hough_grid_lines(k).point1; hough_grid_lines(k).point2];
    %     plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
    %     % Display the starting and ending points of the lines
    %     plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow','MarkerSize',10);
    %     plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red','MarkerSize',10);
    % end
    % hold off;
    
    %% 2.2 Identify digital intersection points between detected segments
    
    num_lines = 4;
    if size(hough_grid_lines,2)~= num_lines
        disp([img_filename ': Error: It is not possible to determine the grid area']);
        continue;
        
    end
    
    % Find the parallel line based on the theta angle
    idx= knnsearch([hough_grid_lines.theta]',hough_grid_lines(1).theta,"K",4);
    
    % Parallel lines
    line_group1=[hough_grid_lines(1:idx(2))];
    
    other_idx=sort([idx(3:4)]); 
    % Orthogonal lines
    line_group2 =[hough_grid_lines(other_idx)];
    
    
    k= 1;
    
    % List of x coordinates of intersection points
    point_intersec_x = zeros(num_lines,1);
    % List of y coordinates of intersection points
    point_intersec_y = zeros(num_lines,1);
    
    % Find the intersection between lines
    for i = 1:size(line_group1,2)
    
        line1_p1 = line_group1(i).point1;
        line1_p2 = line_group1(i).point2;
    
        for j = 1:size(line_group2,2)
    
            line2_p1 = line_group2(j).point1;
            line2_p2 = line_group2(j).point2;
    
            [intersec_X, intersec_Y] = intersectLines(line1_p1(1), line1_p1(2), line1_p2(1), line1_p2(2), line2_p1(1), line2_p1(2), line2_p2(1), line2_p2(2),...
                img_max_width,img_max_height);
    
            point_intersec_x(k) = intersec_X;
            point_intersec_y(k) = intersec_Y;
            k=k+1;
        end
    end
    
    % Combine coordinates in a new matrix 
    points = [point_intersec_x(:) point_intersec_y(:)];
    
    % Sort rows in an ascending order on coordinate Y and X
    points_sorted = sortrows(points,[2 1]);  
    
    % Containts the digital approximation of grid corners
    grid_points= [points_sorted(1,1) points_sorted(1,2);points_sorted(2,1) points_sorted(2,2);
                  points_sorted(3,1) points_sorted(3,2); points_sorted(4,1) points_sorted(4,2)];
    
    % %DEBUG
    % figure;
    % imshow(img);
    % hold on;
    % plot(grid_points(1,1), grid_points(1,2), 'bo', 'MarkerSize', 10, 'LineWidth', 3);
    % plot(grid_points(2,1), grid_points(2,2), 'go', 'MarkerSize', 10, 'LineWidth', 3);
    % plot(grid_points(3,1), grid_points(3,2), 'co', 'MarkerSize', 10, 'LineWidth', 3);
    % plot(grid_points(4,1), grid_points(4,2), 'mo', 'MarkerSize', 10, 'LineWidth', 3);
    % title("Grid corner results");
    % legend('Top Left', 'Top Right', 'Bottom Left', 'Bottom Right','Location', 'south');
    % hold off;
    
    %% Find the closest point to digital grid corners
    % So as to get the adjusted grid corners
    
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
    
    for i = 1:size(grid_points_cropped,1)
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
    % plot(grid_points(:,1), grid_points(:,2), 'mo', 'MarkerSize', 13, 'LineWidth', 3);
    % plot(refined_grid_points(:,1), refined_grid_points(:,2), 'rx', 'MarkerSize', 13, 'LineWidth', 3);
    % 
    % digit_corner = plot(NaN, NaN, 'mo', 'LineWidth', 1.5);
    % adj_corners = plot(NaN, NaN, 'rx', 'LineWidth', 1.5);
    % 
    % % legend([digit_corner, adj_corners], ...
    % %     {'Digital corner', 'Adjusted corner'}, ...
    % %     'Location', 'southoutside');
    % % % title('Adjusted grid corners');
    
    % Initialize the adjusted grid corner segment variables
    grid_corner_lines = struct('point1', {}, 'point2', {});
    
    grid_corner_lines(1) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(2,:)); % upper horizontal line
    grid_corner_lines(2) = struct('point1', refined_grid_points(1,:), 'point2', refined_grid_points(3,:)); % left vertical line
    grid_corner_lines(3) = struct('point1', refined_grid_points(3,:), 'point2', refined_grid_points(4,:)); % lower horizontal line
    grid_corner_lines(4) = struct('point1', refined_grid_points(2,:), 'point2', refined_grid_points(4,:)); % right vertical line
    
    
    
    
    %% Find grid internal intersections
    
    % Apply the binarization operator to obtain the binary image
    bin_img = imcomplement(imbinarize(grayImg));
    edgeMap = imdilate(bin_img, strel("square", 3));
    edgeMap= bwmorph(edgeMap,'skeleton');
    
    
    % Compute the Hough Transform
    [H, theta, rho] = hough(edgeMap);
    
    peaks = houghpeaks(H, 31, 'threshold', ceil(0.01 * max(H(:))));
    % Extract the detected lines based on the found peaks
    lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 500, 'MinLength', 500);
    
    
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
    distThresh = 10;
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
            % Compute the distance between
            d1 = abs(lines(i).point1(2) - grid_corner_lines(1).point1(2));
            d2 = abs( lines(i).point2(2) - grid_corner_lines(3).point1(2));
    
            if d1 > distThresh && d2> distThresh
                % Adjust x-coord with the difference between the right grid corner
                % coordinates
                lines(i).point2(1) = lines(i).point2(1) + (abs(lines(i).point2(1)-min(grid_corner_lines(4).point1(1),grid_corner_lines(4).point1(1)))); % needed for next phase
        
                horizontal_lines(h,:)=tmp;
                filteredLines = [filteredLines; lines(i)];
                h=h+1;
            end
            
        elseif isVertical && ~checkIntersection(tmp,grid_corner_lines(2),grid_corner_lines(4)) 
            % Compute the distance between
            d1 = abs(lines(i).point1(1) - grid_corner_lines(2).point1(1));
            d2 = abs(lines(i).point2(1) - grid_corner_lines(4).point1(1));
            
            if d1 > distThresh && d2 > distThresh
            % Adjust y-coord with the difference between the upper grid corner
            % coordinates
            lines(i).point1(2) = lines(i).point1(2) - (abs(lines(i).point1(2)-min(grid_corner_lines(1).point1(2),grid_corner_lines(1).point2(2)))); % needed for next phase
    
            vertical_lines(v,:) = [lines(i).point1,lines(i).point2];
            filteredLines = [filteredLines; lines(i)];
            v=v+1;
            end
    
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
    % plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 3, 'Color', 'yellow');
    % plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 3, 'Color', 'red');
    % end
    % title('Filtered Lines detected with the Hough Transform');
    % hold off;
    
    
    
    %% Look for the intersection between grid corner lines
    
    intersectionPoints = zeros(max_num_vert_lines * max_num_horiz_lines, 2);
    
    % Search for intersection between grid corner lines and horizontal/vertical lines
    
    k = 1;  % Index to save intersections
    for i = 1:length(grid_corner_lines)
    
        x1 = grid_corner_lines(i).point1(1);
        x2 = grid_corner_lines(i).point2(1);
        y1 = grid_corner_lines(i).point1(2);
        y2 = grid_corner_lines(i).point2(2);
        seg1_x = [x1, x2];
        seg1_y = [y1, y2];
        
        for j = 1:length(filteredLines)
        
            xx1 = filteredLines(j).point1(1);
            xx2 = filteredLines(j).point2(1);
            yy1 = filteredLines(j).point1(2);
            yy2 = filteredLines(j).point2(2);
            seg2_x = [xx1, xx2];
            seg2_y = [yy1, yy2];
            
            % Compute the intersection between two lines
            [xi, yi] = polyxpoly(seg1_x, seg1_y, seg2_x, seg2_y);
            if ~isempty(xi)
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
    % figure;
    % imshow(grayImg);
    % hold on;  % Abilita la sovrapposizione dei plot
    % 
    % % Horizontal lines
    % numHorizLines = size(horizontal_lines, 1);
    % for i = 1:numHorizLines
    %     x_coords = [horizontal_lines(i,1), horizontal_lines(i,3)];
    %     y_coords = [horizontal_lines(i,2), horizontal_lines(i,4)];
    %     plot(x_coords, y_coords, 'r-', 'LineWidth', 2);
    % end
    % 
    % % Vertical lines
    % numVertLines = size(vertical_lines, 1);
    % for i = 1:numVertLines
    %     x_coords = [vertical_lines(i,1), vertical_lines(i,3)];
    %     y_coords = [vertical_lines(i,2), vertical_lines(i,4)];
    %     plot(x_coords, y_coords, 'b-', 'LineWidth', 2);
    % end
    % 
    % for i =1 : k
    %     plot(intersectionPoints(i,1),intersectionPoints(i,2),'x', 'LineWidth',3,'Color','Green','MarkerSize',5)
    % end
    % 
    % title('Internal grid lines and intersection points');
    % hold off;
    
    
    % Optimize the size
    intersectionPoints = round(intersectionPoints(1:k-1, :),2);
    
    
    %% OCR IMPROVEMENT
    
    improved_ocr_img = enhance_text_contrast(grayImg);
    
    %1.  List points over the frequency text area by extracting coordinates 
    % that are above the upper-left grid corner
    
    % Frequency
    upper_corner_point=min(grid_corner_lines(1).point1(2),grid_corner_lines(1).point2(2));
    lower_corner_point=max(grid_corner_lines(1).point1(2),grid_corner_lines(1).point2(2));
    idx = intersectionPoints(:,2) >= upper_corner_point & intersectionPoints(:,2) <=lower_corner_point;
    
    freq_points= zeros(size(intersectionPoints(idx,:),1),3);
    freq_points(:,1:2) = sortrows(intersectionPoints(idx,:));
    
    if size(freq_points,1) < 8 % convetional frequencies scale in an audiogram
        % throw(MException('sizeError:Error','The number of points for frequency axis is not sufficient'));
        disp([img_filename ': The number of points for frequency axis is not sufficient']);
        continue;
    end
    
    % Initialize array to store OCR results for the frequency axis
    freq_ocr_results = cell(size(freq_points,1), 1);
    
    
    % % %DEBUG
    % figure, imshow(improved_ocr_img);
    
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
    
        % % Plot corners of the OCR area
        % hold on;
        % % Top-left corner
        % plot(ocr_area(1), ocr_area(2), 'bs', 'MarkerSize', 6, 'LineWidth', 2);
        % % Top-right corner
        % % plot(ocr_area(1) + ocr_area(3), ocr_area(2), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % % % Bottom-right corner
        % % plot(ocr_area(1) + ocr_area(3), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % % % Bottom-left corner
        % % plot(ocr_area(1), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % 
        % % % Optional: Draw the rectangle connecting the corners
        % rectangle('Position', ocr_area, 'EdgeColor', 'r','LineWidth',2);
    end
    
    
    % Decibel axis
    left_corner_point=min(grid_corner_lines(2).point1(1),grid_corner_lines(2).point2(1));
    right_corner_point=max(grid_corner_lines(2).point1(1),grid_corner_lines(2).point2(1));
    idx = intersectionPoints(:,1) >= left_corner_point & intersectionPoints(:,1) <=right_corner_point;
    
    dB_points= zeros(size(intersectionPoints(idx,:),1),3);
    dB_points(:,1:2) = sortrows(intersectionPoints(idx,:),2);
    
    if size(dB_points,1) < 5 % convetional range of decibel values for an audiogram
        % throw(MException('sizeError:Error','The number of points for decibel axis is not sufficient'));
            disp([img_filename ': The number of points for decibel axis is not sufficient']);
        continue;
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
            
        % rectangle('Position', ocr_area, 'EdgeColor', 'r');
    
        % Perform OCR
        dB_ocr_results{i} = ocr(improved_ocr_img, ocr_area, 'LayoutAnalysis', 'Block', 'CharacterSet', "-0123456789k");
        % 
        % % Plot corners of the OCR area
        % % Top-left corner
        % plot(ocr_area(1), ocr_area(2), 'bs', 'MarkerSize', 6, 'LineWidth', 2);
        % % % Top-right corner
        % % plot(ocr_area(1) + ocr_area(3), ocr_area(2), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % % % Bottom-right corner
        % % plot(ocr_area(1) + ocr_area(3), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % % % Bottom-left corner
        % % plot(ocr_area(1), ocr_area(2) + ocr_area(4), 'gs', 'MarkerSize', 4, 'LineWidth', 1);
        % 
        % % Optional: Draw the rectangle connecting the corners
        % rectangle('Position', ocr_area, 'EdgeColor', 'r','LineWidth',2);
    
    end
    % title("OCR")
    % % Ensure the figure is updated
    % hold off;
    
    
    % Remove noise in the ocr results
    
    % Frequencies 
    freq_labeled_list= ocrFreqAdjust(freq_ocr_results);
    freq_points(:,3)=freq_labeled_list;
    
    % Decibels
    dB_labeled_list= ocrDecibelAdjust(dB_ocr_results);
    dB_points(:,3)=dB_labeled_list;
    
    %% FINAL PART
    % 1. Extract information with Circular Hough or with Cross pattern matching
    
    x = min(refined_grid_points(1,1), refined_grid_points(3,1));
    y = max(refined_grid_points(1,2), refined_grid_points(2,2));
    max_width= max(refined_grid_points(2,1),refined_grid_points(4,1))- x;
    cropped_img = imcrop (grayImg, [x,y,max_width, refined_grid_points(3,2)-y]);
    
    filtered_img = imadjust(cropped_img);
    BW_binarized = imbinarize(filtered_img);
    
    BW_complem=imcomplement(BW_binarized);
    BW_complem = imdilate(BW_complem,strel('square',1));
    BW_binarized = bwskel(BW_complem);
    
    [centers, radii, metric] = imfindcircles(BW_binarized,[6 25],"ObjectPolarity","dark","Method","PhaseCode");
    
    [centers2, radii2, metric2] = imfindcircles(BW_binarized,[6 25],"ObjectPolarity","bright","Method","PhaseCode");
    
    
    % % DEBUG
    % figure ; imshow(BW_binarized);
    % hold on;
    % % Draw the detected circles
    % viscircles(centers, radii,'EdgeColor','b', 'LineWidth', 2);
    % viscircles(centers2, radii2,'EdgeColor','r', 'LineWidth', 2);
    % 
    % hold off;
    
     % List of the point coordinates in the grid
    cropped_exam_points=[];
    
    % Initialize array for the centers of overlapping white circles
    overlapping_bright_centers = [];
    
    center_threshold=5;
    
    % Check if there are circles of both types
    if ~isempty(centers) && ~isempty(centers2) 
        
        % For each white circle check if it overlaps with a black one
        for i = 1:size(centers2, 1)
            center_bright = centers2(i, :);
            radius_bright = radii2(i);
           
            % Compute distance vector
            distances = sqrt(sum((centers - center_bright).^2, 2));
            
            % Check if there is at least one overlapped center
            if any(distances < center_threshold)
                overlapping_bright_centers = [overlapping_bright_centers; center_bright];
            end
    
        end
    end
    
    
    % % DEBUG
    % % Result: overlapping_bright_centers contains the coordinates of the centers
    % % of the white circles that overlap with at least one black circle
    % if ~isempty(overlapping_bright_centers)
    %     fprintf('Found %d overlapping white circles\n', size(overlapping_bright_centers, 1));
    %     fprintf('Centers coordinates:\n');
    %     disp(overlapping_bright_centers);
    % else
    %     fprintf('No overlapping white circle found\n');
    % end
    
    cropped_exam_points=[];
    
    if isempty(overlapping_bright_centers) || size(overlapping_bright_centers,1)< 4 % According to the minimum number of frequencies 
        % The image contains X, not O
    
        line_length = 20;     
        threshold   = 14;     
        
        matches = crossPatternMatchingBinary(BW_binarized, line_length, threshold);
        
        
        epsilon = 10;    % maximum radius (in pixels) to consider two points as close
        MinPts  = 1;    % minimum number of points to form a cluster
        
        [idx, isCorePoint] = dbscan(matches, epsilon, MinPts);
        
        % Display how many clusters have been found (excluding -1)
        clusterLabels = unique(idx);
        clusterLabels(clusterLabels == -1) = [];   % remove noise (-1)
        nClusters = numel(clusterLabels);
        
        % % For each cluster, extract the coordinates:
        % clusters = cell(nClusters,1);
        % for k = 1:nClusters
        %     label = clusterLabels(k);
        %     clusters{k} = matches(idx == label, :);
        %     fprintf('Cluster %d: %d points\n', label, size(clusters{k},1));
        % end
        
        % nNoisy = sum(idx == -1);
        % fprintf('Points considered noise (not assigned to any cluster): %d\n', nNoisy);
        
        % 1. Find the effective clusters (excluding label -1)
        allLabels = unique(idx);
        clusterLabels = allLabels(allLabels ~= -1);   % remove -1
        nClusters = numel(clusterLabels);
        
    
        centroids = zeros(nClusters, 2);
        
        % 3. Compute centroid for each cluster
        for k = 1:nClusters
            label = clusterLabels(k);
            
            % Extract points of cluster k
            pts = matches(idx == label, :);
            centroids(k,1) = mean(pts(:,1));  
            centroids(k,2) = mean(pts(:,2)); 
        end
    
        % Assign result
        cropped_exam_points = zeros(size(centroids,1),4);
        cropped_exam_points(:,1:2)=centroids;
        
        % % DEBUG
        % fprintf('Centroid of each cluster found:\n');
        % for k = 1:nClusters
        %     fprintf('  Cluster %d → Centroid (x,y) = (%.2f, %.2f)\n', ...
        %             clusterLabels(k), centroids(k,1), centroids(k,2));
        % end
        
        % % DEBUG
        % figure; 
        % imshow(BW_binarized); hold on;
        % 
        % % Plot all cluster points (as before)
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
        % % Plot centroids with a bigger red cross marker
        % scatter(centroids(:,1), centroids(:,2), 100, ...
        %         'r', 'x', 'LineWidth', 2, ...
        %         'DisplayName', 'Centroids');
        % 
        % axis ij;  % to match axes with image coordinates
        % xlabel('X [pixel]');
        % ylabel('Y [pixel]');
        % % legend('Location','bestoutside');
        % title('Clusters and related centroids');
        % hold off;
    
    else
        % Assign result
        cropped_exam_points = zeros(size(overlapping_bright_centers,1),4);
        cropped_exam_points(:,1:2) = overlapping_bright_centers;
    end
    
    
    
    % Restore the coordinates to the original image
    exam_points = cropped_exam_points;
    exam_points(:,1) = exam_points(:,1) + x;
    exam_points(:,2) = exam_points(:,2) + y;
    
    % a. Identify examination frequency values
    freq_values = freq_points(:,3);
    % Assign the closest frequency value to each point
    [~, idx_freq] = min(abs(exam_points(:,1) - freq_points(:,1)'), [], 2);
    
    exam_points(:,3) = freq_values(idx_freq);
    
    
    % b. Identify examination decibel values
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
    
    
    % Order the values according to an ascending sequence
    exam_values_csv= sortrows(exam_points(:,3:4));
    
    
    
    %% Save examination information on a CSV file
    
    if ~exist(csv_output_folder, 'dir')
        mkdir(csv_output_folder);
    end
    
    % Build the full file path
    filename = fullfile(strcat(pwd,'\',csv_output_folder), strcat(img_name,'_results.csv'));
    
    % Create a table with column names
    data_table = array2table(exam_values_csv, ...
        'VariableNames', {'Frequency_Hz', 'Intensity_dB'});
    
    % Save the table in CSV format
    writetable(data_table, filename);
    
    % Confirmation message
    disp(['File successfully saved: ' filename]);
    
    
    execution_time =toc;
    mean_execution_time=[mean_execution_time, execution_time];
    disp(["Execution time:" execution_time]);
    
    
    %% Generate report
    % Save images
    % DEBUG
    
    % Create the folders if they do not exist
    if ~exist(img_report_folder, 'dir')
        mkdir(img_report_folder);
    end
    if ~exist(img_subfolder, 'dir')
        mkdir(img_subfolder);
    end
    
    % Print original image
    fig0 = figure('Visible', 'off');
    imshow(img);
    title(img_name);
    saveas(fig0, fullfile(img_subfolder, img_filename));
    
    % Print grid points
    fig1 = figure('Visible', 'off');
    imshow(grayImg), hold on;
    
    plot(intersectionPoints(:,1), intersectionPoints(:,2), 'ro', 'MarkerSize', 5, 'LineWidth', 2);
    
    title('Grid points');
    
    for i = 1:length(grid_corner_lines)
        % Point 1 of the line
        x_pt1 = grid_corner_lines(i).point1(1);
        y_pt1 = grid_corner_lines(i).point1(2);
        plot(x_pt1, y_pt1, 'bs', 'MarkerSize', 6, 'LineWidth', 2);    
        % Point 2 of the line
        x_pt2 = grid_corner_lines(i).point2(1);
        y_pt2 = grid_corner_lines(i).point2(2);
        plot(x_pt2, y_pt2, 'bs', 'MarkerSize', 6, 'LineWidth', 2);
    end
    h_intersection = plot(NaN, NaN, 'ro', 'MarkerSize', 5, 'LineWidth', 2);
    h_gridcorner = plot(NaN, NaN, 'bs', 'MarkerSize', 6, 'LineWidth', 2);
    legend([h_intersection, h_gridcorner], ...
           {'Internal grid intersections', 'Grid corners'}, ...
           'Location', 'southoutside');
    hold off;
    saveas(fig1, fullfile(img_subfolder, [img_name '_grid_points.png']));
    close(fig1);
    %%
    % Print OCR results
    fig_ocr = figure('Visible', 'off');
    imshow(improved_ocr_img);
    hold on;
    
    % Process and display OCR results for frequencies
    for i = 1:size(freq_points,1)
        % Compute OCR area
        if i == 1
            a = abs(freq_points(i,1) - 1) / 2.5;
        elseif i == 13
            a = abs(freq_points(i,1) - freq_points(i-1,1)) / 2;
        else
            a = abs(freq_points(i,1) - freq_points(i-1,1)) / 2.5;
        end
        
        point1 = [freq_points(i,1) - a, freq_points(i,2)];
        point2 = [freq_points(i,1) + a, freq_points(i,2)];
        
        width_ocr_area = point2(1) - point1(1);
        if point1(1) + width_ocr_area > img_max_width
            width_ocr_area = img_max_width - point1(1) - 1;
        end
        
        ocr_area = [point1(1), 1, width_ocr_area, point1(2) - 1];
        
        % Draw the bounding box
        rectangle('Position', ocr_area, 'EdgeColor', 'r', 'LineWidth', 1.5);
        plot(ocr_area(1), ocr_area(2), 'bs', 'MarkerSize', 5, 'LineWidth', 2);
    
        % Add the improved label
        if i <= length(freq_labeled_list) && ~isnan(freq_labeled_list(i))
            text(freq_points(i,1), freq_points(i,2)+5, ...
                num2str(freq_labeled_list(i)), ...
                'Color', 'g', 'FontWeight', 'bold', 'FontSize', 12, ...
                'HorizontalAlignment', 'center');
        end
    end
    k=1;
    % Process and display OCR results for decibels
    for i = 1:2:size(dB_points,1)
        % Compute OCR area
        if i == 1
            a = abs(dB_points(i,2) - 1) / 2;
        else
            a = abs(dB_points(i,2) - dB_points(i-1,2)) / 2;
        end
        
        point1 = [dB_points(i,1), dB_points(i,2) - a];
        point2 = [dB_points(i,1), dB_points(i,2) + a];
        
        height_ocr_area = point2(2) - point1(2);
        if point1(2) + height_ocr_area > img_max_height
            height_ocr_area = img_max_height - point1(2) - 1;
        end
        
        ocr_area = [1, point1(2), point1(1) - 1, height_ocr_area];
        
        % Draw the bounding box
        rectangle('Position', ocr_area, 'EdgeColor', 'b', 'LineWidth', 1.5);
        plot(ocr_area(1), ocr_area(2), 'rs', 'MarkerSize', 5, 'LineWidth', 2);
        
        % Add the improved label
        if k <= length(dB_labeled_list) && ~isnan(dB_labeled_list(k))
            text(dB_points(i,1), dB_points(i,2),...
                num2str(dB_labeled_list(k)), ...
                'Color', 'm', 'FontWeight', 'bold', 'FontSize', 12, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            k=k+1;
        end
    end
    
    % Add a legend
    h_freq = plot(NaN, NaN, 'r-', 'LineWidth', 1.5);
    h_db = plot(NaN, NaN, 'b-', 'LineWidth', 1.5);
    
    legend([h_freq, h_db], ...
        {'Frequency OCR Area', 'Decibel OCR Area'}, ...
        'Location', 'southoutside');
    title('OCR Results with Bounding Boxes and Corrected Labels');
    hold off;
    
    % Save the image
    saveas(fig_ocr, fullfile(img_subfolder, [img_name '_ocr_boxes.png']));
    close(fig_ocr);
    
    % Print Circles/Crosses points
    fig3 = figure('Visible', 'off');
    imshow(BW_binarized);
    hold on;
    
    if ~isempty(overlapping_bright_centers)
        % Detected circles
        viscircles(centers, radii,'EdgeColor','b', 'LineWidth', 2);
        viscircles(centers2, radii2,'EdgeColor','r', 'LineWidth', 2);
        plot(cropped_exam_points(:,1), cropped_exam_points(:,2), 'gx', 'MarkerSize', 8, 'LineWidth', 2);
        title('Detected circles');
    else
        % Detected crosses
        scatter(cropped_exam_points(:,1), cropped_exam_points(:,2), 100, 'g', 'x', 'LineWidth', 5);
        title('Detected crosses');
    end
    
    hold off;
    saveas(fig3, fullfile(img_subfolder, [img_name '_detection_result.png']));
    close(fig3);
    %% Generating the Latex file 
    latex_file = fullfile(img_report_folder, [img_name '_report.tex']);
    fid = fopen(latex_file, 'w');
    
    % Document header
    fprintf(fid, '\\documentclass{article}\n\\usepackage{graphicx}\n\\usepackage{subcaption}\n\\usepackage{subcaption}\n\\usepackage{booktabs}\n\\usepackage{array}\n\\usepackage[margin=1.5cm]{geometry}\n\n\\title{Audiogram Analysis Report: %s}\n\\date{\\today}\n\n\\begin{document}\n\n\\maketitle\n\n\\section*{Processing Results}\n\\begin{figure}[h!]\n\\centering\n',replace(img_name,'_','\_'));

    % First row: Original image and grid points
	% Generate the first row of images with the original and the grid points results
    fprintf(fid, '\\begin{subfigure}{0.45\\textwidth}\n\\centering\n\\includegraphics[width=\\textwidth]{img/%s%s}\n\\caption{Original image}\n\\end{subfigure}\n\\hfill\n\\begin{subfigure}{0.45\\textwidth}\n\\centering\n\\includegraphics[width=\\textwidth]{img/%s_grid_points.png}\n\\caption{Grid points detection}\n\\end{subfigure}\n', img_name, ext, img_name );

    % Generate the second row of images with the OCR and the circles/crosses results
    fprintf(fid, '\\\\\n\\begin{subfigure}{0.45\\textwidth}\n\\centering\n\\includegraphics[width=\\textwidth]{img/%s_ocr_boxes.png}\n\\caption{OCR enhancement}\n\\end{subfigure}\n\\hfill\n\\begin{subfigure}{0.45\\textwidth}\n\\centering\n\\includegraphics[width=\\textwidth]{img/%s_detection_result.png}\n\\caption{Circle/cross detection}\n\\end{subfigure}\n\\caption{Key processing stages for audiogram analysis}\n\\end{figure}\n\\newpage\n',img_name,img_name);
    
    % Create the table
    fprintf(fid, '\\section*{Examination Results}\n\\begin{table}[h!]\n\\centering\n\\caption{Audiometric measurements}\n\\begin{tabular}{>{\\ttfamily}crr}\n\\toprule\n\\textbf{Frequency (Hz)} & \\textbf{Intensity (dB)} \\\\\n\\midrule\n');

    % Insert data from the CSV table
    for j = 1:size(exam_values_csv, 1)
        fprintf(fid, '%d & %d \\\\\n', exam_values_csv(j,1), exam_values_csv(j,2));
    end
    
    fprintf(fid, '\\bottomrule\n\\end{tabular}\n\\end{table}\n\n\\end{document}');
    fclose(fid);
    
    try
        current_dir = pwd;
        cd(img_report_folder);
        
        % Compile the LaTeX document
        system(['pdflatex -interaction=nonstopmode -interaction=batchmode ' img_name '_report.tex']);
        
        % Clean up auxiliary files
        delete('*.aux');
        delete('*.log');
        delete('*.out');
        
        cd(current_dir);
        disp(['PDF report generated for: ' img_name]);
    catch ME
        warning('PDF compilation failed for %s: %s', img_name, ME.message);
        cd(current_dir);
    end

end

disp(["Mean execution time:" mean(mean_execution_time)]);


function enhanced_img = enhance_text_contrast(gray_img)
    % Normalize the image 
    normalized = mat2gray(gray_img);
    
    % 2. Gamma transformation to lighten shadows
    gamma_dark = 2.5;  
    lightened = normalized.^gamma_dark;

    % figure;
    % imshow(lightened);

    % 3. Non-linear mapping to increase contrast in highlights
    k = 1;  % Contrast factor for highlights
    enhanced = (1 - exp(-k*lightened)) / (1 - exp(-k));

    % figure;
    % imshow(enhanced);

    % 4. Adaptive contrast equalization (CLAHE)
    enhanced_img = adapthisteq(enhanced);
    figure;
    imshow(enhanced_img);
    enhanced_img = imsharpen(enhanced_img, 'Radius', 3, 'Amount', 2.5);
    
    % figure;
    % imshow(enhanced_img);

    % Convert to uint8 for visualization
    enhanced_img = im2uint8(enhanced_img);
end
