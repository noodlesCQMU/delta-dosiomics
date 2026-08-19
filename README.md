# Hierarchical Radiotherapy Error Identification Using 3D Dose-Difference Maps

## Overview

This repository contains core MATLAB code used to process three-dimensional (3D) radiotherapy dose-difference maps and to develop machine-learning and deep-learning models for radiotherapy error identification during patient-specific quality assurance (PSQA).

The uploaded code package mainly provides **Level-1 analysis examples**, including DICOM dose-difference generation, BODY-based 3D volume preprocessing, delta-dosiomics machine-learning analysis, transfer learning with a 3D ResNet-50, and bootstrap-based model evaluation. Scripts for the complete Level-2 and Level-3 analyses are not included in the current package.

> **Reproducibility status.** The current folder contains the core analysis scripts but is **not yet a fully self-contained, one-command reproducibility package**. Several custom helper functions, intermediate datasets, trained model files, and the dosiomics feature-extraction step are referenced by the scripts but are not present in the uploaded archive. These dependencies are listed below so that the repository does not overstate reproducibility.

## Repository structure

```text
.
├── processing/
│   ├── Diff_Dicom_generation.m
│   ├── Diff_Dicom_generation.mlx
│   └── Feature_ROI.mlx
│
├── machine_learning/
│   ├── Body_Clinical_Level1.mlx
│   └── Boostrap2000_Level1.mlx
│
└── Deep_learning/
    ├── MLC-DeepLearning-Clinic-Test-Level1.mlx
    ├── resnet50TL3Dfun.mlx
    ├── params.mat
    ├── Bootstrap_CTEST_Level1.mlx
    └── license.txt
```

## Recommended workflow

Two preprocessing routes are represented in the uploaded files. They should be regarded as **alternative implementations**, rather than scripts that must all be run sequentially.

### Route A — combined dose-difference and deep-learning volume generation

`processing/Diff_Dicom_generation.mlx` reads RTSTRUCT and RTDOSE DICOM files, identifies the reference dose, calculates 3D dose differences, extracts the ROI, resamples the resulting volume to the deep-learning input size, and saves both DICOM dose-difference maps and MATLAB volumes. This route requires the missing helper functions `cal_diff` and `ROI_extract` (and, in an optional bladder-processing branch, `CROPDICOM`).

### Route B — DICOM dose-difference generation followed by ROI preprocessing

Run `processing/Diff_Dicom_generation.m` to generate signed dose-difference DICOM files. Then run `processing/Feature_ROI.mlx` to map the BODY contour from the RTSTRUCT to the dose grid, interpolate missing mask slices when necessary, crop the BODY region, resample it to `224 × 224 × 224`, set voxels outside the ROI to zero, and save the resulting 3D MATLAB volumes in label-specific folders.

After either preprocessing route, the two modelling branches can be run independently:

```text
3D RTDOSE + RTSTRUCT
        │
        ├── Dose-difference generation
        │
        ├──────────────► DICOM dose-difference maps
        │                       │
        │                       └──► external dosiomics feature extraction
        │                                    │
        │                                    └──► CSV feature tables
        │                                             │
        │                                             └──► machine-learning branch
        │
        └── ROI extraction/resampling ──► 224×224×224 MAT volumes
                                                  │
                                                  └──► 3D ResNet-50 branch
```

## File-by-file description

