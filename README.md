# Hierarchical Radiotherapy Error Identification Using 3D Dose-Difference Maps

## Overview

This repository contains the core MATLAB code used in our study for hierarchical identification of radiotherapy errors during patient-specific quality assurance (PSQA) using three-dimensional (3D) dose-difference maps.

The workflow integrates two complementary analysis strategies:

1. **Delta-dosiomics-based machine learning**, in which quantitative features are extracted from 3D dose-difference maps and used to train conventional machine-learning classifiers.
2. **3D deep learning**, in which a pretrained 3D ResNet-50 is fine-tuned directly on preprocessed 3D dose-difference maps.

The radiotherapy errors are organized hierarchically according to error type, direction, and magnitude. The code provided here contains the preprocessing, feature-selection, model-development, patient-level data splitting, bootstrap evaluation, and 3D ResNet-50 transfer-learning procedures used in the study.

> **Important:** Patient-level clinical imaging, RTDOSE, RTSTRUCT, and other potentially identifiable data are not included in this repository because of privacy, ethical, and institutional restrictions.

---

## Repository structure

```text
.
├── README.md
├── LICENSE
│
├── processing/
│   ├── Diff_Dicom_generation.m
│   ├── Diff_Dicom_generation.mlx
│   ├── Feature_ROI.mlx
│   └── helpers/
│       ├── cal_diff.m
│       ├── ROI_extract.m
│       └── CROPDICOM.m
│
├── machine_learning/
│   ├── Body_Clinical_Level1_patient_split.m
│   ├── Boostrap2000_Level1.mlx
│   └── helpers/
│       ├── correlate_feature.m
│       ├── FeatureToRecursion.m
│       ├── RandomForest.m
│       ├── XGBoost.m
│       ├── SVM.m
│       ├── NeuralNet.m
│       ├── eval_model.m
│       ├── AddNoise.m
│       ├── Clinicaleval_model.m
│       ├── XGBoost_eval_model.m
│       ├── plot_roc_curve.m
│       └── plot_roc_curve4.m
│
├── Deep_learning/
│   ├── MLC_DeepLearning_Clinic_Test_Level1_patient_split.m
│   ├── resnet50TL3Dfun.mlx
│   ├── Bootstrap_CTEST_Level1.mlx
│   ├── params.mat
│   ├── license.txt
│   └── helpers/
│       ├── matRead.m
│       ├── Eval_Metrics.m
│       └── EvalDeepModel.m
│
└── splits/
    └── patient_split.csv
```

The exact filenames may be adjusted in future releases, but the analysis sequence described below should be preserved.

---

## Analysis workflow

The overall analysis pipeline is:

```text
Original RTDOSE + error-induced RTDOSE + RTSTRUCT
                     │
                     ▼
          3D dose-difference generation
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
  DICOM dose-difference    BODY ROI extraction
        maps               and resampling
          │                     │
          ▼                     ▼
 Dosiomics feature        224 × 224 × 224
     extraction              MAT volumes
          │                     │
          ▼                     ▼
 Feature selection        3D ResNet-50
          │               transfer learning
          ▼                     │
 ML model development           │
          └──────────┬──────────┘
                     ▼
        Independent test evaluation
                     │
                     ▼
       Clinical validation evaluation
                     │
                     ▼
        Bootstrap confidence intervals
```

The machine-learning and deep-learning branches use the **same fixed patient-level data split** defined in `splits/patient_split.csv`.

---

# 1. Preprocessing

## `processing/Diff_Dicom_generation.m`

### Purpose

Generates signed 3D dose-difference distributions from the original/reference RTDOSE and error-induced RTDOSE distributions.

### Input

- RTSTRUCT DICOM file
- Reference/original RTDOSE DICOM file
- Error-induced RTDOSE DICOM files

### Main operations

1. Read RTDOSE and RTSTRUCT information.
2. Identify the reference dose distribution.
3. Align dose grids when necessary.
4. Calculate the signed dose difference:

```text
Dose difference = Error-induced dose − Original dose
```

5. Preserve positive and negative dose deviations.
6. Write the resulting dose-difference distribution as an RTDOSE-compatible DICOM file.

### Output

- Signed 3D dose-difference DICOM files
- Optional verification figures

### Dependencies

- `processing/helpers/cal_diff.m`

---

## `processing/Diff_Dicom_generation.mlx`

