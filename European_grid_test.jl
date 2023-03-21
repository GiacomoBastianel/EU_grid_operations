# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using JSON

file = joinpath(@__DIR__,"European_grid.json")
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)

test_file = joinpath(@__DIR__,"case5_acdc.m")
test_grid = _PM.parse_file(test_file)
_PMACDC.process_additional_data!(test_grid)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
test_result = _PMACDC.run_acdcopf(test_grid, DCPPowerModel, Gurobi.Optimizer; setting = s)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(EU_grid, DCPPowerModel, Gurobi.Optimizer; setting = s)

