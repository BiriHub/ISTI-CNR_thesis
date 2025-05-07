function isIntersect = checkIntersection(segment,corner1,corner2)
%checkIntersection : used to verify if a segment intersect improperly a
%grid segment due to its angle, if so, then returns true, else false

segment_x=[segment(1),segment(3)];
segment_y=[segment(2),segment(4)];

x1 = corner1.point1(1);
x2 = corner1.point2(1);
y1 = corner1.point1(2);
y2 = corner1.point2(2);
seg1_x = [x1, x2];
seg1_y = [y1, y2];
[xi_1, yi_1] = polyxpoly(seg1_x, seg1_y, segment_x, segment_y);

x1 = corner2.point1(1);
x2 = corner2.point2(1);
y1 = corner2.point1(2);
y2 = corner2.point2(2);
seg1_x = [x1, x2];
seg1_y = [y1, y2];
[xi_2, yi_2] = polyxpoly(seg1_x, seg1_y, segment_x, segment_y);

if ~isempty([xi_1,yi_1]) || ~isempty([xi_2,yi_2])
    isIntersect=true;
    return;
end
isIntersect=false;

end