| File                                                    | Purpose                                                                                                                                                                                                                                                                                                                                                                                 | Main input                                                                                                                                                                                                      | Main output                                                                                                                                     | Important dependencies / notes                                                                                                                                                                                                                                       |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `processing/Diff_Dicom_generation.mlx`                  | Primary live-script implementation for generating signed 3D dose-difference maps. It searches a selected patient folder for RTSTRUCT and RTDOSE files, identifies the reference dose, computes dose differences, optionally extracts/resamples an ROI for deep learning, assigns files to Level-1 label folders according to filename patterns, and writes dose-difference DICOM files. | A folder containing an RTSTRUCT file, a reference RTDOSE, and error-induced RTDOSE files.                                                                                                                       | Signed dose-difference DICOM files in a `diff/` subfolder; `224×224×224` MAT volumes stored as `Diff_interp` when the ROI branch is used.       | Requires custom `cal_diff` and `ROI_extract`; optional code also calls `CROPDICOM`. These functions are not included. Hard-coded Windows paths must be replaced before use.                                                                                          |
| `processing/Diff_Dicom_generation.m`                    | Alternate/older script-oriented version of dose-difference generation. It computes common-grid dose differences and writes signed RTDOSE DICOM files for downstream analysis and visual inspection. It also contains optional comparisons using different reference dose distributions.                                                                                                 | RTSTRUCT and multiple RTDOSE DICOM files in a patient folder.                                                                                                                                                   | Signed dose-difference DICOM files and verification plots.                                                                                      | Calls `cal_diff`, which is not included. This `.m` version and the `.mlx` version are not identical; use one validated implementation consistently.                                                                                                                  |
| `processing/Feature_ROI.mlx`                            | Extracts the BODY ROI from RTSTRUCT, maps it to the RTDOSE grid, fills/interpolates missing mask slices, performs morphological cleanup, crops the 3D volume, resamples it to `224×224×224`, zeros voxels outside the ROI, and saves label-organized MAT files for 3D deep learning.                                                                                                    | RTSTRUCT plus dose-difference DICOM files in the same folder.                                                                                                                                                   | MAT files containing `cropImage`, organized into label folders such as `SETUP`, `MU`, `MLCR`, `MLCS`, `Gantry`, `ErrorFree`, and `BodyChanges`. | Uses DICOM and image-processing functions including `dicomContours`, `poly2mask`, `bwdist`, `strel`, `imclose`, `imfill`, and `interp3`. Hard-coded example paths and numeric IDs must be removed or de-identified before public release.                            |
| `machine_learning/Body_Clinical_Level1.mlx`             | Level-1 delta-dosiomics machine-learning workflow. Reads a feature table, creates a hold-out split, removes highly correlated features, performs recursive feature selection, selects the final 20 features, trains/evaluates RF, XGBoost, SVM, and neural-network classifiers, evaluates a clinical test table, and plots ROC curves.                                                  | `Body_Clinical_Level1.csv` and `Body_ClinicalTest_Level1.csv`. The script uses columns 1–108, corresponding to one label column plus 107 feature columns.                                                       | Selected features, trained model objects, performance metrics, confusion matrices, and ROC figures in the MATLAB workspace.                     | Requires custom functions `correlate_feature`, `FeatureToRecursion`, `RandomForest`, `XGBoost`, `SVM`, `NeuralNet`, `eval_model`, `AddNoise`, `Clinicaleval_model`, `XGBoost_eval_model`, `plot_roc_curve`, and `plot_roc_curve4`. These functions are not included. |
| `machine_learning/Boostrap2000_Level1.mlx`              | Performs 2,000 stratified bootstrap resamples for the Level-1 SVM, neural-network, and XGBoost models on two test datasets. It evaluates ROC-AUC, accuracy, precision, recall, F1-score and related metrics, aligns class/score order, generates bootstrap confidence intervals, and exports ROC data.                                                                                  | `BodyClinicalLevel1.mat` containing the required datasets, trained models and selected features.                                                                                                                | `ML_Bootstrap2000_TwoTestSets.xlsx`; per-model ROC figures; bootstrap metric sheets and detailed ROC/AUC data.                                  | The bootstrap code itself is largely self-contained, but still depends on the missing custom `XGBoost` function and on model/data variables saved from the preceding workflow.                                                                                       |
| `Deep_learning/resnet50TL3Dfun.mlx`                     | Reconstructs the pretrained 3D ResNet-50 layer graph used for transfer learning. The network accepts a `224×224×224×1` input and loads pretrained layer parameters from `params.mat`.                                                                                                                                                                                                   | `params.mat`.                                                                                                                                                                                                   | MATLAB `layerGraph` returned as `lgraph`.                                                                                                       | The original final layer has 1,000 outputs and is replaced by the training script for the target number of classes.                                                                                                                                                  |
| `Deep_learning/params.mat`                              | Stores pretrained parameters used by `resnet50TL3Dfun.mlx`, including convolutional, batch-normalization and fully connected layer parameters.                                                                                                                                                                                                                                          | None.                                                                                                                                                                                                           | Loaded network parameters.                                                                                                                      | The file is approximately 129 MiB and should be handled using Git LFS or an external persistent archive rather than normal Git tracking. Preserve the accompanying third-party license.                                                                              |
| `Deep_learning/MLC-DeepLearning-Clinic-Test-Level1.mlx` | Level-1 3D ResNet-50 transfer-learning workflow. Creates an `imageDatastore` from label folders, makes an 80/20 split, performs five-fold stratified cross-validation within the training portion, replaces the 1,000-class output with a 7-class output, trains five models with Adam, evaluates independent/clinical test sets, and draws confusion matrices.                         | A folder tree containing `.mat` 3D volumes in class-named subfolders; `params.mat`; `resnet50TL3Dfun.mlx`; custom `matRead`; later sections also load several intermediate/test MAT files and trained networks. | Five trained networks, five training-info MAT files, validation/test predictions, scores, metrics, and confusion matrices.                      | Requires custom `matRead`, `Eval_Metrics`, and `EvalDeepModel`, which are not included.                                                                                                                                                                              |
| `Deep_learning/Bootstrap_CTEST_Level1.mlx`              | Performs 2,000 stratified bootstrap evaluations for five trained 3D ResNet-50 fold models and their probability-averaged ensemble. It computes macro AUC, accuracy, macro/weighted precision, recall and F1, and generates a macro-average ROC curve with 95% confidence intervals.                                                                                                     | Clinical test datastore and five trained network MAT files.                                                                                                                                                     | `Bootstrap_Metrics_Results.xlsx`, `Ensemble_Macro_ROC_with_95CI.png`, and `Ensemble_ROC_Curve_95CI.xlsx`.                                       | Prediction is performed on CPU in the current evaluation script; bootstrap seed is fixed for reproducibility.                                                                                                                                                        |
| `Deep_learning/license.txt`                             | Third-party license accompanying the pretrained 3D network assets.                                                                                                                                                                                                                                                                                                                      | None.                                                                                                                                                                                                           | License notice.                                                                                                                                 | This license should be retained with relevant redistributed third-party files. It should not automatically be treated as the license for all code in this repository.                                                                                                |

