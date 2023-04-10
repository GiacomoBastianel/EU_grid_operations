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
include("batch_opf.jl")
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

# Isolate zone: input is vector of strings
zone_grid = _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = 0.02)

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, zone_mapping; zone = "DE")

push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

# Start runnning hourly OPF calculations
hour_start_idx = 1 
hour_end_idx =  8760


for (b, branch) in zone_grid["branch"]
    branch["angmin"] = -2*pi
    branch["angmax"] = 2*pi
end


s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)
#result = batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s)

batch_size = 730
batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s, batch_size, output_file_name)


# for i in 1:12
i = 1
    hs = 1 + (i-1) * batch_size
    he = hs + 729
    fn = join([output_file_name, "_opf_","$hs","_to_","$he",".json"])
    res = Dict()
    open(fn) do f
        dicttxt = read(f,String)  # file information to string
        res = JSON.parse(dicttxt)  # parse and transform data
    end
    for (h, hour) in res
        if isempty(hour["solution"])
            print(h, " -> ", hour["termination_status"],  "\n")
        end
    end
# end


# for (r, res) in result
#     if isempty(res["solution"])
#         print(r, " -> ", res["termination_status"],  "\n")
#     end
# end
# for a = 1:12
#     zone_grid_hourly["borders"]["$a"]["slack"] = 0
# end
# zone_grid_hourly["borders"]["5"]["slack"] = 0.06
# # zone_grid_hourly["borders"]["6"]["slack"] = 0.06
# # zone_grid_hourly["borders"]["7"]["slack"] = 0.06
# zone_grid_hourly["borders"]["8"]["slack"] = 0.01
# zone_grid_hourly["borders"]["13"]["slack"] = 0.01
# res = CBAOPF.solve_cbaopf(zone_grid_hourly, DCPPowerModel, Gurobi.Optimizer; setting = s) 

# ###### Validation ###########

# hour = "1"
# res_h = result[hour]["solution"]

# for (bo, border) in zone_grid_hourly["borders"]
#     xb_flow_in = border["flow"]
#     xb_flow_out = 0
#     border_cap = 0
#     for (b, branch) in border["xb_lines"]
#         if branch["direction"] == "from"
#             xb_flow_out =  xb_flow_out + res_h["branch"][b]["pf"]
#         else
#             xb_flow_out =  xb_flow_out + res_h["branch"][b]["pt"]
#         end
#         border_cap = border_cap + branch["rate_a"]
#     end
#     for (c, conv) in border["xb_convs"]
#         xb_flow_out = xb_flow_out - res_h["convdc"][c]["pgrid"]
#         border_cap = border_cap + conv["Pacmax"]
#     end
#     print(border["name"], " ", xb_flow_in, " ", xb_flow_out, " cap: ",border_cap,  "\n") 
# end


# for (c, conv) in zone_grid_hourly["convdc"]
#     if conv["busdc_i"] == 10193
#         print(c, "\n")
#     end
# end

# for (b, branch) in zone_grid_hourly["branchdc"]
#     if branch["fbusdc"] == 10204 || branch["tbusdc"] == 10204
#         print("10204 -> ", b, "\n" )
#     end
#     if branch["fbusdc"] == 10205 || branch["tbusdc"] == 10205
#         print("10204 -> ", b, "\n" )
#     end
# end


# for (b, branch) in zone_grid_hourly["branch"]
#     if branch["f_bus"] == 5941 || branch["t_bus"] == 5941
#         print(b, "\n")
#     end
# end