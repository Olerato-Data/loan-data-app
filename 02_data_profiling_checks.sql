-- Checks run before writing the eight questions.

-- 1. Column types of the raw table (all came back as varchar)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'data_app_db' AND table_name = 'loans'
ORDER BY ordinal_position;

-- 2. Duplicates and suspicious values in the raw table
SELECT
  COUNT(*) AS total_rows,
  (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM loans)) AS distinct_rows,
  SUM(CASE WHEN TRY_CAST(person_age AS DOUBLE) > 80 THEN 1 ELSE 0 END) AS age_over_80,
  SUM(CASE WHEN TRY_CAST(person_emp_exp AS DOUBLE) > 50 THEN 1 ELSE 0 END) AS experience_over_50,
  SUM(CASE WHEN TRY_CAST(credit_score AS DOUBLE) < 300
            OR TRY_CAST(credit_score AS DOUBLE) > 850 THEN 1 ELSE 0 END) AS credit_score_out_of_range
FROM loans;

-- 3. What does loan_status mean? (every status 1 row has no previous default)
SELECT loan_status, previous_loan_defaults_on_file, COUNT(*) AS n
FROM loans
GROUP BY loan_status, previous_loan_defaults_on_file
ORDER BY 1, 2;

-- 4. Verify the cleaned table
SELECT COUNT(*) AS total_rows, MAX(person_age) AS max_age,
       MAX(person_emp_exp) AS max_experience, SUM(loan_status) AS approved
FROM data_app_db.loans_clean;

-- 5. Credit score range (used to choose sensible bands for Q7: 390 to 784)
SELECT MIN(credit_score) AS lowest, MAX(credit_score) AS highest
FROM loans_clean;
