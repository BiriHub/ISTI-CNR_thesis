function matchesCross = crossPatternMatchingBinary(binaryImg, line_length, threshold)
    % crossPatternMatchingBinary   Identify cross pattern (X) in a binary image
    % Input:
    %   - binaryImg: Binary image.
    %   - line_length: length (in pixels) of the square side that forms the cross.
    %   - threshold: minimum threshold for the sum of overlapping pixels. 
    % Output:
    %   - matchesCross:  Nx2 matrix with coordinates (x, y) of points where the cross template
    %                    responded >= threshold and both diagonals pass individual validation.

    % Build the cross-shaped template (X)
    e = eye(line_length); % Create identity matrix
    templateCross = (e + fliplr(e)) > 0;  % Combine main diagonal with flipped diagonal
    % Perform 2D convolution to find cross patterns
    corrCross = conv2(double(binaryImg), double(templateCross), 'same');

    % Find candidate coordinates where convolution response exceeds threshold
    [yC, xC] = find(corrCross >= threshold);
    matchesCross = [xC, yC];
    
    % Prepare templates for individual diagonals (double precision for calculations)
    template45 = double(e);     % Main diagonal (45°)
    template135 = double(fliplr(e));    % Anti-diagonal (135°)
    % Calculate offset for centering the template on candidate points
    offset = floor((line_length-1)/2);
    
    % Validate each candidate individually
    validMatches = [];
    [h, w] = size(binaryImg); % Get image dimensions
    
    % For each matched cross, it apply a double verification in order to
    % remove noises
    for i = 1:size(matchesCross,1)
        x = matchesCross(i,1);
        y = matchesCross(i,2);
        
        % Calculate Region of Interest (ROI) centered on candidate point
        rStart = max(1, y - offset);
        rEnd = min(h, y + offset);
        cStart = max(1, x - offset);
        cEnd = min(w, x + offset);
        
        % Extract current window and adapt templates to the window
        win = binaryImg(rStart:rEnd, cStart:cEnd);
        winSize = size(win);
        temp45 = template45(1:winSize(1), 1:winSize(2));
        temp135 = template135(1:winSize(1), 1:winSize(2));
        
        % Compute results
        score45 = sum(sum(win .* temp45));
        score135 = sum(sum(win .* temp135));
        
        % Accept candidate only if both diagonals meet minimum score requirement
        minDiagScore = max(1, ceil(0.2 * line_length)); % Adaptive threshold (20% of line length)
        if score45 >= minDiagScore && score135 >= minDiagScore
            validMatches = [validMatches; x, y];
        end
    end
    
    matchesCross = validMatches; % Return final validated matches

    % % DEBUG
    % if ~isempty(matchesCross)
    %     figure;
    %     imshow(binaryImg);
    %     hold on;
    %     plot(matchesCross(:,1), matchesCross(:,2), 'md', 'MarkerSize', 10, 'LineWidth', 2);
    %     legend('Verified Cross');
    %     title(sprintf('Detected %d crosses (threshold: %d)', size(matchesCross,1), threshold));
    % end
    % pause;
end