### Purpose

Live-script implementation of the dose-difference generation workflow, with additional preprocessing options for subsequent deep-learning analysis.

### Input

Same as `Diff_Dicom_generation.m`.

### Main operations

- Dose-difference generation
- ROI extraction where enabled
- Volume resampling
- Organization of output data by error category

### Output

Depending on the selected branch:

- 3D dose-difference DICOM files
- Resampled 3D MATLAB arrays such as `Diff_interp`

### Dependencies

- `cal_diff.m`
- `ROI_extract.m`
- `CROPDICOM.m` where the optional crop routine is used

---

## `processing/Feature_ROI.mlx`

### Purpose

Maps the BODY structure from RTSTRUCT to the dose grid and prepares BODY-based 3D dose-difference volumes for deep learning.

### Input

- RTSTRUCT DICOM
- 3D dose-difference DICOM files

### Main operations

1. Read BODY contours from RTSTRUCT.
2. Convert contours into a voxelized 3D mask on the dose grid.
3. Interpolate missing mask slices where necessary.
4. Perform mask cleanup and morphological processing.
5. Crop the BODY-containing region.
6. Resample the volume to:

```text
224 × 224 × 224
```

7. Set voxels outside the BODY ROI to zero.
8. Save the processed volume into label-specific subdirectories.

### Output

- `.mat` files containing preprocessed 3D volumes
- Typical variable name: `cropImage`

### Expected directory structure

```text
DeepLearningData/
├── SETUP/
├── MU/
├── MLCR/
├── MLCS/
├── Gantry/
├── BodyChanges/
└── ErrorFree/
```

The folder names are used as class labels by MATLAB `imageDatastore`.

---

# 2. Delta-dosiomics feature extraction

The machine-learning workflow assumes that dosiomics features have been extracted from the 3D dose-difference maps before model development.

The feature table used by the current Level-1 workflow should contain:

```text
PatientID
Label
Feature_1
Feature_2
...
Feature_107
```

`PatientID` is used only for dataset assignment and is **never used as a model feature**.

The feature-extraction configuration should be kept identical across the training, independent test, and clinical validation cohorts.

---

# 3. Machine-learning workflow

## `machine_learning/Body_Clinical_Level1_patient_split.m`

### Purpose

Performs Level-1 delta-dosiomics feature selection, model development, and evaluation using a fixed patient-level split.

### Input

- Dosiomics feature table containing `PatientID`, `Label`, and feature columns
- `splits/patient_split.csv`

### Main operations

1. Read the feature table.
2. Match each sample to `patient_split.csv` through `PatientID`.
3. Create:
   - training set,
   - independent test set,
   - clinical validation set.
4. Verify that no patient appears in more than one set.
5. Remove highly correlated features.
6. Perform recursive feature selection.
7. Select the final feature subset.
8. Train the machine-learning classifiers.
9. Evaluate the trained models on the independent test and clinical validation sets.
10. Generate ROC curves, confusion matrices, and classification metrics.

### Feature selection

The workflow includes:

```text
Correlation filtering
        ↓
Recursive feature selection
        ↓
Final selected feature set
```

The correlation threshold used in the original implementation is:

```text
|ρ| > 0.8
```

Highly correlated features are removed before recursive selection.

### Models

The workflow includes:

- Support Vector Machine (SVM)
- Artificial Neural Network (ANN)
- Extreme Gradient Boosting (XGBoost)
- Random Forest (RF), where applicable in the corresponding analysis script

### Output

Typical outputs include:

- selected feature names,
- trained model objects,
- predicted class labels,
- class probabilities/scores,
- confusion matrices,
- ROC curves,
- AUC,
- accuracy,
- precision,
- recall,
- F1-score.

### Dependencies

The helper functions are located in:

```text
machine_learning/helpers/
```

and include:

```text
correlate_feature.m
FeatureToRecursion.m
RandomForest.m
XGBoost.m
SVM.m
NeuralNet.m
eval_model.m
AddNoise.m
Clinicaleval_model.m
XGBoost_eval_model.m
plot_roc_curve.m
plot_roc_curve4.m
```

---

# 4. Machine-learning bootstrap evaluation

## `machine_learning/Boostrap2000_Level1.mlx`

### Purpose

Estimates model performance and 95% confidence intervals using stratified bootstrap resampling.

