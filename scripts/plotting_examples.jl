### This file contains some plotting examples to visual the results coming from the nodal or zonal model



## Import required functions - Some of them in later stages....
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations

using Plots
import JuMP
import JSON
import CbaOPF
import DataFrames; const _DF = DataFrames
import CSV
import Feather
using XLSX
using Statistics
using Clustering
using StatsBase
import StatsPlots
using ColorSchemes

#####################################################################
#### Printing average zonal prices and average zonal costs
#####################################################################
scenario = "DE2050"
climate_year = "2009"
zonal_result, zonal_input, scenario_data = _EUGO.load_results(scenario, climate_year)
file_name_marg = joinpath("results", "plots", join([scenario,"_", climate_year, "_zonal_marginal_prices.pdf"]))
file_name_avg = joinpath("results", "plots", join([scenario,"_", climate_year, "_zonal_average_costs.pdf"]))
zones = ["DE00" "FR00" "NL00" "BE00" "AT00" "CH00" "UK00"]
_EUGO.plot_marginal_zonal_prices(zonal_result, zonal_input, file_name_marg; zones = zones)
_EUGO.plot_average_zonal_costs(zonal_result, zonal_input, file_name_avg; zones = zones)



#####################################################################################
#### Plotting average line loadings as colors using a color map, on a geographic map
#####################################################################################
# DEFINE INPUT PARAMETERS
scenario = "DE2050" #"GA2030"
climate_year = "2009"#"2007"
use_case = "de_hvdc_backbone"
file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year,"_inv"]))
hour_start = 1
hour_end = 8760
batch_size = 365
load_data = true
zone = "IT01"#"DE00"
links = Dict("Suedostlink" => [] , "Suedostlink" => [], "Ultranet" => [])
############ LOAD EU grid data
file = "./data_sources/European_grid_no_nseh.json"
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
# zone_grid = _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = 0.01)

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

ac_branch_flows, dc_branch_flows = _EUGO.get_branch_flows(hour_start, hour_end, batch_size, file_name) 

delete!(dc_branch_flows, "101")

flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = abs.(ac_branch_flows[b]) ./ zone_grid_un["branch"][b]["rate_a"]
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = abs.(dc_branch_flows[b]) ./ zone_grid_un["branchdc"][b]["rateA"]
end


colormap = ColorSchemes.jet1

plot_file_name = file_name = joinpath("results", "plots", join([use_case,"_",scenario,"_", climate_year,"_flows.pdf"]))

_EUGO.plot_grid(zone_grid_un, plot_file_name; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc, maximum_flows = false)   #; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc
