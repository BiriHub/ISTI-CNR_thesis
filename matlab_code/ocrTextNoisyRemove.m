function cleaned_ocrTextResults = ocrTextNoisyRemove(ocrTextResults)
    cleaned_ocrTextResults = ocrTextResults(:);

    % Preallocate numeric array
    n = numel(cleaned_ocrTextResults);
    numeric_values = zeros(n, 1);

    % Convert strings to numeric values
    for i = 1:n
        s = cleaned_ocrTextResults{i}.Text;

        % Check if 'k' is present
        if contains(s, 'k')
            s_no_k = strrep(s, 'k', '');
            num = str2double(s_no_k);
            if isnan(num)
                num = 0;  % Conversion error fallback
            end
            numeric_values(i) = num * 1000;
        else
            num = str2double(s);
            if isnan(num)
                num = 0;  % Handle empty OCR results or conversion error
            end
            numeric_values(i) = num;
        end
    end

    % Filter out non‐increasing values
    keep_idx = true(n, 1);       % Start by keeping all
    current_value = numeric_values(1);  % Initialize with the first value

    for i = 2:n
        if numeric_values(i) > current_value
            current_value = numeric_values(i);  % Update reference value
        else
            keep_idx(i) = false;  % Mark for removal
        end
    end

    % Apply filtered results
    cleaned_ocrTextResults = cleaned_ocrTextResults(keep_idx);

end
