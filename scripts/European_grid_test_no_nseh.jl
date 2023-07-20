# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using EU_grid_operations; const _EUGO = EU_grid_operations
using JSON
import CbaOPF
using Plots


# creat the json file of the grid on the default folder, e.g. data_sources/European_grid.json
# output filename can be specified with  _EUGO.create_european_grid(output_filename = "filepath/filename")
_EUGO.create_european_grid(output_filename = "./data_sources/European_grid_no_nseh.json", no_nseh = true)

# Load the EU grid file 
file = "./data_sources/European_grid_no_nseh.json"

#parse file
EU_grid = _PM.parse_file(file)

#add DC grid to grid model
_PMACDC.process_additional_data!(EU_grid)

# specify optimisation settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

# Solve using PMACDC
result = _PMACDC.run_acdcopf(EU_grid, DCPPowerModel, Gurobi.Optimizer; setting = s)

# Add data fields to solve with CbaOPF.jl
EU_grid["pst"] = Dict{String, Any}()
for (l, load) in EU_grid["load"]
    load["pred_rel_max"]  = 0
    load["cost_red"] = 100 * EU_grid["baseMVA"] 
    load["cost_curt"]  = 1000 * EU_grid["baseMVA"] 
    load["flex"] = 1
end

# Update setttings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => false)

# solve CbaOPF
result_cba = CbaOPF.solve_cbaopf(EU_grid, DCPPowerModel, Gurobi.Optimizer; setting = s) 

#### Plot some results:
average_electricity_price = result_cba["objective"] / (sum([load["pd"] for (l, load) in EU_grid["load"]]) * EU_grid["baseMVA"])
total_load_curtailment =  sum([load["pcurt"] for (l, load) in result_cba["solution"]["load"]]) * EU_grid["baseMVA"]

##### Print some results for sanity check
print("Average electricty price: ", average_electricity_price, " Euro / MWh", "\n")
print("Total curtailed load: ", total_load_curtailment, " MW")
plot([load["pcurt"] for (l, load) in result_cba["solution"]["load"]] * EU_grid["baseMVA"])
xlabel!("Load ID")
ylabel!("Pcurt in MW")
