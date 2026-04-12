# Automated Analysis and Digitization of Audiometric Curves

A MATLAB-based system for the **automatic extraction and digitization of audiometric data** from audiogram images captured with standard smartphone cameras. The project converts graphical hearing test reports into **structured CSV data**, enabling downstream clinical analysis, data archiving, and integration with digital health workflows — while preserving privacy through **fully local processing**.
## Overview

Audiograms are widely used to assess hearing thresholds across frequencies, but many historical records still exist only as **paper documents, scans, or static images**. Manual transcription of these records is slow, error-prone, and difficult to scale for research or longitudinal monitoring. This project addresses that problem by providing an automated computer-vision pipeline that detects the audiometric grid, extracts axis labels, identifies plotted symbols, and maps them to calibrated **frequency (Hz)** and **intensity (dB)** values.

Unlike many recent solutions based on deep learning, this system is intentionally designed as a **deterministic and interpretable pipeline** using classical image processing techniques. This makes it more transparent, easier to tune, less dependent on annotated training datasets, and suitable for environments where privacy, offline execution, and limited computational resources are critical.
## Key Features

*   **Automatic digitization of audiograms** from smartphone photos and scanned reports.
*   **Fully local processing**, with no need to upload medical images to cloud services..
*   **Classical computer vision pipeline**, avoiding dependency on large labeled datasets or black-box inference..
*   **Grid detection and geometric refinement** using Canny edge detection, morphological operations, Hough transforms, and nearest-neighbor refinement.
*   **Localized OCR** for extracting frequency and decibel labels from expected regions of interest.
*   **Symbol detection** for both right-ear and left-ear markers using circle detection, template matching, and DBSCAN clustering.
*   **Structured CSV export** containing extracted audiometric measurements.
*   **Automatic report generation**, including intermediate visualizations and a compiled PDF report (when LaTeX is available).
## How It Works

The pipeline is organized into four main stages:

### 1. Image Pre-processing and Enhancement

The input image is converted to grayscale and enhanced using techniques such as **gamma correction**, **CLAHE (Contrast-Limited Adaptive Histogram Equalization)**, and **unsharp masking** to improve visibility of the grid, symbols, and text labels under different acquisition conditions.
### 2. Grid Detection and Structural Analysis

The system detects the audiogram grid using **Canny edge detection**, **morphological dilation/filling**, and the **Hough transform** to estimate the main horizontal and vertical lines. Grid intersections are then refined using a nearest-neighbor strategy to improve geometric accuracy.

### 3. OCR and Symbol Extraction

Once the grid has been reconstructed, the system extracts text only from **targeted regions of interest** to reduce OCR noise. It then detects hearing-threshold markers using:

*   a **dual-pass circular Hough transform** for right-ear circular symbols, and
*   **template matching + DBSCAN clustering** for left-ear cross-shaped symbols.

### 4. Coordinate Mapping and Output Serialization

Detected symbol positions are mapped from image coordinates to **standard audiometric values** using interpolation:

*   **logarithmic interpolation** on the frequency axis, and
*   **linear interpolation** on the decibel axis.

The final output is saved as a **CSV file** containing `(Frequency_Hz, Intensity_dB)` pairs. The pipeline can also generate visual reports showing grid detection, OCR regions, symbol extraction, and a summary table of results.)
## Why This Project Matters

The project aims to bridge the gap between **legacy analog audiometric records** and **modern digital health systems**. By digitizing static audiograms into machine-readable data, it becomes possible to:

*   build structured repositories of historical hearing tests,
*   support large-scale clinical and longitudinal analyses,
*   reduce manual transcription effort and error,
*   and preserve compliance with privacy requirements through **on-device/local execution**.

## Technologies Used

*   **MATLAB** as the main development environment.
*   **Image Processing Toolbox** for image enhancement, binarization, morphology, skeletonization, and Hough-based detection.
*   **Computer Vision Toolbox** for OCR and geometric processing.
*   **Statistics and Machine Learning Toolbox** functions such as `knnsearch` and `dbscan` for point refinement and clustering.
*   **LaTeX / pdflatex** (optional) for automatic PDF report generation.

## Dataset

The evaluation described in the accompanying article is based on a dataset combining:

*   approximately **420 smartphone-captured photographs** derived from **34 distinct audiograms**
*   plus **30 scanned audiograms** with minimal acquisition artifacts.

After filtering out unusable images affected by severe distortion, blur, truncation, or overexposure, around **50 images** were retained for quantitative evaluation. Additional re-photographed samples were also used to increase acquisition variability while preserving privacy constraints.

## Performance

On the evaluated subset, the system achieved:

*   **87.9% Symbol Accuracy**, and
*   **80.5% Text Accuracy**.

The average processing time was approximately **2.6 seconds per image** on a standard laptop, with memory usage in the range of **200–500 KB per image**, indicating that the approach is lightweight and suitable for resource-constrained environments.

## Repository Structure

A typical repository layout for this project may look like this:

```text
.
├── dataset/
│   ├── *.png
│   ├── *.jpg
│   └── TestDataset/
├── csv_results/
├── audiogram_reports/
├── pipeline.m
└── README.md
```

The main processing script iterates over image files in the dataset folders, exports extracted values to `csv_results/`, and stores visual and PDF reports in `audiogram_reports/`.

## Getting Started

### Requirements

Before running the project, make sure you have:

*   MATLAB installed.
*   The required MATLAB toolboxes for image processing, OCR, and clustering.
*   (Optional) A LaTeX distribution with `pdflatex` if you want automatic PDF reports.

### Installation

1.  Clone this repository.
2.  Place your audiogram images inside the `dataset/` directory (or `dataset/TestDataset/` depending on your setup).
3.  Open MATLAB in the project root directory.

### Run the Pipeline

Execute the main script from MATLAB:

```matlab
run('pipeline.m')
```

If your repository still stores the pipeline as a text file, convert it into a MATLAB script first.

## Output

For each processed audiogram, the pipeline generates:

*   a **CSV file** with extracted frequency and intensity values,
*   images showing **grid detection**, **OCR regions**, and **symbol detection**,
*   and a **PDF report** summarizing the processing workflow and extracted measurements.

The CSV format contains two main columns:

```text
Frequency_Hz, Intensity_dB
```

This makes the output easy to integrate into spreadsheets, statistical analyses, or clinical information systems.

## Current Limitations

The current implementation works best when:

*   the audiogram grid is fully visible,
*   perspective distortion is moderate,
*   and lighting / motion blur do not severely affect local contrast.

Performance may degrade on highly non-standard audiogram layouts, extreme image degradation, handwritten corrections, or severe camera misalignment.

## Future Work

Planned and suggested improvements include:

*   perspective correction through homography estimation,
*   support for additional audiological report layouts and symbol types,
*   and hybrid extensions combining rule-based methods with lightweight neural models, while still preserving the **local-processing** constraint.

## Privacy and Design Philosophy

A central design goal of this project is **privacy preservation**. All computations are performed locally, without relying on external servers or cloud APIs. This makes the system particularly suitable for medical contexts where sensitive patient information must remain on-device or within local institutional infrastructure.


## License

This project is licensed under the **GNU General Public License v3.0**.  
You are free to use, study, modify, and redistribute this software under the terms of the GPL-3.0 license.

See the [LICENSE](./LICENSE) file for the full license text.