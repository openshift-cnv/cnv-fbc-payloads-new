#!/usr/bin/env python3
"""
align_version.py - Helper script to validate, align, or scaffold CNV FBC version directories.

Usage:
  # Verify one or more versions against reference (default v4-22):
  python3 align_version.py --verify v5-0 v5-1 v5-2

  # Scaffold or align a version to match canonical structure:
  python3 align_version.py --scaffold v5-3

  # Align all existing v* versions in the repository:
  python3 align_version.py --align-all
"""

import argparse
import os
import sys

DEFAULT_REF_VERSION = "v4-22"

# 17 leaf directories and whether they require payload.yaml
# (True = requires payload.yaml initialized with '#\n', False = .gitkeep only)
CANONICAL_LEAF_DIRS = {
    "lanes/candidate/errata": False,
    "lanes/candidate/gating": True,
    "lanes/candidate/konflux-release": True,
    "lanes/candidate/prod": True,
    "lanes/candidate/release-candidate": True,
    "lanes/candidate/stage": True,
    "lanes/candidate/verify-production-release": True,
    "lanes/nightly/prod": True,
    "lanes/nightly/release": False,
    "lanes/nightly/smoke": True,
    "lanes/nightly/stage": True,
    "lanes/nightly/verify-production-release": False,
    "lanes/stable/prod": True,
    "lanes/stable/qe": True,
    "lanes/stable/stage": True,
    "lanes/stable/verify-production-release": True,
    "lanes/test/verify-production-release": False,
}


def find_repo_root():
    current = os.path.abspath(os.getcwd())
    while current != os.path.dirname(current):
        if os.path.exists(os.path.join(current, ".git")):
            return current
        current = os.path.dirname(current)
    return os.path.abspath(os.getcwd())


def verify_version(repo_root, version_name):
    v_dir = os.path.join(repo_root, version_name)
    if not os.path.isdir(v_dir):
        print(f"[FAIL] {version_name}: directory does not exist")
        return False

    all_passed = True
    missing_dirs = []
    missing_gitkeep = []
    missing_payload = []

    for rel_dir, requires_payload in sorted(CANONICAL_LEAF_DIRS.items()):
        full_dir = os.path.join(v_dir, rel_dir)
        if not os.path.isdir(full_dir):
            missing_dirs.append(rel_dir)
            all_passed = False
            continue

        gitkeep = os.path.join(full_dir, ".gitkeep")
        if not os.path.exists(gitkeep):
            missing_gitkeep.append(rel_dir)
            all_passed = False

        if requires_payload:
            payload = os.path.join(full_dir, "payload.yaml")
            if not os.path.exists(payload):
                missing_payload.append(rel_dir)
                all_passed = False

    if all_passed:
        print(f"[PASS] {version_name}: fully aligned with canonical 17-leaf structure")
        return True
    else:
        print(f"[FAIL] {version_name}: discrepancies found:")
        for d in missing_dirs:
            print(f"  - missing folder: {d}")
        for g in missing_gitkeep:
            print(f"  - missing .gitkeep in: {g}")
        for p in missing_payload:
            print(f"  - missing payload.yaml in: {p}")
        return False


def scaffold_version(repo_root, version_name, dry_run=False):
    v_dir = os.path.join(repo_root, version_name)
    print(f"[{'DRY-RUN' if dry_run else 'APPLY'}] Scaffolding/aligning {version_name}...")
    created_count = 0

    for rel_dir, requires_payload in sorted(CANONICAL_LEAF_DIRS.items()):
        target_dir = os.path.join(v_dir, rel_dir)
        if not os.path.exists(target_dir):
            if not dry_run:
                os.makedirs(target_dir, exist_ok=True)
            print(f"  + mkdir {target_dir}")

        gitkeep_path = os.path.join(target_dir, ".gitkeep")
        if not os.path.exists(gitkeep_path):
            if not dry_run:
                with open(gitkeep_path, "w") as f:
                    pass
            print(f"  + create {os.path.relpath(gitkeep_path, repo_root)}")
            created_count += 1

        if requires_payload:
            payload_path = os.path.join(target_dir, "payload.yaml")
            if not os.path.exists(payload_path):
                if not dry_run:
                    with open(payload_path, "w") as f:
                        f.write("#\n")
                print(f"  + create {os.path.relpath(payload_path, repo_root)} with '#' placeholder")
                created_count += 1

    print(f"Done for {version_name}: {created_count} file(s) created/planned.\n")
    return True


def main():
    parser = argparse.ArgumentParser(description="Validate or scaffold CNV FBC version directories.")
    parser.add_argument("--verify", nargs="+", help="One or more versions to verify")
    parser.add_argument("--scaffold", nargs="+", help="One or more versions to scaffold or align")
    parser.add_argument("--align-all", action="store_true", help="Scaffold/align all existing v* versions")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without modifying files")

    args = parser.parse_args()
    repo_root = find_repo_root()

    if args.verify:
        success = True
        for v in args.verify:
            if not verify_version(repo_root, v):
                success = False
        sys.exit(0 if success else 1)

    if args.scaffold:
        for v in args.scaffold:
            scaffold_version(repo_root, v, dry_run=args.dry_run)
        sys.exit(0)

    if args.align_all:
        versions = [d for d in os.listdir(repo_root) if d.startswith("v") and not d.endswith("-99") and os.path.isdir(os.path.join(repo_root, d))]
        versions.sort()
        for v in versions:
            scaffold_version(repo_root, v, dry_run=args.dry_run)
        sys.exit(0)

    parser.print_help()


if __name__ == "__main__":
    main()
