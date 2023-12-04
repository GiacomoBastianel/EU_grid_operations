#####################################
#  main.jl
# Author: Hakan Ergun 24.03.2022
# Script to solve the hourly ecomic dispatch problem for the TYNDP 
# reference grid based on NTC and provided genreation capacities
# RES and demand time series
#######################################


######### IMPORTANT: YOU WILL NEED TO DOWNLOAD THE FEATHER FILES AND ADD THEM TO YOUR data_sources FOLDER!!!!!!!
######### See data_sources/download_links.txt for the download links

# Import packages and create short names
import DataFrames; const _DF = DataFrames
import CSV
import ExcelFiles; const _EF = ExcelFiles
import JuMP
import Gurobi
import Feather
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels
import JSON
import CbaOPF
import Plots
using EU_grid_operations; const _EUGO = EU_grid_operations
gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer)

# Add auxiliary functions to construct input and scenario data dictionary


# Select input paramters for:
# Scenario selection: Distributed Energy (DE), National Trends (NT), Global Ambition (GA)
# Planning years: 2025 (NT only), 2030, 2040
# Climate year: 1982, 1984, 2007
# Number of hours: 1 - 8760
# Fetch data: true/false, to parse input data (takes ~ 1 min.)

scenario = "GA2040"
climate_year = "1982"
fetch_data = true
hours = 1:8760
ns_wind_power = 300e3 # in MW
file_name = "NSOW_zonal"
co2_cost = 45

# Load grid and scenario data
if fetch_data == true
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
    ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, node_positions = _EUGO.get_grid_data(scenario)
end

# Construct input data dictionary in PowerModels style 
# Construct RES time and demand series, installed capacities on nodal (zonal) data
input_data, nodal_data = _EUGO.construct_data_dictionary(ntcs, capacity, nodes, demand, scenario, climate_year, gen_types, pv, wind_onshore, wind_offshore, gen_costs, emission_factor, inertia_constants, node_positions; co2_cost = 50.0)

_EUGO.add_north_sea_wind_zonal!(input_data, nodal_data, ns_wind_power, co2_cost; branch_cap = 150e3)
input_data_raw = deepcopy(input_data)

number_of_hours = 8760
# Create dictionary for writing out results
result = Dict{String, Any}("$hour" => nothing for hour in 1:number_of_hours)
for hour = 1:number_of_hours
    print("Hour ", hour, " of ", number_of_hours, "\n")
    # Write time series data into input data dictionary
    _EUGO.prepare_hourly_data!(input_data, nodal_data, hour)
    # Solve Network Flow OPF using PowerModels
    result["$hour"] = _PM.solve_opf(input_data, PowerModels.NFAPowerModel, gurobi) 
end

## Write out JSON files
# Result file, with hourly results
json_string = JSON.json(result)
result_file_name = joinpath("results", join([file_name, "_",scenario, "_", climate_year, ".json"]))
open(result_file_name,"w") do f
  JSON.print(f, json_string)
end





# _EUGO.branch_capacity_cost!(input_data)
# _EUGO.scale_costs!(input_data, hours)

# for (l, load) in input_data["load"]
#     load["pred_rel_max"] = 0
#     load["cost_red"] = 10e3 * input_data["baseMVA"]
#     load["cost_curt"] = 10e3 * input_data["baseMVA"]
#     load["flex"] = 1
# end




# # Create dictionary for writing out results
# print("######################################", "\n")
# print("####### PREPARING DATA      ##########", "\n")
# @time mn_input_data = _EUGO.prepare_mn_data(input_data, nodal_data, hours)

# print("######################################", "\n")
# print("####### STARTING OPTIMISATION#### ####", "\n")
# @time result = CbaOPF.solve_zonal_tnep(mn_input_data, _PM.NFAPowerModel, gurobi; multinetwork = true) 

# result_file_name = joinpath("results", join([file_name, "_cap_",scenario, "_", climate_year, ".json"]))
# json_string = JSON.json(result)
# open(result_file_name,"w") do f
# write(f, json_string)
# end


# cap  = zeros(1, maximum(parse.(Int, collect(keys(input_data["branch"])))))
# for (n, network) in result["solution"]["nw"]
#     for idx in sort(parse.(Int, collect(keys(network["branch"]))))
#         branch = network["branch"]["$idx"]
#         cap[1, idx] = max(cap[idx], branch["delta_cap"])
#     end
# end
# p1 = Plots.plot(cap')
# Plots.savefig(p1, "results/plots/capacity_nsow.pdf")