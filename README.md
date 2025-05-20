Results:

Category | count
-- | --
Last updated closed issues with no associated PRs where the issue was open for less than 3 years | 14827
Last updated closed issues with no associated PRs where the issue was open for 3 or more years | 913
Last updated closed issues with an associated PR where the issue was open for less than 3 years | 4016
Last updated closed issues with an associated PR where the issue was open for 3 or more years | 244

1. Download latest commits:

   ```bash
   export GITHUB_TOKEN='ghp_foo'
   dart run main.dart
   ```

2. Open duckdb: `duckdb -ui`

3. Find how many closed issues had associated PRs and were open for at least 3 years

   ```sql
   WITH foo AS (
     SELECT *, (open_duration_days > 365*3) AS open_at_least_3_years FROM "/Users/loicsharma/Code/flutter_bankruptcy/issues.csv"
   )
   SELECT
     has_associated_pr, open_at_least_3_years, COUNT(*)
   FROM foo
   GROUP BY has_associated_pr, open_at_least_3_years
   ORDER BY has_associated_pr ASC, open_at_least_3_years ASC
   ```

4. Find how many recently updated closed issues had an associated PR and were open for at least 3 years:

   ```sql
   SELECT issue_url, issue_created_at, issue_closed_at, open_duration_days
   FROM "/Users/loicsharma/Code/flutter_bankruptcy/issues.csv"
   WHERE has_associated_pr AND open_duration_days > 365*3
   ```
