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
import JSON
using EU_grid_operations; const _EUGO = EU_grid_operations
gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer, "OutputFlag" => 0)

# Add auxiliary functions to construct input and scenario data dictionary


# Select input paramters for:
# Scenario selection: Distributed Energy (DE), National Trends (NT), Global Ambition (GA)
# Planning years: 2025 (NT only), 2030, 2040
# Climate year: 1982, 1984, 2007
# Number of hours: 1 - 8760
# Fetch data: true/false, to parse input data (takes ~ 1 min.)

scenario = "GA2030"
climate_year = "2007"
fetch_data = true
number_of_hours = 8760

# Load grid and scenario data
if fetch_data == true
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
    ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, node_positions = _EUGO.get_grid_data(scenario)
end

# Construct input data dictionary in PowerModels style 
# Construct RES time and demand series, installed capacities on nodal (zonal) data
input_data, nodal_data = _EUGO.construct_data_dictionary(ntcs, capacity, nodes, demand, scenario, climate_year, gen_types, pv, wind_onshore, wind_offshore, gen_costs, emission_factor, inertia_constants, node_positions)

input_data_raw = deepcopy(input_data)


print("######################################", "\n")
print("### STARTING HOURLY OPTIMISATION ####", "\n")
print("######################################", "\n")

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
result_file_name = join(["./results/result_zonal_tyndp_", scenario,"_", climate_year, ".json"])
open(result_file_name,"w") do f
  JSON.print(f, json_string)
end

# Input data dictionary as .json file
input_file_name = join(["./results/input_zonal_tyndp_", scenario,"_", climate_year, ".json"])
json_string = JSON.json(input_data_raw)
open(input_file_name,"w") do f
  JSON.print(f, json_string)
end

# scenario file (e.g. zonal time series and installed capacities) as .json file
scenario_file_name = join(["./results/scenario_zonal_tyndp_", scenario,"_", climate_year, ".json"])
json_string = JSON.json(nodal_data)
open(scenario_file_name,"w") do f
  JSON.print(f, json_string)
end