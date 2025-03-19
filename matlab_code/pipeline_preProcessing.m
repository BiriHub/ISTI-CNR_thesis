%% Image pre-processing script in matlab

clc; clear; close all;

% Load image
img = imread('Noah_01_01_01.jpg');
grayImg = rgb2gray(img);
grayImg = medfilt2(grayImg); % median filter to red7uce errors (3 by 3)


%% 2. Edge-detection with Canny's algorithm
% Applica l'operatore Canny per ottenere la mappa di bordi binaria
edgeMap = edge(grayImg, 'Canny');

% Visualizza la mappa di bordi

% dilatation
edgeMap = imdilate(edgeMap,strel('line',3,0))| imdilate(edgeMap,strel('line',3,90));
edgeMap = imfill(edgeMap,4 ,'holes');

% extract the perimeter of the grid
edgeMap = bwmorph(edgeMap,'remove');

figure;
imshow(edgeMap);
title('Mappa di Bordi (Canny)');
%increase line size preparing to hough transformation
edgeMap = imdilate(edgeMap,strel("square",3));

%% 3. Applicazione della Trasformata di Hough per il Rilevamento delle Linee
% Calcola la trasformata di Hough
[H, theta, rho] = hough(edgeMap);

% Individua i picchi nella trasformata di Hough (numero e soglia possono essere regolati)
peaks = houghpeaks(H, 4);

% Estrai le linee rilevate basandoti sui picchi trovati
lines = houghlines(edgeMap, theta, rho, peaks, 'FillGap', 40);


%% 4. Visualizzazione dei Risultati
figure;
imshow(img);
hold on;
for k = 1:length(lines)
    xy = [lines(k).point1; lines(k).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'green');
    % Visualizza i punti iniziali e finali delle linee
    plot(xy(1,1), xy(1,2), 'x', 'LineWidth', 2, 'Color', 'yellow');
    plot(xy(2,1), xy(2,2), 'x', 'LineWidth', 2, 'Color', 'red');
end

title('Linee rilevate con la Trasformata di Hough');
hold off;



% % Otsu's method for binarization
% thresh = graythresh(grayImg);
% bwImg = imbinarize(grayImg, thresh);
% 
% % % Recognition of horizontal and vertical lines
% % hLines = imopen(~bwImg, strel('line', 30, 0));
% % vLines = imopen(~bwImg, strel('line', 30, 90));
% % smallerHLines = imopen(~bwImg, strel('line', 10, 0));
% % smallerVLines = imopen(~bwImg, strel('line', 10, 90));
% % %Plot visualization
% % gridMask = hLines | vLines | smallerHLines | smallerVLines;
% 
% % Extract data by removing grid
% figure, imshow(gridMask);
% title('Grid mask');
% 
% 
% % % Dilatation of smaller points
% bwImg = imdilate(bwImg,strel("square",1));
% 
% bwImg = bwmorph(bwImg,'bridge',Inf);

% 
% figure, imshow(bwImg);
% title('Binary image');
% 
% dataOnly = bwImg & ~gridMask;
