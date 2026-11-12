-- L2 sim test runner (MASTERPLAN §8.9): the whole HeistSim headless in Lune.
-- Runs every tests/sim/*.spec.luau (determinism, fast-forward equivalence,
-- solvability, naive kid, latency injection, divergence, soak, lifecycle).
-- Run from the repo root: lune run tests/run_sim.luau [filter]
-- Exits with code 1 if any test fails or a spec file fails to load.

local process = require("@lune/process")
local SpecRunner = require("./SpecRunner")

local passed, failed, failures = SpecRunner.run("sim", process.args[1])
process.exit(SpecRunner.report(passed, failed, failures))
