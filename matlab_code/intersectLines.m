function [xI, yI] = intersectLines(x1,y1,x2,y2,x3,y3,x4,y4)
% Computes the intersection point (xI, yI) of two lines defined by
% the points (x1,y1)-(x2,y2) and (x3,y3)-(x4,y4).
% If the lines are parallel (i.e., they have no intersection), 
% the function returns NaN values.
% parameters: 

    % Compute coefficients for the implicit line equation Ax + By = C
    % Line 1 passing through (x1, y1) and (x2, y2)
    A1 = y2 - y1;    % Change in y
    B1 = x1 - x2;    % Negative change in x
    C1 = A1*x1 + B1*y1;  % Compute C1 based on one point of the line

    % Line 2 passing through (x3, y3) and (x4, y4)
    A2 = y4 - y3;    % Change in y for second line
    B2 = x3 - x4;    % Negative change in x for second line
    C2 = A2*x3 + B2*y3;  % Compute C2 based on one point of the line

    % Compute the determinant of the coefficient matrix
    det = A1*B2 - A2*B1;

    if abs(det) < 1e-9  % Check if determinant is close to zero (parallel lines)
        % The lines are parallel (or nearly parallel), no intersection
        xI = NaN; 
        yI = NaN;
        return
    end

    % Compute the intersection point using Cramer's rule
    xI = (B2*C1 - B1*C2) / det;
    yI = (A1*C2 - A2*C1) / det;
    
    % Check for invalid point coordinates
    if abs(xI) > 1e3 || abs(yI) > 1e3
        xI = NaN;
        yI = NaN;
    end

end