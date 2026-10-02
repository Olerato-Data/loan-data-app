-- Typed, cleaned copy of the raw CSV-backed table (data_app_db.loans).
-- The raw table stores every column as string, so values are cast here once.
-- Rows with impossible values are removed (age > 80, experience > 50 years);
-- profiling found 12 such rows (ages up to 144, experience up to 125).
CREATE TABLE data_app_db.loans_clean
WITH (
  format = 'PARQUET'
) AS
SELECT
  CAST(person_age AS DOUBLE)                                  AS person_age,
  person_gender,
  person_education,
  CAST(person_income AS DOUBLE)                               AS person_income,
  CAST(CAST(person_emp_exp AS DOUBLE) AS INTEGER)             AS person_emp_exp,
  person_home_ownership,
  CAST(loan_amnt AS DOUBLE)                                   AS loan_amnt,
  loan_intent,
  CAST(loan_int_rate AS DOUBLE)                               AS loan_int_rate,
  CAST(loan_percent_income AS DOUBLE)                         AS loan_percent_income,
  CAST(CAST(cb_person_cred_hist_length AS DOUBLE) AS INTEGER) AS cb_person_cred_hist_length,
  CAST(CAST(credit_score AS DOUBLE) AS INTEGER)               AS credit_score,
  previous_loan_defaults_on_file,
  CAST(CAST(loan_status AS DOUBLE) AS INTEGER)                AS loan_status
FROM data_app_db.loans
WHERE CAST(person_age AS DOUBLE) <= 80
  AND CAST(person_emp_exp AS DOUBLE) <= 50;
