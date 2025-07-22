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
import Feather
using XLSX
using Statistics
using Clustering
using StatsBase
import StatsPlots
 
######### DEFINE INPUT PARAMETERS
tyndp_version = "2024"
scenario = "DE"
year = "2050"
climate_year = "2009"
load_data = true
use_case = "it"
#use_case = "pt_es_fr"
 
hour_start = 1
hour_end = 8760
############ LOAD EU grid data
file = "c:/Users/SEM2/.julia/dev/EU_grid_operations/data_sources/European_grid_no_nseh.json" #"./data_sources/European_grid_no_nseh.json"
output_file_name = joinpath("c:/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024", join([use_case,"_",scenario,"_", climate_year]))
gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)
 
 
#zones = unique(EU_grid["bus"]["$b_id"]["zone"] for (b_id,b) in EU_grid["bus"])
isolated_zones = ["IT-CNOR","IT-CSUD","IT-NORD","IT-SUD","IT-SICI","IT-SA"]
 # [IT-CSUD, IT-SUD, IT-NORD, IT-SICI,]







 
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
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)
 
# Isolate zone: input is vector of strings, if you need to relax the fixing border flow assumptions use:
# _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = x), this will leas to (1-slack)*xb_flow_ref < xb_flow < (1+slack)*xb_flow_ref
zone_grid = _EUGO.isolate_zones(EU_grid, isolated_zones, border_slack = 0.01)


# delate all the storages
for key in keys(zone_grid["storage"])
    delete!(zone_grid["storage"], key)
end


# add data grid for Sardinia
using DataFrames
xlsx_file = "c:/Users/SEM2/.julia/dev/EU_grid_operations/data_sources/Dati Rete sardegna.xlsx"
sheet_name = "BUS_AC"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    row[:ac_voltage]
    ac_voltage = row[:ac_voltage]   
    zone = row[:zone]
    name = row[:Bus_name]
    ac_bus_id = hasproperty(row, :Bus_idx) ? row[:Bus_idx] : nothing
    lat = hasproperty(row, :lat) ? row[:lat] : 0
    lon = hasproperty(row, :lon) ? row[:lon] : 0
    add_ac_bus!(zone_grid, ac_voltage, zone, name; ac_bus_id=ac_bus_id, lat=lat, lon=lon)
end

sheet_name = "BUS_DC"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    dc_voltage = row[:dc_voltage]   
    zone = row[:zone]
    name = row[:Bus_name]
    dc_bus_id = hasproperty(row, :Bus_idx) ? row[:Bus_idx] : nothing
    lat = hasproperty(row, :lat) ? row[:lat] : 0
    lon = hasproperty(row, :lon) ? row[:lon] : 0
    add_dc_bus!(zone_grid, dc_voltage, zone, name; dc_bus_id=dc_bus_id, lat=lat, lon=lon)
end

sheet_name = "Converter"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    ac_bus_idx = row[:ac_bus_idx]   
    dc_bus_idx = row[:dc_bus_idx] 
    power_rating = row[:power_rating]
    zone = row[:zone]
    converter_idx = row[:converter_idx]
    add_converter!(zone_grid, ac_bus_idx, dc_bus_idx, power_rating,zone = zone, conv_id=converter_idx )
end

sheet_name = "Converter"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    ac_bus_idx = row[:ac_bus_idx]   
    dc_bus_idx = row[:dc_bus_idx] 
    power_rating = row[:power_rating]
    zone = row[:zone]
    converter_idx = row[:converter_idx]
    add_converter!(zone_grid, ac_bus_idx, dc_bus_idx, power_rating,zone = zone, conv_id=converter_idx )
end

sheet_name = "branch ac"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)   
    fbus = row[:fbus]   
    tbus = row[:tbus] 
    power_rating = row[:power_rating]
    add_ac_branch!(zone_grid, fbus, tbus, power_rating)
end

sheet_name = "branch dc"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    fbus = row[:fbus]   
    tbus = row[:tbus] 
    power_rating = row[:power_rating]  
    add_dc_branch!(zone_grid, fbus, tbus, power_rating)
end

sheet_name = "gen"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    gen_bus = row[:gen_bus]   
    gen_zone = row[:gen_zone] 
    power_rating = row[:power_rating]
    gen_type = row[:gen_type]
    add_generator!(zone_grid, gen_bus, power_rating, gen_zone, gen_type)
end

sheet_name = "load"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)      
    load_bus = row[:load_bus]   
    load_zone = row[:load_zone] 
    peak_power = row[:peak_power]
    powerportion = row[:powerportion]
    country_peak_load = row[:country_peak_load]
    add_load!(zone_grid, load_bus, peak_power, load_zone, powerportion,country_peak_load)
end


# create RES time series based on the TYNDP model for
# (1) all zones, e.g.  create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping)
# (2) a specified zone, e.g. create_res_time_series(wind_onshore, wind_offshore, pv, zone_mapping; zone = "DE")
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zones = isolated_zones)
 
#cf_pv = timeseries_data["solar_pv"]["IT-CNOR"]
#scatter(cf_pv, label = "PV", title = "PV capacity factor", xlabel = "hour", ylabel = "capacity factor", legend = :topright)
 
push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping))
 
# Start runnning hourly OPF calculations
hour_start_idx = 1
hour_end_idx = 8760 #720
 
plot_filename = joinpath("c:/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024", join(["grid_input_",use_case,".pdf"]))
_EUGO.plot_grid(zone_grid, plot_filename)
 
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)
# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
# result = _EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s)
# obj = [result["$(i)"]["termination_status"] for i in 1:8760]; countmap(obj) # chcek objective
 
# An alternative is to run it in chuncks of "batch_size", which will store the results as json files, e.g. hour_1_to_batch_size, ....
batch_size = 24
_EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s, batch_size, output_file_name)
 
result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/it_DE_2009_opf_1_to_24.json"
 
result_1_24 = JSON.parsefile(result_file)
 
zone_grid["gen"]["3409"]
gen_3409 = [result_1_24["$h"]["solution"]["gen"]["3409"]["pg"] for h in 1:24]
 
plot(gen_3409*100)
 
 
result_1_24["1"]["solution"]["gen"]["3409"]

#total_pmax_sici = 0.0
#total_powerportion_sici = 0.0

#for (_, entry) in zone_grid_un["load"]
#    if entry["zone"] == "IT-SICI"
#        total_pmax_sici += entry["pmax"]
#        total_powerportion_sici += entry["powerportion"]
#    end
#end

#println("Total pmax: ", total_pmax_sici)
#println("Total powerportion: ", total_powerportion_sici)