## Input data conventions

### DICOM preprocessing

The preprocessing scripts expect an RTSTRUCT and multiple RTDOSE files in a common patient directory. Filename matching is used extensively to determine the reference distribution and error category. Therefore, users must adapt the filename rules in the scripts to their own export convention.

Dose differences are stored as **signed** values, allowing both positive and negative dose deviations to be retained.

### Deep-learning volumes

The 3D deep-learning workflow expects MAT files stored in subdirectories whose folder names serve as class labels through:

```matlab
imageDatastore(..., 'LabelSource', 'foldernames')
```

The preprocessing files in this archive save either `Diff_interp` or `cropImage`, depending on the selected preprocessing route. The missing custom `matRead` function must load the appropriate 3D numeric array and return it in the format expected by the network.

The pretrained network expects a single-channel input of:

```text
224 × 224 × 224 × 1
```

### Dosiomics feature tables

`machine_learning/Body_Clinical_Level1.mlx` expects a table whose first column is `Label` followed by 107 features. The current script reads the first 108 columns.

The code that extracts these 107 dosiomics features from the dose-difference maps is **not included in the uploaded repository**, so this step must either be added to the repository or documented as an external prerequisite.

## Machine-learning workflow details

The uploaded Level-1 machine-learning script implements the following sequence:

1. Read the delta-dosiomics feature table.
2. Create a hold-out training/test split.
3. Remove highly correlated features using a correlation threshold of `0.8`.
4. Apply recursive feature selection using the custom `FeatureToRecursion` routine.
5. Retain the final 20 features.
6. Train/evaluate the available RF, XGBoost, SVM and neural-network models.
7. Load a separate clinical test feature table and evaluate the trained models.
8. Use `Boostrap2000_Level1.mlx` for 2,000-resample confidence intervals and ROC analysis of the SVM, neural-network and XGBoost models.

## Deep-learning workflow details

The Level-1 deep-learning script reconstructs a pretrained 3D ResNet-50 from `params.mat`, replaces the original 1,000-class fully connected/classification output with a seven-class output, and trains five cross-validation models. The bootstrap script then evaluates each model and an ensemble formed by averaging the five probability matrices.

The current training configuration is:

| Setting               |               Value in uploaded script |
| --------------------- | -------------------------------------: |
| Optimizer             |                                   Adam |
| Input size            |                  `224 × 224 × 224 × 1` |
| Initial learning rate |                            `1 × 10^-4` |
| Mini-batch size       |                                     16 |
| Maximum epochs        |                                     20 |
| LR schedule           |                              Piecewise |
| LR drop factor        |                                    0.5 |
| LR drop period        |                               5 epochs |
| Validation patience   |                                      8 |
| L2 regularization     |                            `1 × 10^-4` |
| Cross-validation      | 5-fold, stratified within `Data_Train` |
| Training execution    |                                    GPU |
| Bootstrap resamples   |                                  2,000 |
| Bootstrap type        |                             Stratified |
| Bootstrap seed        |                                   2026 |

## Required MATLAB environment

The uploaded live scripts were saved across MATLAB releases from R2020b to R2024b. **MATLAB R2024b or later is recommended** for the public repository to maximize compatibility with the most recent scripts.

