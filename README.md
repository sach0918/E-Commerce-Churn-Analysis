# E-Commerce-Churn-Analysis

## Problem Statement
77.4% of customers on the Olist e-commerce platform had not placed 
an order in over 180 days. This project identifies the key drivers 
of churn and surfaces actionable retention strategies using SQL 
and Python.

## Pipeline
Raw Kaggle Data → SQL Cleaning → RFM Feature Engineering → 
Python EDA → ML Modelling → Business Recommendations

## Key Results
| Metric | Value |
| Dataset Size | 90k+ customers |
| Churn Rate | 77.4% |
| Best Model | Random Forest |
| ROC-AUC | 0.705 |
| Churner Recall | 86% |

## Key Findings
- Churn follows non-linear patterns — Random Forest (0.705) 
  significantly outperformed Logistic Regression (0.518)
- Average order frequency of 1.008 suggests most customers 
  are one-time buyers — a structural retention problem
- 64% of customers left no review — limiting satisfaction 
  as a predictive signal

## Business Recommendations
1. Trigger re-engagement campaigns at 120–150 days inactivity 
   before customers cross the churn threshold
2. Prioritise retention budget on top 25% monetary-value customers 
   — highest ROI for win-back offers
3. Introduce one-click post-purchase reviews to fill the 64% 
   review data gap and improve future model performance

## Tech Stack
| Layer | Tools |
| Data Cleaning | MySQL (SQL) |
| Feature Engineering | SQL — RFM table, churn flag |
| Analysis & Modelling | Python, Pandas, Scikit-learn |
| Visualisation | Matplotlib, Seaborn |
| Environment | Jupyter Notebook, Kaggle |

## File Structure
| File | Description |
| sql/01_data_cleaning.sql | Table renaming, date cleaning, validation |
| sql/02_feature_engineering.sql | Master table, RFM, delivery analysis, churn flag |
| notebooks/churn_analysis.ipynb | Full EDA and ML modelling notebook |

## Dataset
Olist Brazilian E-Commerce — Kaggle
