# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using JSON
import CBAOPF
using Plots


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

result = _PM.solve_opf(EU_grid, DCPPowerModel, Gurobi.Optimizer)

EU_grid["pst"] = Dict{String, Any}()
for (l, load) in EU_grid["load"]
    load["pred_rel_max"]  = 0
    load["cost_red"] = 100 * EU_grid["baseMVA"] 
    load["cost_curt"]  = 1000 * EU_grid["baseMVA"] 
    load["flex"] = 1
end

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => false)

result_cba = CBAOPF.solve_cbaopf(EU_grid, DCPPowerModel, Gurobi.Optimizer; setting = s) 


#### Plot some results:
average_electricity_price = result_cba["objective"] / (sum([load["pd"] for (l, load) in EU_grid["load"]]) * EU_grid["baseMVA"])
total_load_curtailment =  sum([load["pcurt"] for (l, load) in result_cba["solution"]["load"]]) * EU_grid["baseMVA"]

print("Average electricty price: ", average_electricity_price, " Euro / MWh", "\n")
print("Total curtailed load: ", total_load_curtailment, " MW")
plot([load["pcurt"] for (l, load) in result_cba["solution"]["load"]] * EU_grid["baseMVA"])
xlabel!("Load ID")
ylabel!("Pcurt in MW")
