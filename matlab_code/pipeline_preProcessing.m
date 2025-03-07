%% Image pre-processing script in matlab

clc; clear; close all;

% Load image
img = imread('Noah_01_01_01.jpg');
grayImg = rgb2gray(img);

% % grayImg= imdilate(grayImg,strel("square",2)); % debug
% figure;
% imshow(grayImg)

% Otsu's method for binarization
thresh = graythresh(grayImg);
bwImg = imbinarize(grayImg, thresh);

% Dilatation of smaller points
bwImg = imdilate(bwImg,strel("square",2));

% Recognition of horizontal and vertical lines
hLines = imopen(~bwImg, strel('line', 30, 0));
vLines = imopen(~bwImg, strel('line', 30, 90));
smallerHLines = imopen(~bwImg, strel('line', 10, 0));
%To do: complete the recognition
gridMask = hLines | vLines | smallerHLines;

%Plot visualization

% Extract data by removing grid
figure, imshow(gridMask);
title('Immagine con la grid mask');

figure, imshow(bwImg);
title('Immagine Binarizzata');

