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
import DataFrames; const _DF = DataFrames
import CSV
import Feather
using XLSX
using Statistics
using Clustering
using StatsBase
import StatsPlots

######### DEFINE INPUT PARAMETERS
tyndp_version = "2024"
scenario = "GA"
year = "2050"
climate_year = "2008"
load_data = true
use_case = "fr_es_pt"
hour_start = 1
hour_end = 8760
isolated_zones = ["FR", "ES", "PT"]
############ LOAD EU grid data
file = "./data_sources/European_grid_no_nseh.json"
output_file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year]))
gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)

#### LOAD TYNDP SCENARIO DATA ##########
if load_data == true
    zonal_result, zonal_input, scenario_data = _EUGO.load_results(tyndp_version, scenario, year, climate_year) # Import zonal results
    ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(tyndp_version, scenario, year, climate_year) # import zonal input (mainly used for cost data)
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
end

print("ALL FILES LOADED", "\n")
print("----------------------","\n")
######

# map EU-Grid zones to TYNDP model zones
zone_mapping = _EUGO.map_zones()

# Scale generation capacity based on TYNDP data
_EUGO.scale_generation!(tyndp_capacity, EU_grid, tyndp_version, scenario, climate_year, zone_mapping)

# Isolate zone: input is vector of strings, if you need to relax the fixing border flow assumptions use:
# _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = x), this will leas to (1-slack)*xb_flow_ref < xb_flow < (1+slack)*xb_flow_ref
zone_grid = _EUGO.isolate_zones(EU_grid, isolated_zones, border_slack = 0.01)

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zones = isolated_zones)

push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

# Start runnning hourly OPF calculations
hour_start_idx = 1 
hour_end_idx =  8760

plot_filename = joinpath("results", join(["grid_input_",use_case,".pdf"]))
_EUGO.plot_grid(zone_grid, plot_filename)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true, "objective_components" => ["gen", "demand"])
# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
# result = _EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s)
# obj = [result["$(i)"]["termination_status"] for i in 1:8760]; countmap(obj) # chcek objective
 
# An alternative is to run it in chuncks of "batch_size", which will store the results as json files, e.g. hour_1_to_batch_size, ....
batch_size = 8760
_EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s, batch_size, output_file_name)