-- The eight database questions (identical to the Lambda's QUERIES).

-- Q1  What are the 10 largest approved loans?  [table]
-- query_name: largest_approved_loans
SELECT loan_amnt, loan_intent, person_income, credit_score, loan_int_rate
FROM loans_clean
WHERE loan_status = 1
ORDER BY loan_amnt DESC, person_income DESC
LIMIT 10;

-- Q2  What is the approval rate for each loan purpose?  [bar chart]
-- query_name: approval_rate_by_purpose
SELECT loan_intent,
       COUNT(*) AS applications,
       ROUND(100.0 * SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS approval_rate_pct
FROM loans_clean
GROUP BY loan_intent
ORDER BY approval_rate_pct DESC;

-- Q3  What is the average loan amount by home ownership status?  [bar chart]
-- query_name: avg_loan_by_home_ownership
SELECT person_home_ownership,
       ROUND(AVG(loan_amnt), 2) AS avg_loan_amount,
       COUNT(*) AS applications
FROM loans_clean
GROUP BY person_home_ownership
ORDER BY avg_loan_amount DESC;

-- Q4  How does the average loan amount differ between approved and rejected applications for each loan purpose?  [grouped bar chart]
-- query_name: loan_amount_by_purpose_and_outcome
SELECT loan_intent,
       CASE WHEN loan_status = 1 THEN 'Approved' ELSE 'Rejected' END AS outcome,
       ROUND(AVG(loan_amnt), 2) AS avg_loan_amount
FROM loans_clean
GROUP BY loan_intent, loan_status
ORDER BY loan_intent, outcome;

-- Q5  Which education levels have an average income above the overall average?  [table]
-- query_name: education_above_avg_income
SELECT person_education,
       COUNT(*) AS applicants,
       ROUND(AVG(person_income), 0) AS avg_income
FROM loans_clean
GROUP BY person_education
HAVING AVG(person_income) > (SELECT AVG(person_income) FROM loans_clean)
ORDER BY avg_income DESC;

-- Q6  How does the average loan amount change with years of work experience?  [line chart]
-- query_name: loan_by_experience
SELECT person_emp_exp AS years_experience,
       ROUND(AVG(loan_amnt), 2) AS avg_loan_amount,
       COUNT(*) AS applicants
FROM loans_clean
GROUP BY person_emp_exp
HAVING COUNT(*) >= 30
ORDER BY years_experience;

-- Q7  How does the approval rate vary across credit score bands?  [table]
-- query_name: approval_by_credit_band
WITH banded AS (
    SELECT CASE
             WHEN credit_score < 580 THEN '1. Below 580'
             WHEN credit_score < 670 THEN '2. 580-669'
             WHEN credit_score < 740 THEN '3. 670-739'
             ELSE '4. 740 and above'
           END AS credit_band,
           loan_status
    FROM loans_clean
)
SELECT credit_band,
       COUNT(*) AS applications,
       SUM(loan_status) AS approved,
       ROUND(100.0 * SUM(loan_status) / COUNT(*), 2) AS approval_rate_pct
FROM banded
GROUP BY credit_band
ORDER BY credit_band;

-- Q8  What are the portfolio's key totals?  [table]
-- query_name: portfolio_summary
SELECT COUNT(*) AS total_applications,
       SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END) AS approved,
       ROUND(100.0 * SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS approval_rate_pct,
       ROUND(SUM(loan_amnt), 0) AS total_requested,
       MIN(loan_amnt) AS smallest_loan,
       MAX(loan_amnt) AS largest_loan,
       ROUND(AVG(credit_score), 0) AS avg_credit_score
FROM loans_clean;
