using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations
using Gurobi
using JSON

import Ipopt
using Plots
import Memento
import JuMP
import Gurobi  # needs startvalues for all variables!
import JSON
import CbaOPF
import DataFrames; const _DF = DataFrames
import CSV
import ExcelFiles; const _EF = ExcelFiles
import Feather
using XLSX
using Statistics
using Clustering
using StatsBase
import StatsPlots

######### DEFINE INPUT PARAMETERS
scenario = "GA2030"
climate_year = "2007"
load_data = true
use_case = "STERNA_offshore_wind"
only_hvdc_case = false
#links = Dict("BE_EI" => [], "Nautilus" => [] , "Triton" => [])
zone = "North_Sea"
hour_start = 1
hour_end = 24
############ LOAD EU grid data
file = "./data_sources/European_grid.json"
output_file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year]))
gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)

#### LOAD TYNDP SCENARIO DATA ##########
if load_data == true
    zonal_result, zonal_input, scenario_data = _EUGO.load_results(scenario, climate_year) # Import zonal results
    ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(scenario) # import zonal input (mainly used for cost data)
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
end

print("ALL FILES LOADED", "\n")
print("----------------------","\n")
######

# map EU-Grid zones to TYNDP model zones
zone_mapping = _EUGO.map_zones()

# Scale generation capacity based on TYNDP data
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)

# Isolate zone: input is vector of strings, if you need to relax the fixing border flow assumptions use:
# _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = x), this will lead to (1-slack)*xb_flow_ref < xb_flow < (1+slack)*xb_flow_ref
zone_grid = _EUGO.isolate_zones(EU_grid, ["BE","UK","NL"])

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping)

# Determine hourly cross-border flows and add them to time series data
push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

# Determine demand response potential and add them to zone_grid. Default cost value = 140 Euro / MWh, can be changed with get_demand_reponse!(...; cost = xx)
_EUGO.get_demand_reponse!(zone_grid, zonal_input, zone_mapping, timeseries_data)

# There is no internal congestion as many of the lines are 5000 MVA, limit the lines....
for (b, branch) in zone_grid["branch"]
    branch["angmin"] = -pi
    branch["angmax"] = pi
    #for (bo, border) in zone_grid["borders"]
    #    if branch["rate_a"] >= 49.9 && !haskey(border["xb_lines"], b)
    #        branch["rate_a"] = 15
    #        branch["rate_b"] = 15
    #        branch["rate_c"] = 15
    #    end
    #end
end

delete!(zone_grid["gen"],"1822")
delete!(zone_grid["branch"],"219")
delete!(zone_grid["branch"],"214")
delete!(zone_grid["branch"],"234")
delete!(zone_grid["branch"],"237")
delete!(zone_grid["branch"],"7316")
delete!(zone_grid["branch"],"7308")
delete!(zone_grid["branch"],"7310")
delete!(zone_grid["branch"],"7319")

###################
#####  Adding offshore wind farms -> Develop code in src/core/add_STERNA_wind_farms.jl

folder_results = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/STERNA 2050/Simulation_Results/Playground"

json_string_data = JSON.json(zone_grid)
open(joinpath(folder_results,"Nodal_grid.json"),"w" ) do f
write(f,json_string_data)
end

json_string_timeseries = JSON.json(timeseries_data)
open(joinpath(folder_results,"Timeseries.json"),"w" ) do f
    write(f,json_string_timeseries)
end



STERNA_grid = "Nodal_grid.json"
STERNA_time_series = "Timeseries.json"

file_STERNA_grid = joinpath(folder_results,"$STERNA_grid")
file_STERNA_time_series = joinpath(folder_results,"$STERNA_time_series")

STERNA_grid = _PM.parse_file(file_STERNA_grid)
STERNA_grid_time_series = read_json(file_STERNA_time_series)


### Carry out OPF
# Start runnning hourly OPF calculations
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)

hour_start_idx = 1 
hour_end_idx =  24

# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
result = _EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s)

STERNA_grid = _PM.parse_file(file_STERNA_grid)
STERNA_grid_time_series = JSON.parsefile(file_STERNA_time_series)


hour_start_idx = 1 
hour_end_idx =  720

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)
# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
result = _EUGO.batch_opf(hour_start_idx, hour_end_idx, STERNA_grid, timeseries_data, gurobi, s)

obj = []
for i in 1:hour_end_idx
    push!(obj,result["$i"]["termination_status"])
end
