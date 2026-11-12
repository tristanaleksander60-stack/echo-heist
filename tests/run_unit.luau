-- L1 unit test runner (MASTERPLAN §8.9). Runs every tests/unit/*.spec.luau.
-- Run from the repo root: lune run tests/run_unit.luau
-- Optional filter: lune run tests/run_unit.luau Codec   (only spec files containing "Codec")
-- Exits with code 1 if any test fails or a spec file fails to load.
-- L2 sim specs (tests/sim) have their own runner: lune run tests/run_sim.luau

local process = require("@lune/process")
local SpecRunner = require("./SpecRunner")

local passed, failed, failures = SpecRunner.run("unit", process.args[1])
process.exit(SpecRunner.report(passed, failed, failures))
