# Generate Smoke Results Weekly Report

Generate a smoke results summary report for v4.99 dev-preview.

## Instructions

1. **Ask for date range** if not provided (default: last 7 days from today).

2. **Query git history** for `v4-99/lanes/dev-preview/qe/smokeResults.yaml`:

   ```bash
   git log --since="YYYY-MM-DD" --until="YYYY-MM-DD" --oneline --follow -- v4-99/lanes/dev-preview/qe/smokeResults.yaml
   ```

3. **For each commit**, extract via `git show <sha>:v4-99/lanes/dev-preview/qe/smokeResults.yaml`:
   - `bundle`
   - `smokeResults` (success/failure)
   - `freightName` / `snapshotID`
   - `prowJobUrl`, `prowJobYaml`
   - `payloadCommit`

4. **Write report** to `reports/smoke-results-weekly-YYYY-MM-DD-to-DD.md` with:
   - Header: period, file path, channel, total runs, success rate
   - Summary table: # | Bundle | Date (UTC) | smokeResults | Freight / Snapshot
   - Prow Job Links section (one subsection per bundle with Job, YAML, Commit)
   - Notes section (gaps, failures, recovery)

5. **Use MD060-compliant tables**: `| Col | Col |` and `| --- | --- |` (spaces around pipes).

## Template Reference

See `reports/smoke-results-weekly-2026-02-16-to-23.md` for structure and formatting.
