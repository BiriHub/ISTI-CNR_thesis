function [cleaned_ocrTextResults, ocrText_values] = ocrDecibelAdjust(ocrTextResults)
    cleaned_ocrTextResults = ocrTextResults(:);

    % Preallocate numeric array
    n = numel(cleaned_ocrTextResults);
    numeric_values = zeros(n, 1);

    % Convert strings to numeric values
    for i = 1:n
        s = cleaned_ocrTextResults{i}.Text;
       num = str2double(s);
        if isnan(num)
            num = 0;  % Conversion error fallback
        end
            numeric_values(i) = num;
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
        elseif i==n
            ratio= ocrText_values(i-1)/ocrText_values(i-2);
            ocrText_values(i)=round((ocrText_values(i-1) * ratio) / 10) * 10;
        else
            % Calculate logarithmic midpoint
            log_prev = log10(current_value);
            j=i+1;
            while j<size(numeric_values,1) && numeric_values(j)==0
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
