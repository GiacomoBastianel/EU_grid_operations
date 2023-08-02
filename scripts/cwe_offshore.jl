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
import Clustering
using StatsBase
import StatsPlots
using ColorSchemes

######### DEFINE INPUT PARAMETERS
scenario = "GA2040"
climate_year = "1982"
load_data = true
use_case = "nsow"
only_hvdc_case = false
hour_start_idx = 1 
hour_end_idx =  24
batch_size = 1
############ LOAD EU grid data
file = "data_sources/European_grid_no_nseh.json"
output_file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year, ".json"]))
gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)

#### LOAD TYNDP SCENARIO DATA ##########
if load_data == true
    zonal_result, zonal_input, scenario_data = _EUGO.load_results(scenario, climate_year; file_name = "NSOW_zonal") # Import zonal results
    ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(scenario) # import zonal input (mainly used for cost data)
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
end
print("ALL FILES LOADED", "\n")
print("----------------------","\n")

# map EU-Grid zones to TYNDP model zones
zone_mapping = _EUGO.map_zones()

# Scale generation capacity based on TYNDP data -> Offshore wind will be written extra!
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping; exclude_offshore_wind = true)

# For high impedance lines, set power rating to what is physically possible -> otherwise it leads to infeasibilities around XB lines
_EUGO.fix_data!(EU_grid)

# Isolate zone: input is vector of strings
zone_grid = _EUGO.isolate_zones(EU_grid, ["UK","BE","DE","FR","NL","DK1","DK2"]; border_slack = 0.01)

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping)

# Determine hourly cross-border flows and add them to time series data
push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

# Determine demand response potential and add them to zone_grid. Default cost value = 140 Euro / MWh, can be changed with get_demand_reponse!(...; cost = xx)
_EUGO.get_demand_reponse!(zone_grid, zonal_input, zone_mapping, timeseries_data)

# Add offshore wind power hubs according  to the excel file:
_EUGO.add_offshore_wind_farms!(zone_grid)

# Add HVDC connections for the offshore wind farms -> nearest node
_EUGO.add_offshore_wind_connections!(zone_grid)

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

# Load zonal result
zonal_result_file_name = joinpath("results", join(["NSOW_zonal_",scenario, "_", climate_year, ".json"]))
zonal_result = Dict{String, Any}()
open(zonal_result_file_name) do f
    dicttxt = read(f,String)  # file information to string
    global zonal_result = JSON.parse(dicttxt)  # parse and transform data
end

# Start runnning hourly OPF calculations


s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)
# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
_EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s, batch_size, output_file_name)


# Psot processing
ac_branch_flows, dc_branch_flows = _EUGO.get_branch_flows(hour_start_idx, hour_end_idx, batch_size, output_file_name) 

flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = abs.(ac_branch_flows[b]) ./ zone_grid["branch"][b]["rate_a"]
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = abs.(dc_branch_flows[b]) ./ zone_grid["branchdc"][b]["rateA"]
end

plot_file_name = joinpath("results", "plots", join([use_case,"_",scenario,"_", climate_year,"_grid.pdf"]))
_EUGO.plot_grid(zone_grid, plot_file_name; color_branches = true, flows_ac = flows_ac, flows_dc = flows_dc, maximum_flows = false) 