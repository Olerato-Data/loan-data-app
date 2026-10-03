import json
import boto3
import time

ATHENA_DATABASE = "data_app_db"
WORKGROUP       = "data-app-workgroup"

athena = boto3.client("athena")

# Exactly eight questions. The browser sends only a name, never SQL.
QUERIES = {
    # Q1: WHERE, ORDER BY, LIMIT
    "largest_approved_loans": """
        SELECT loan_amnt, loan_intent, person_income, credit_score, loan_int_rate
        FROM loans_clean
        WHERE loan_status = 1
        ORDER BY loan_amnt DESC, person_income DESC
        LIMIT 10""",

    # Q2: GROUP BY, COUNT, SUM, CASE, percentage
    "approval_rate_by_purpose": """
        SELECT loan_intent,
               COUNT(*) AS applications,
               ROUND(100.0 * SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END)
                     / COUNT(*), 2) AS approval_rate_pct
        FROM loans_clean
        GROUP BY loan_intent
        ORDER BY approval_rate_pct DESC""",

    # Q3: AVG, GROUP BY, ORDER BY
    "avg_loan_by_home_ownership": """
        SELECT person_home_ownership,
               ROUND(AVG(loan_amnt), 2) AS avg_loan_amount,
               COUNT(*) AS applications
        FROM loans_clean
        GROUP BY person_home_ownership
        ORDER BY avg_loan_amount DESC""",

    # Q4: CASE labels, two-level GROUP BY (grouped bar chart)
    "loan_amount_by_purpose_and_outcome": """
        SELECT loan_intent,
               CASE WHEN loan_status = 1 THEN 'Approved' ELSE 'Rejected' END AS outcome,
               ROUND(AVG(loan_amnt), 2) AS avg_loan_amount
        FROM loans_clean
        GROUP BY loan_intent, loan_status
        ORDER BY loan_intent, outcome""",

    # Q5: HAVING with a subquery
    "education_above_avg_income": """
        SELECT person_education,
               COUNT(*) AS applicants,
               ROUND(AVG(person_income), 0) AS avg_income
        FROM loans_clean
        GROUP BY person_education
        HAVING AVG(person_income) > (SELECT AVG(person_income) FROM loans_clean)
        ORDER BY avg_income DESC""",

    # Q6: HAVING, ordered numeric x-axis (line chart)
    "loan_by_experience": """
        SELECT person_emp_exp AS years_experience,
               ROUND(AVG(loan_amnt), 2) AS avg_loan_amount,
               COUNT(*) AS applicants
        FROM loans_clean
        GROUP BY person_emp_exp
        HAVING COUNT(*) >= 30
        ORDER BY years_experience""",

    # Q7: CTE, CASE banding, percentage
    "approval_by_credit_band": """
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
        ORDER BY credit_band""",

    # Q8: COUNT, SUM, MIN, MAX, AVG, percentage
    "portfolio_summary": """
        SELECT COUNT(*) AS total_applications,
               SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END) AS approved,
               ROUND(100.0 * SUM(CASE WHEN loan_status = 1 THEN 1 ELSE 0 END)
                     / COUNT(*), 2) AS approval_rate_pct,
               ROUND(SUM(loan_amnt), 0) AS total_requested,
               MIN(loan_amnt) AS smallest_loan,
               MAX(loan_amnt) AS largest_loan,
               ROUND(AVG(credit_score), 0) AS avg_credit_score
        FROM loans_clean""",
}

def respond(code, payload):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }

def get_params(event):
    if "body" in event:
        body = event["body"]
        return json.loads(body) if isinstance(body, str) and body else {}
    return event

def convert(value, col_type):
    if value is None:
        return None
    if col_type in ("integer", "bigint", "smallint", "tinyint"):
        return int(value)
    if col_type in ("double", "float", "real", "decimal"):
        return float(value)
    if col_type == "boolean":
        return value == "true"
    return value

def lambda_handler(event, context):
    try:
        name = get_params(event).get("query_name")
    except (ValueError, TypeError, json.JSONDecodeError):
        return respond(400, {"error": "Invalid input"})
    if name not in QUERIES:
        return respond(400, {"error": "Unknown query_name", "allowed": list(QUERIES)})

    started = athena.start_query_execution(
        QueryString=QUERIES[name],
        QueryExecutionContext={"Database": ATHENA_DATABASE},
        WorkGroup=WORKGROUP,
    )
    query_id = started["QueryExecutionId"]

    for _ in range(50):          # HTTP APIs cut off at 30 s
        time.sleep(0.5)
        status = athena.get_query_execution(QueryExecutionId=query_id)
        state = status["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            break
        if state in ("FAILED", "CANCELLED"):
            print("Athena failure:", status["QueryExecution"]["Status"])
            return respond(500, {"error": "Query failed"})
    else:
        return respond(504, {"error": "Query timed out"})

    result = athena.get_query_results(QueryExecutionId=query_id)
    cols = result["ResultSet"]["ResultSetMetadata"]["ColumnInfo"]
    names = [c["Name"] for c in cols]
    types = [c["Type"] for c in cols]
    data = [
        {names[i]: convert(c.get("VarCharValue"), types[i])
         for i, c in enumerate(r["Data"])}
        for r in result["ResultSet"]["Rows"][1:]
    ]
    return respond(200, {"count": len(data), "results": data})
