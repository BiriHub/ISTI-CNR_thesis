function [cleaned_ocrTextResults, ocrText_values] = ocrTextNoisyRemove(ocrTextResults)
    cleaned_ocrTextResults = ocrTextResults(:);

    % Preallocate numeric array
    n = numel(cleaned_ocrTextResults);
    numeric_values = zeros(n, 1);

    % Convert strings to numeric values
    for i = 1:n
        s = cleaned_ocrTextResults{i}.Text;
        % Check negative value
        if contains(s,'-')
            num = str2double(s);
            if isnan(num)
                num = 0;  % Conversion error fallback
            end
            numeric_values(i) = num;
        % Check if 'k' is present
        elseif contains(s, 'k')
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

    ocrText_values=zeros(n,1);
    ocrText_values(1)=current_value;
    for i = 2:n
        if numeric_values(i) > current_value
            % Update both current and previous values
            current_value = numeric_values(i);
        else
            % Calculate logarithmic midpoint
            log_prev = log10(current_value);
            j=i+1;
            while numeric_values(j)==0
                j=j+1;
            end
            nZero = j-i;

            log_next = log10(numeric_values(j));

            V = logspace(log_prev,log_next,nZero+2);
            
            % Set new value to 10^(logarithmic midpoint)
            new_values = round(V(2:end-1) / 10) * 10;
            
            % Update the current value to the new midpoint value
            numeric_values(i : j-1) = new_values;
            current_value = new_values(1);
        end
        ocrText_values(i)=current_value;
    end

    % Apply filtered results
    cleaned_ocrTextResults = cleaned_ocrTextResults(keep_idx);

end
