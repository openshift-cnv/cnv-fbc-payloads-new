# Generate Verify-Production-Release Bundles Report

Generate a report of bundles committed to verify-production-release in candidate and stable channels.

## Instructions

1. **Ask for date range** if not provided (default: last 7 days from today).

2. **Find all VPR payload files** (excluding v4-99, v5-99):
   ```bash
   find . -path '*/lanes/stable/verify-production-release/payload.yaml' -o -path '*/lanes/candidate/verify-production-release/payload.yaml' | grep -v 'v4-99\|v5-99'
   ```

3. **For each file**, query git history in the date range:
   ```bash
   git log --since="YYYY-MM-DD" --until="YYYY-MM-DD" --oneline --follow -- <file_path>
   ```

4. **For each commit with activity**, extract payload via `git show <sha>:<file_path>`:
   - `hco_bundle_version` (bundle)
   - `channel`, `version` (e.g. v4-17)
   - `snapshot_id`, `freightName`
   - `hco_bundle_registry_by_tag`, `hco_bundle_registry_by_sha`
   - `fbc_fragment`, `index_image`, `firstRelease`

5. **Skip scaffolding commits**: If payload is just `#` or empty, treat as directory init, not a real bundle.

6. **Write report** to `reports/verify-production-release-bundles-YYYY-MM-DD-to-DD.md` with:
   - Header: period, scope, total VPR commits
   - Summary table: # | Version | Channel | Bundle | Date (UTC) | Commit
   - Detailed Payloads section (Field | Value tables per bundle)
   - Versions with No VPR Activity (list versions that had no commits)
   - Notes (concentration of activity, channel mix, firstRelease flags)

7. **Use MD060-compliant tables**: `| Col | Col |` and `| --- | --- |` (spaces around pipes).

## Template Reference

See `reports/verify-production-release-bundles-2026-02-16-to-23.md` for structure and formatting.
