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
import CBAOPF
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
links = Dict("Ultranet" => [], "Suedostlink" => [] , "Suedlink" => [])
zone = "DE00"
output_base = "DE"
output_cba = "DE_HVDC"
number_of_clusters = 20
number_of_hours_rd = 5
hour_start = 1
hour_end = 8760
############ LOAD EU grid data
file = "./data_sources/European_grid.json"
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

# Isolate zone: input is vector of strings
zone_grid = _EUGO.isolate_zones(EU_grid, ["DE"])

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, zone_mapping; zone = "DE")

push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

# Start runnning hourly OPF calculations
hour_start_idx = 1 
hour_end_idx = 24
zone_grid_hourly = deepcopy(zone_grid)

result = Dict{String, Any}(["$hour" => Dict{String, Any}() for hour in hour_start_idx : hour_end_idx])
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => false)
for hour_idx in hour_start_idx : hour_end_idx
    _EUGO.hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
    result["$hour_idx"] = CBAOPF.solve_cbaopf(zone_grid_hourly, DCPPowerModel, Gurobi.Optimizer; setting = s) # solve the OPF 
end