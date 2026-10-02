# Loan Data Query App (AWS)

BIA712 Data Warehousing and Data Structure, Homework Assignment 1.

A web app that answers eight fixed database questions about a loan-applications dataset (44,988 cleaned records). Pick a question, and the app runs the matching SQL on AWS and shows a table or chart.

**Live app:** https://staging.dpleguc4hli0x.amplifyapp.com

## Architecture

```
Browser (index.html on AWS Amplify Hosting)
   |  POST /query  {"query_name": "..."}
   v
Amazon API Gateway (HTTP API, CORS, throttling)
   v
AWS Lambda (Python): maps query_name to a fixed SQL query
   v
Amazon Athena (workgroup data-app-workgroup)
   v
Glue Data Catalog: data_app_db.loans_clean (Parquet) <- built from data_app_db.loans (raw CSV in S3)
```

The browser never sends SQL. It sends only a question name, and the Lambda looks up the SQL in a fixed dictionary of eight queries.

## The eight questions

| # | Question | Display |
|---|---|---|
| 1 | What are the 10 largest approved loans? | Table |
| 2 | What is the approval rate for each loan purpose? | Bar chart |
| 3 | What is the average loan amount by home ownership status? | Bar chart |
| 4 | How does the average loan amount differ between approved and rejected applications for each loan purpose? | Grouped bar chart |
| 5 | Which education levels have an average income above the overall average? | Table |
| 6 | How does the average loan amount change with years of work experience? | Line chart |
| 7 | How does the approval rate vary across credit score bands? | Table |
| 8 | What are the portfolio's key totals? | Table |

SQL constructs used: WHERE, COUNT/SUM/AVG/MIN/MAX, GROUP BY, ORDER BY, LIMIT, calculated percentages, CASE, HAVING, a subquery (Q5) and a CTE (Q7).

## Data preparation

- The source CSV has 14 columns and 45,000 rows. Athena read every column as text (`string`), so a typed copy (`loans_clean`, Parquet) was created.
- Profiling found no duplicates or missing values, but 12 impossible records (ages up to 144, work experience up to 125 years). They were removed, leaving 44,988 rows.
- `loan_status = 1` is treated as **approved**. This is inferred, not documented: all 10,000 rows with status 1 have no previous default, and every applicant with a previous default has status 0.
- The highest credit score is 784, so Q7 uses four bands (below 580, 580-669, 670-739, 740 and above).

## Repository contents

| Path | Purpose |
|---|---|
| `index.html` | The web front end (Chart.js). Set `API_URL` near the top of the script to your own endpoint. |
| `lambda/lambda_function.py` | Lambda handler containing the eight fixed queries |
| `sql/01_create_loans_clean.sql` | Builds the typed, cleaned table |
| `sql/02_data_profiling_checks.sql` | Checks run before writing the questions |
| `sql/03_eight_questions.sql` | The eight queries, runnable in the Athena console |

## Notes

- The raw dataset is not included in this repository.
- Data limits worth knowing: the `OTHER` home-ownership group has only 117 applicants, and the `740 and above` credit band has only 89.
