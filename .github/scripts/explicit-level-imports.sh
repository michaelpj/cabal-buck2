#!/usr/bin/env bash
# Checks explicit level imports on the per-module build of example/ (GHC
# 9.14 and later), run from there, with the worker or without it as `cabal
# buck2` finds it. With th_build_depends empty, Example.Eli still compiles,
# against th's final db, because it imports Example.TH at the splice level;
# Example.EliNone, whose splice runs only template-haskell, compiles against
# th's early db, not waiting for th's library.
set -euo pipefail

echo 'OVERRIDES = {"example": {"example": {"th_build_depends": []}}}' > cabal-buck2.bzl
CABAL_BUCK2="$RUNNER_TEMP/cabal-buck2" ./setup.sh --per-module
# A comment in each, so that GHC compiles them again rather than finding
# them up to date from the last build (it doesn't count package dbs).
cp Example/Eli.hs Example/EliNone.hs "$RUNNER_TEMP"
printf '\n-- explicit level imports\n' | tee -a Example/Eli.hs >> Example/EliNone.hs
for mode in dev prof; do
  # Example.Lib, without explicit level imports, fails (see
  # th-build-depends.sh); nothing else does.
  buck2 build -m "$mode" --keep-going //:example > build.txt 2>&1 || true
  cat build.txt
  if grep 'Action failed' build.txt | grep -qv 'Example\.Lib)'; then exit 1; fi
done
buck2 audit dep-files root//:example haskell_compile_module_shared Example.Eli | tee inputs.txt
grep -q '__th__/db-shared' inputs.txt
buck2 audit dep-files root//:example haskell_compile_module_shared Example.EliNone | tee inputs.txt
grep -q '__th__/db-early-shared' inputs.txt
if grep -q '__th__/db-shared' inputs.txt; then exit 1; fi
cp "$RUNNER_TEMP/Eli.hs" "$RUNNER_TEMP/EliNone.hs" Example/
rm cabal-buck2.bzl
