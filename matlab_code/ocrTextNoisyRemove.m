function [cleaned_ocrTextResults, idx] = ocrTextNoisyRemove(ocrTextResults)
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

    idx=zeros(n,1);
    idx(1)= current_value;
    for i = 2:n
        if numeric_values(i) > current_value
            % Update both current and previous values
            current_value = numeric_values(i);
        else
            % Calculate logarithmic midpoint
            log_prev = log10(current_value);
            log_current = log10(numeric_values(i+1));
            log_mid = (log_prev + log_current) / 2;
            
            % Set new value to 10^(logarithmic midpoint)
            new_value = 10^log_mid;
            
            % Update the current value to the new midpoint value
            numeric_values(i) = new_value;
            current_value = new_value;
            keep_idx(i) = false;  % Mark for removal
        end
        idx(i)=current_value;
    end
    
    % Apply filtered results
    cleaned_ocrTextResults = cleaned_ocrTextResults(keep_idx);

end
