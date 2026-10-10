# Actor Tracking Using Color Segmentation and Motion Detection

## Overview

This project implements a computer vision algorithm in MATLAB to detect and track a moving actor in a video sequence using a combination of **color segmentation and motion detection**.

The system was developed using footage from *A Pluma y Espada*, a live show at Puy du Fou España. Due to the proprietary nature of the footage, the original video cannot be included in this repository.

The main objective is to identify an actor based on the color of their clothing and their movement between consecutive frames, then maintain tracking by dynamically adjusting a local search region.

Rather than relying on deep learning or pre-trained object detection models, the algorithm uses classical image processing techniques to perform detection and tracking.

## Objectives

- Detect moving objects by comparing grayscale video frames.
- Segment objects based on a predefined color range in HSV color space.
- Combine color and motion information to reduce false detections.
- Identify candidate regions using connected-component analysis.
- Track the selected actor across successive frames.
- Dynamically expand the search region when the actor is temporarily lost.
- Export the tracking process as a new video for visualization and analysis.

## Methodology

### 1. Motion Detection

Motion is detected by calculating the absolute pixel-wise difference between two grayscale frames.

A configurable threshold determines which pixels are considered to have changed significantly.

```matlab
diffFrame = abs(double(frameB_gray) - double(frameA_gray));
movimientoBinario = diffFrame > umbralMovimiento;
```

This produces a binary mask highlighting regions of movement between the two frames.

### 2. Noise Reduction and Morphological Processing

The initial motion mask may contain isolated pixels, small artifacts and fragmented regions.

Morphological operations are applied to improve the quality of the detection:

- **Opening:** Removes small isolated regions and noise.
- **Closing:** Connects nearby regions and fills small gaps.
- **Area filtering:** Eliminates connected components below a minimum size.

These operations produce a cleaner mask that is more suitable for identifying potential actors.

### 3. Color Segmentation in HSV Space

The input frame is converted from RGB to HSV color space.

A predefined range of hue, saturation and brightness values is used to identify pixels corresponding to the target's blue clothing.

HSV color segmentation provides a more intuitive way to define color ranges than directly thresholding RGB channels.

The resulting binary mask isolates pixels that match the selected color profile.

### 4. Motion and Color Fusion

The color mask is combined with the motion mask using a logical AND operation.

```matlab
mascaraFinal = movimientoLimpio & mascaraColor;
```

Only pixels that satisfy both conditions are retained:

- They belong to the selected color range.
- They exhibit sufficient movement between frames.

This reduces detections caused by static objects with similar colors, as well as moving objects that do not match the target's color.

Additional morphological filtering is applied to consolidate the resulting regions.

### 5. Actor Detection and Localization

The `regionprops` function extracts the bounding box and area of each connected component in the final mask.

When multiple candidate regions are detected, the algorithm selects the one with the largest area.

The selected bounding box is then drawn over the original frame to visualize the detected actor.

This approach provides a simple and computationally lightweight detection mechanism, although it assumes that the largest valid region is the most likely target.

### 6. Region of Interest (ROI)

After the initial detection, a Region of Interest (ROI) is defined around the actor's bounding box.

A configurable margin expands the region to provide additional space for subsequent detections.

Instead of processing the entire frame for every tracking iteration, the algorithm focuses on a smaller area around the actor's last known position.

This reduces the search area and helps limit interference from unrelated objects elsewhere in the scene.

### 7. Adaptive Tracking

The tracking stage combines local color segmentation and frame differencing inside the current ROI.

At each iteration, the algorithm:

1. Extracts the current search region.
2. Computes the color mask in HSV space.
3. Calculates the difference between the current and previous cropped frames.
4. Combines the motion and color masks.
5. Identifies candidate regions and selects the largest component.
6. Updates the actor's bounding box and center coordinates.
7. Adjusts the search region according to the detection result.

When the actor is detected, the ROI returns to its baseline dimensions and follows the newly detected position.

When no valid region is found, the ROI expands progressively to increase the probability of reacquiring the actor.

The expansion is controlled by a multiplicative factor and a maximum width limit.

This mechanism allows the tracker to tolerate temporary detection failures without immediately losing the target.

### 8. Visualization and Video Output

The algorithm displays four synchronized views during execution:

- **Motion mask:** Pixels that differ between frames.
- **Color mask:** Pixels matching the target's color profile.
- **Combined mask:** Pixels satisfying both detection criteria.
- **Tracking result:** The original frame with the current search region and actor bounding box.

