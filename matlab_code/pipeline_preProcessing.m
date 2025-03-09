%% Image pre-processing script in matlab

clc; clear; close all;

% Load image
img = imread('Noah_01_01_01.jpg');
grayImg = rgb2gray(img);

grayImg = medfilt2(grayImg); % median filter to reduce errors (3 by 3)


% Otsu's method for binarization
thresh = graythresh(grayImg);
bwImg = imbinarize(grayImg, thresh);
% 
% bwImg = imclose(bwImg,strel('line',5,0));
% 
% bwImg = bwmorph(bwImg,'bridge',Inf);



% % Dilatation of smaller points
bwImg = imdilate(bwImg,strel("square",1));

bwImg = bwmorph(bwImg,'bridge',Inf);


figure, imshow(bwImg);
title('Binary image');

