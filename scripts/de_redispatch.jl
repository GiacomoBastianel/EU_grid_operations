# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations
using Gurobi
using JSON
using PlotlyJS


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

######### DEFINE INPUT PARAMETERS
scenario = "GA2030"
climate_year = "2007"
load_data = true
use_case = "de_hvdc_sol"
only_hvdc_case = false
links = Dict("Suedostlink" => [] , "Suedostlink" => [], "Ultranet" => []) # 
zone = "DE00"
output_base = "DE"
output_cba = "DE_HVDC"
number_of_clusters = 200
hour_start_idx = 1
hour_end_idx = 8760
batch_size = 365
############ LOAD EU grid data
file = "./data_sources/European_grid.json"
output_file_name_rd = joinpath("results", join([use_case,"_",scenario,"_", climate_year, "_rd.json"]))
file_name_cl = joinpath("results", join([use_case,"_",scenario,"_", climate_year, "_inv_cl.json"]))
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

# map EU-Grid zones to TYNDP model zones
zone_mapping = _EUGO.map_zones()

# Scale generation capacity based on TYNDP data
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)

# For high impedance lines, set power rating to what is physically possible -> otherwise it leads to infeasibilities around XB lines
_EUGO.fix_data!(EU_grid)

# Isolate zone: input is vector of strings
zone_grid = _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = 0.01)

# create RES time series based on the TYNDP model for 
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping) 
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zone = "DE")

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

### Carry out OPF
# Start runnning hourly OPF calculations

res_cl = Dict{String, Any}()
open(file_name_cl) do f
    dicttxt = read(f,String)  # file information to string
    global res_cl = JSON.parse(dicttxt)  # parse and transform data
end



###############
# Redispatch Calcualtions
zone_grid_hourly = deepcopy(zone_grid)
delta_rd_cost = Dict{String, Any}() 
for (hour_idx, hour) in res_cl
    delta_rd_cost[hour_idx] = Dict{String, Any}()
    rd_cost_no_hvdc_cont = [0.0] 
    rd_cost_hvdc_cont = [0.0]

    _EUGO.hourly_grid_data!(zone_grid_hourly, zone_grid, parse(Int, hour_idx), timeseries_data)
    contingencies = _EUGO.find_critical_contingencies(res_cl, zone_grid_hourly, parse(Int, hour_idx); min_rating = 15, loading = 0.7)

    for (cont, contingency) in contingencies[hour_idx]
        print("================= hour:", hour_idx," =========== contingency:", contingency ,"=============", "\n")
        grid_data_rd = _EUGO.prepare_redispatch_data(res_cl, zone_grid_hourly, parse(Int, hour_idx); contingency = contingency, border_slack = 0.01, rd_cost_factor = 2)

        ##### RUN RD_OPF without control
        s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true, "fix_converter_setpoints" => true)
        result_crd = CbaOPF.solve_rdopf(grid_data_rd, _PM.DCPPowerModel, gurobi; setting = s) 

        if isnan(result_crd["objective"])
            push!(rd_cost_no_hvdc_cont, 0)
        else
            push!(rd_cost_no_hvdc_cont, result_crd["objective"])
        end

        ##### RUN RD_OPF with control
        s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true, "fix_converter_setpoints" => false)
        result_crd = CbaOPF.solve_rdopf(grid_data_rd, _PM.DCPPowerModel, gurobi; setting = s) 

        if isnan(result_crd["objective"])
            push!(rd_cost_hvdc_cont, 0)
        else
            push!(rd_cost_hvdc_cont, result_crd["objective"])
        end
    end
    delta_rd_cost_cont = rd_cost_no_hvdc_cont .- rd_cost_hvdc_cont
    if all(delta_rd_cost_cont .== 0)
        mean_delta_rd_cost = 0
        max_delta_rd_cost = 0
    else
        mean_delta_rd_cost = sum(delta_rd_cost_cont[findall(delta_rd_cost_cont .!=0.0)])/length(findall(delta_rd_cost_cont .!= 0.0))
        max_delta_rd_cost = maximum(rd_cost_no_hvdc_cont .- rd_cost_hvdc_cont)
    end

    delta_rd_cost[hour_idx]["rd_cost_no_hvdc_cont"] = rd_cost_no_hvdc_cont
    delta_rd_cost[hour_idx]["rd_cost_hvdc_cont"] = rd_cost_hvdc_cont
    delta_rd_cost[hour_idx]["delta_rd_cost_cont"] = delta_rd_cost_cont
    delta_rd_cost[hour_idx]["mean_delta_rd_cost"] = mean_delta_rd_cost
    delta_rd_cost[hour_idx]["max_delta_rd_cost"] = max_delta_rd_cost
end

hour_factor_rd = 8760/(number_of_clusters)

print("Average benefits of HVDC control: ", sum([hour["mean_delta_rd_cost"] for (h, hour) in delta_rd_cost]) * hour_factor_rd / 1e6,  " MEuro", "\n")
print("Maximum benefits of HVDC control: ", sum([hour["max_delta_rd_cost"] for (h, hour) in delta_rd_cost]) * hour_factor_rd / 1e6,   " MEuro", "\n")


# Save re-dispatch results
json_string = JSON.json(delta_rd_cost)
open(output_file_name_rd,"w") do f
write(f, json_string)
end

############# POST PROCESSING 
res_rd = Dict{String, Any}()
open(output_file_name_rd) do f
    dicttxt = read(f,String)  # file information to string
    global res_rd = JSON.parse(dicttxt)  # parse and transform data
end

print("Average benefits of HVDC control: ", sum([hour["mean_delta_rd_cost"] for (h, hour) in res_rd]) * hour_factor_rd / 1e6,  " MEuro", "\n")
print("Maximum benefits of HVDC control: ", sum([hour["max_delta_rd_cost"] for (h, hour) in res_rd]) * hour_factor_rd / 1e6,   " MEuro", "\n")


for (h, hour) in res_rd
    print(h, " ", hour["mean_delta_rd_cost"], "\n")
end