### Input

- trained machine-learning models,
- selected feature set,
- independent test data,
- clinical validation data.

### Bootstrap settings

```text
Number of bootstrap resamples: 2000
Random seed: 2026
Bootstrap strategy: stratified
```

### Evaluated metrics

- ROC-AUC
- accuracy
- precision
- recall
- F1-score

Where appropriate, macro-averaged metrics are used for multiclass evaluation.

### Output

Examples include:

```text
ML_Bootstrap2000_TwoTestSets.xlsx
```

together with ROC figures and detailed model-specific evaluation results.

---

# 5. 3D ResNet-50 transfer learning

## `Deep_learning/resnet50TL3Dfun.mlx`

### Purpose

Constructs the pretrained 3D ResNet-50 architecture used for transfer learning.

### Input

```text
params.mat
```

### Network input

```text
224 × 224 × 224 × 1
```

### Output

- MATLAB `layerGraph`
- pretrained convolutional feature extractor ready for task-specific fine-tuning

The original classification layer is replaced according to the number of target classes.

---

## `Deep_learning/MLC_DeepLearning_Clinic_Test_Level1_patient_split.m`

### Purpose

Trains and evaluates the Level-1 3D ResNet-50 using the same fixed patient-level split as the machine-learning workflow.

### Input

- preprocessed `.mat` volumes,
- `splits/patient_split.csv`,
- `params.mat`,
- helper functions,
- class labels encoded by folder names.

### Patient-level split

The script maps each `.mat` file to a de-identified `PatientID` and obtains the corresponding dataset assignment from `patient_split.csv`.

It creates:

- `Data_Train`
- `Data_Test`
- `Data_clinic_Test`

without using sample-level random splitting.

### Five-fold cross-validation

The `CVFold` column in `patient_split.csv` defines the grouped patient-level cross-validation folds.

For each fold:

```text
CVFold = current fold   → validation patients
CVFold ≠ current fold   → training patients
```

All samples from a patient remain in the same fold.

### Training configuration

The current implementation uses:

| Setting | Value |
|---|---:|
| Architecture | 3D ResNet-50 |
| Optimizer | Adam |
| Input size | `224 × 224 × 224 × 1` |
| Initial learning rate | `1 × 10^-4` |
| Mini-batch size | 16 |
| Maximum epochs | 20 |
| LR schedule | Piecewise |
| LR drop factor | 0.5 |
| LR drop period | 5 epochs |
| Validation patience | 8 |
| L2 regularization | `1 × 10^-4` |
| Cross-validation | Fixed patient-level 5-fold |
| Training execution | GPU |

### Output

- five trained fold-specific 3D ResNet-50 models,
- training information,
- validation predictions,
- independent test predictions,
- clinical validation predictions,
- confusion matrices,
- classification metrics.

Typical saved model names may follow:

```text
3DRESNet_Level1_PatientCV_Fold1.mat
3DRESNet_Level1_PatientCV_Fold2.mat
3DRESNet_Level1_PatientCV_Fold3.mat
3DRESNet_Level1_PatientCV_Fold4.mat
3DRESNet_Level1_PatientCV_Fold5.mat
```

### Dependencies

```text
Deep_learning/helpers/matRead.m
Deep_learning/helpers/Eval_Metrics.m
Deep_learning/helpers/EvalDeepModel.m
```

---

# 6. Deep-learning bootstrap evaluation

## `Deep_learning/Bootstrap_CTEST_Level1.mlx`

### Purpose

Performs 2,000 stratified bootstrap evaluations of the trained 3D ResNet-50 models and their ensemble.

### Input

- clinical validation datastore,
- five trained fold-specific 3D ResNet-50 models.

### Ensemble strategy

Predicted class-probability matrices from the five models are averaged:

```text
Ensemble probability =
(mean of probabilities from Fold 1–Fold 5)
```

### Metrics

- macro ROC-AUC
- accuracy
- macro precision
- macro recall
- macro F1-score
- weighted precision
- weighted recall
- weighted F1-score

### Bootstrap settings

```text
Number of bootstrap resamples: 2000
Random seed: 2026
Bootstrap strategy: stratified
```

### Output

Typical output files include:

```text
Bootstrap_Metrics_Results.xlsx
Ensemble_Macro_ROC_with_95CI.png
Ensemble_ROC_Curve_95CI.xlsx
```