The final annotated frames are saved to an AVI video file using MATLAB's `VideoWriter`.

This provides a visual record of the tracking process and helps evaluate the behavior of the algorithm over time.

## Technologies Used

- **MATLAB** — Main development environment.
- **Image Processing Toolbox** — Image segmentation, morphological operations, connected-component analysis and object annotation.
- **VideoReader** — Video input and frame processing.
- **VideoWriter** — Exporting the annotated tracking sequence.
- **HSV Color Space** — Color-based target segmentation.
- **Frame Differencing** — Motion detection.
- **Region of Interest (ROI)** — Localized and adaptive target tracking.

## Algorithm Pipeline

```text
Input Video
    |
    v
Frame Extraction
    |
    +---------------------+
    |                     |
    v                     v
Motion Detection     HSV Color Segmentation
    |                     |
    v                     |
Morphological              |
Filtering                  |
    |                     |
    +----------+----------+
               |
               v
       Mask Fusion
               |
               v
   Connected Components
               |
               v
    Largest Region Selection
               |
               v
      Actor Localization
               |
               v
       ROI Initialization
               |
               v
   Local Motion + Color Detection
               |
               v
       Update Actor Position
               |
               v
    Adaptive ROI Expansion
    if Detection Is Lost
               |
               v
    Annotated Video Output
```

## Parameters and Configuration

The algorithm exposes several parameters that can be adjusted to accommodate different lighting conditions, target colors and movement patterns.

| Parameter | Purpose |
|---|---|
| `numFrames` | Number of frames skipped between processing iterations. |
| `umbralMovimiento` | Minimum grayscale intensity difference required to detect motion. |
| `hueMin`, `hueMax` | Lower and upper hue thresholds for color segmentation. |
| `satMin`, `satMax` | Saturation thresholds. |
| `brillMin`, `brillMax` | Brightness thresholds. |
| `margenDeBusqueda` | Additional margin around the initial detection bounding box. |
| `roiBaseAncho`, `roiBaseAlto` | Baseline dimensions of the tracking ROI. |
| `multiplicadorExpansion` | Factor used to expand the ROI when the target is lost. |
| `roiMaxAncho` | Maximum allowed ROI dimension during expansion. |

These parameters are scene-dependent and may require tuning for different videos, clothing colors and lighting conditions.

## Limitations

The algorithm relies on classical image processing rather than learned object representations. Its performance therefore depends on the characteristics of the scene.

- **Color dependency:** The target must exhibit a sufficiently distinctive color within the selected HSV range.
- **Lighting sensitivity:** Changes in illumination may affect color segmentation and motion thresholds.
- **Occlusions:** Other actors or objects may partially obscure the target.
- **Similar colors:** Other moving objects with similar clothing may produce false detections.
- **Largest-region assumption:** Selecting the largest connected component does not guarantee that the detected region belongs to the intended actor.
- **Motion dependency:** A stationary target may become difficult to detect because the algorithm relies on frame differences.
- **Camera movement:** Significant camera motion may generate widespread differences between frames and reduce detection reliability.

The adaptive ROI helps mitigate temporary detection failures, but it does not guarantee continuous tracking under all conditions.

## Potential Improvements

Several extensions could improve robustness and tracking accuracy:

- Use optical flow to capture motion direction and magnitude.
- Introduce Kalman filtering to estimate the actor's position during temporary detection failures.
- Use connected-component proximity and trajectory history instead of relying exclusively on the largest region.
- Add adaptive HSV thresholds to handle changing lighting conditions.
- Incorporate background subtraction or more advanced tracking algorithms.
- Explore deep learning-based object detection for scenes with multiple actors or frequent occlusions.

## Key Takeaways

This project demonstrates how classical computer vision techniques can be combined to build a lightweight actor-tracking system without requiring a trained neural network.

The most important aspect is the fusion of two complementary sources of information: **color identifies what the target looks like, while frame differencing identifies what is moving**.

The adaptive ROI extends this approach by focusing computation around the actor's last known position and progressively expanding the search region when detection fails.

The project provided practical experience in image processing, video analysis, object localization and the development of stateful tracking logic for dynamic scenes.

## Author

**Marcos del Cerro Villanueva**

Master's Degree in Robotics and Automation

Interests: Computer Vision, Robotics, Autonomous Systems and Intelligent Control.
