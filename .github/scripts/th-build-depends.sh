#!/usr/bin/env bash
# Checks th_build_depends on the per-module build of example/, run from
# there, with the worker or without it as `cabal buck2` finds it.
# Example.Lib splices from th, so leaving th out fails, naming the symbol;
# Example.Forest (an ANN pragma that runs only base) then compiles against
# th's early db, not waiting for th's library.
set -euo pipefail

generate() {
  echo "OVERRIDES = {\"example\": {\"example\": {\"th_build_depends\": $1}}}" > cabal-buck2.bzl
  CABAL_BUCK2="$RUNNER_TEMP/cabal-buck2" ./setup.sh --per-module
}

generate '[]'
# A comment in each, so that GHC compiles them again rather than finding
# them up to date from the last build (it doesn't count package dbs).
cp Example/Lib.hs Example/Forest.hs "$RUNNER_TEMP"
printf '\n-- th_build_depends\n' | tee -a Example/Lib.hs >> Example/Forest.hs
for mode in dev prof; do
  # --keep-going: Example.Forest is compiled whatever happens to Example.Lib.
  if buck2 build -m "$mode" --keep-going //:example > build.txt 2>&1; then exit 1; fi
  cat build.txt
  grep -q "couldn't find the following symbol" build.txt
  # The symbol: by its name in the object (GHC 9.12) or the closure's.
  grep -q -E "ExampleziTH_makeGreeter_closure|closure:makeGreeter" build.txt
  # Example.Lib alone fails.
  if grep 'Action failed' build.txt | grep -qv 'Example\.Lib)'; then exit 1; fi
done
buck2 audit dep-files root//:example haskell_compile_module_shared Example.Forest | tee inputs.txt
grep -q '__th__/db-early-shared' inputs.txt
if grep -q '__th__/db-shared' inputs.txt; then exit 1; fi

cp "$RUNNER_TEMP/Lib.hs" "$RUNNER_TEMP/Forest.hs" Example/

generate '[":th"]'
for mode in dev prof; do
  buck2 build -m "$mode" //...
  buck2 test -m "$mode" //...
done
rm cabal-buck2.bzl