---

# 7. Recommended execution order

For a new dataset, run the workflow in the following order.

## Step 1 — Prepare DICOM data

Organize the RTSTRUCT, original RTDOSE, and error-induced RTDOSE files according to the naming rules used by the preprocessing scripts.

## Step 2 — Generate 3D dose-difference maps

Run either:

```text
processing/Diff_Dicom_generation.m
```

or the validated live-script implementation:

```text
processing/Diff_Dicom_generation.mlx
```

## Step 3A — Prepare data for machine learning

1. Extract dosiomics features from the generated 3D dose-difference maps.
2. Create the feature table containing:
   - `PatientID`
   - `Label`
   - feature columns.
3. Confirm that every `PatientID` exists in `splits/patient_split.csv`.

Then run:

```text
machine_learning/Body_Clinical_Level1_patient_split.m
```

followed by:

```text
machine_learning/Boostrap2000_Level1.mlx
```

## Step 3B — Prepare data for deep learning

Run:

```text
processing/Feature_ROI.mlx
```

to generate `224 × 224 × 224` MAT volumes.

Then run:

```text
Deep_learning/MLC_DeepLearning_Clinic_Test_Level1_patient_split.m
```

followed by:

```text
Deep_learning/Bootstrap_CTEST_Level1.mlx
```

The machine-learning and deep-learning branches may be run independently after preprocessing.

---

# 8. Input and output summary

| Stage | Main input | Main output |
|---|---|---|
| Dose-difference generation | Original and error-induced RTDOSE | Signed 3D dose-difference DICOM |
| ROI preprocessing | RTSTRUCT + dose-difference DICOM | `224×224×224` MAT volumes |
| Dosiomics extraction | Dose-difference maps | Feature table |
| Patient split | `patient_split.csv` | Fixed Train/Test/Clinical/CV assignment |
| ML model development | Feature table | Trained ML models + predictions |
| DL model development | MAT volumes | Five trained 3D ResNet-50 models |
| ML bootstrap | ML predictions/models | 95% CIs + ROC/metrics |
| DL bootstrap | DL predictions/models | 95% CIs + ensemble ROC/metrics |

---

# 9. MATLAB environment

The code was developed using MATLAB and requires functions from several MathWorks toolboxes.

Recommended environment:

```text
MATLAB R2024b or later
```

Expected toolboxes include:

- Image Processing Toolbox
- Statistics and Machine Learning Toolbox
- Deep Learning Toolbox
- Parallel Computing Toolbox

A CUDA-compatible GPU is recommended for 3D ResNet-50 training.

The XGBoost workflow additionally requires the XGBoost interface used by the provided helper implementation.

---

# 10. Pretrained 3D ResNet-50 parameters

`Deep_learning/params.mat` contains pretrained parameters used to initialize the 3D ResNet-50.

Because this file is larger than the normal GitHub per-file Git limit, it could be get from :
https://ww2.mathworks.cn/matlabcentral/fileexchange/87427-pre-trained-3d-resnet-50
---

# 11. Data privacy

The repository does not include:

- patient RTDOSE files,
- patient RTSTRUCT files,
- raw DICOM images,
- identifiable Patient IDs,
- clinical records,
- institutional file paths,
- other protected health information.

All identifiers used in public examples and split files should be de-identified.

Users applying this code to clinical data are responsible for ensuring compliance with their institutional review board, ethics approval, data-use agreements, and applicable privacy regulations.

---

# 14. Code availability

The custom code supporting the main preprocessing, delta-dosiomics analysis, machine-learning, 3D deep-learning, and performance-evaluation workflows is provided in this repository.

Patient-level clinical imaging, dose, and treatment-planning data are not publicly distributed because of patient privacy and institutional restrictions.

For the associated manuscript, a suitable Code Availability statement is:

> The custom code supporting the main analyses and findings of this study is publicly available at [GitHub repository URL]. Patient-level clinical imaging and radiotherapy data are not publicly available because of privacy, ethical, and institutional restrictions.

---


# 15. Contact

For questions regarding the code, preprocessing workflow, or model implementation, please contact the corresponding author listed in the associated publication.

---

## Disclaimer

This repository is intended for research and academic use. The code has not been developed or validated as a standalone clinical decision-support system and should not be used for direct patient-care decisions without appropriate independent validation.