Likely required products include MATLAB, Image Processing Toolbox, Statistics and Machine Learning Toolbox, Deep Learning Toolbox, Parallel Computing Toolbox for GPU training, and the XGBoost interface used by the custom XGBoost routine.

## Missing files/functions required for full reproduction

```text
Preprocessing helpers
  cal_diff
  ROI_extract
  CROPDICOM              (optional branch)

Machine-learning helpers
  correlate_feature
  FeatureToRecursion
  RandomForest
  XGBoost
  SVM
  NeuralNet
  eval_model
  AddNoise
  Clinicaleval_model
  XGBoost_eval_model
  plot_roc_curve
  plot_roc_curve4

Deep-learning helpers
  matRead
  Eval_Metrics
  EvalDeepModel

Intermediate/model files referenced by scripts
  BodyClinicalLevel1.mat
  DP_data.mat
  Data_ClinicTest.mat
  DeepTESTData.mat
  3DRESNetCV1-*.mat ... 3DRESNetCV5-*.mat

Input feature tables
  Body_Clinical_Level1.csv
  Body_ClinicalTest_Level1.csv

Not included
  Dosiomics feature-extraction code that generates the 107-feature tables
```

For a publication-facing repository, these custom helper functions should ideally be added, or the README/Code Availability statement should explicitly state which parts of the workflow are provided and which are unavailable because of software, licensing, data-access, or institutional restrictions.

## Important reproducibility issue: patient-level splitting

The currently uploaded scripts do **not** implement an explicit patient-level split.

`machine_learning/Body_Clinical_Level1.mlx` uses:

```matlab
cvpartition(ori_data.Label,'holdout',0.20)
```

which partitions rows/samples.

`Deep_learning/MLC-DeepLearning-Clinic-Test-Level1.mlx` uses:

```matlab
splitEachLabel(Data_all,0.8,0.2,'randomized')
```

which also partitions samples in the datastore.

If the associated manuscript reports **patient-level splitting**, the public code should be updated before release so that all samples derived from a given patient are assigned to only one partition.

A recommended approach is to provide a de-identified split file containing:

```text
SampleID
PatientGroupID
Split
```

and have both the machine-learning and deep-learning scripts read the same predefined split rather than generating a new random hold-out split.

## Before public release

1. Remove or replace all hard-coded patient/example numeric identifiers with de-identified placeholders.
2. Replace all local Windows drive paths with relative paths or configuration variables.
3. Confirm that no DICOM headers, filenames, MAT files, CSV files, screenshots, or comments contain protected health information.
4. Add the missing custom helper functions required to reproduce the reported analyses, where sharing is permitted.
5. Convert key `.mlx` live scripts to plain `.m` files where possible so that GitHub can display diffs and reviewers can inspect the code without MATLAB Live Editor.
6. Provide a fixed, de-identified patient-level split if patient-level separation is part of the manuscript methods.
7. Move `params.mat` to Git LFS or a persistent external archive.
8. Add a top-level license for the authors' own code and retain `Deep_learning/license.txt` for the third-party pretrained network assets.

## Suggested public repository layout

```text
.
├── README.md
├── LICENSE
├── config.example.m
├── processing/
│   ├── generate_dose_difference.m
│   ├── extract_body_roi.m
│   └── helpers/
│       ├── cal_diff.m
│       └── ROI_extract.m
├── machine_learning/
│   ├── train_level1_models.m
│   ├── bootstrap_level1.m
│   └── helpers/
├── deep_learning/
│   ├── train_resnet50_level1.m
│   ├── bootstrap_resnet50_level1.m
│   ├── resnet50TL3Dfun.m
│   └── helpers/
├── splits/
│   └── splits_example.csv
└── examples/
    └── expected_input_structure.md
```

## Data availability and privacy

Patient-level RTDOSE, RTSTRUCT, clinical data, and any files containing identifiable metadata should **not** be placed in this repository.

Where clinical data cannot be shared publicly because of privacy, ethics, or institutional restrictions, provide a clear data-availability statement and, when possible, include a small synthetic or de-identified example showing the required input structure.

## Code availability statement for the manuscript

A conservative statement consistent with the current scope of this repository would be:

> The custom code supporting the core preprocessing, model development, and performance evaluation workflows in this study is available at [GitHub repository URL]. Patient-level clinical and imaging data are not publicly available because of privacy and institutional restrictions.

Do not state that **all code required to reproduce the study** is publicly available until the missing custom helper functions and the actual patient-level split implementation have been added or otherwise documented.

## Citation

If you use this code, please cite the associated article:

```text
[Add the final article citation and DOI after publication.]
```

## Contact

For questions regarding the code or analysis workflow, please contact the corresponding author listed in the associated publication.
