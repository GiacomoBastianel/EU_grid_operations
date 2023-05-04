### This file contains some plotting examples to visual the results coming from the nodal or zonal model



## Import required functions - Some of them in later stages....
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations

using Plots
import JuMP
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
using ColorSchemes

#####################################################################
#### Printing average zonal prices and average zonal costs
#####################################################################
scenario = "GA2030"
climate_year = "2007"
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
scenario = "GA2030"
climate_year = "2007"
use_case = "de_hvdc_backbone"
file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year,"_inv"]))
hour_start = 1
hour_end = 8760
batch_size = 365
load_data = true
zone = "DE00"
links = Dict("Suedostlink" => [] , "Suedostlink" => [], "Ultranet" => [])
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

zone_mapping = _EUGO.map_zones()

_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)

grid = _EUGO.isolate_zones(EU_grid, ["DE"])

data_link = _EUGO.add_hvdc_links(grid, links)

ac_branch_flows, dc_branch_flows = _EUGO.get_branch_flows(hour_start, hour_end, batch_size, file_name)  

flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = abs.(ac_branch_flows[b]) ./ data_link["branch"][b]["rate_a"]
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = abs.(dc_branch_flows[b]) ./ data_link["branchdc"][b]["rateA"]
end


colormap = ColorSchemes.jet1

plot_file_name = file_name = joinpath("results", "plots", join([use_case,"_",scenario,"_", climate_year,"_flows.pdf"]))

_EUGO.plot_grid(data_link, plot_file_name; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc, maximum_flows = false)   #; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc
