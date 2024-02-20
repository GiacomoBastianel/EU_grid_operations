# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations
using Gurobi
using JSON


## Import required functions - Some of them in later stages.....
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
use_case = "de_hvdc_backbone"
only_hvdc_case = false
links = Dict("BE_EI" => [], "Nautilus" => [] , "Triton" => [])
zone = "DE00"
output_base = "DE"
output_cba = "DE_HVDC"
number_of_clusters = 20
number_of_hours_rd = 5
hour_start = 1
hour_end = 8760
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
# _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = x), this will leas to (1-slack)*xb_flow_ref < xb_flow < (1+slack)*xb_flow_ref
zone_grid = _EUGO.isolate_zones(EU_grid, ["BE","UK","DK1","DK2"])

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
    for (bo, border) in zone_grid["borders"]
        if branch["rate_a"] >= 49.9 && !haskey(border["xb_lines"], b)
            branch["rate_a"] = 15
            branch["rate_b"] = 15
            branch["rate_c"] = 15
        end
    end
end

###################
#####  Adding HVDC links
zone_grid_un = _EUGO.add_hvdc_links(zone_grid, links)
zone_grid_EI = add_full_Belgian_energy_island(zone_grid,5900.0)
zone_grid_EI_0 = add_full_Belgian_energy_island(zone_grid,0.0)

json_string_data_un = JSON.json(zone_grid_un)
json_string_data_EI = JSON.json(zone_grid_EI)
json_string_data_EI_0 = JSON.json(zone_grid_EI_0)

folder_results = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/WP1_WP3_collaboration/OPF_power_directions"

open(joinpath(folder_results,"Nodal_grid.json"),"w" ) do f
write(f,json_string_data_un)
end
open(joinpath(folder_results,"Nodal_grid_EI_5900.json"),"w" ) do f
write(f,json_string_data_EI)
end
open(joinpath(folder_results,"Nodal_grid_EI_0.json"),"w" ) do f
write(f,json_string_data_EI_0)
end


### Carry out OPF
# Start runnning hourly OPF calculations
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)

number_of_hours = 8760
results = hourly_opf(zone_grid,number_of_hours,timeseries_data)
results_EI = hourly_opf(zone_grid_EI,number_of_hours,timeseries_data)
results_EI_0 = hourly_opf(zone_grid_EI_0,number_of_hours,timeseries_data)

results_opf = Dict{String,Any}()
results_opf["no_investment"] = deepcopy(results)
results_opf["EI_5900"] = deepcopy(results_EI)
results_opf["EI_0"] = deepcopy(results_EI_0)


obj = []
obj_EI = []
obj_EI_0 = []

for i in 1:number_of_hours
    #if i != 57 && i != 58 && i != 59
        push!(obj,results["$i"]["objective"])
        push!(obj_EI,results_EI["$i"]["objective"])
        push!(obj_EI_0,results_EI_0["$i"]["objective"])
    #end
end
findall(@. any(isnan, obj))


json_string_data_un = JSON.json(results_opf)

open(joinpath(folder_results,"Nodal_grid.json"),"w" ) do f
    write(f,json_string_data_un)
    end
    


