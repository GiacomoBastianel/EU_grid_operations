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
scenario = "FENICE"
year = "2050"
climate_year = "2009"
load_data = true
use_case = "it"
hour_start = 1
hour_end = 8760
isolated_zones = ["IT-CSUD", "IT-SUD", "IT-NORD", "IT-CNOR", "IT-SICI","IT-SA"]
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
gdshfs
print("ALL FILES LOADED", "\n")
print("----------------------","\n")
######

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
    _EUGO.add_ac_bus!(EU_grid, ac_voltage, zone, name; ac_bus_id=ac_bus_id, lat=lat, lon=lon)
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
    _EUGO.add_dc_bus!(EU_grid, dc_voltage, zone, name; dc_bus_id=dc_bus_id, lat=lat, lon=lon)
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
    _EUGO.add_converter!(EU_grid, ac_bus_idx, dc_bus_idx, power_rating,zone = zone, conv_id=converter_idx )
end

sheet_name = "branch ac"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)   
    fbus = row[:fbus]   
    tbus = row[:tbus] 
    power_rating = row[:power_rating]
    _EUGO.add_ac_branch!(EU_grid, fbus, tbus, power_rating)
end

sheet_name = "branch dc"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    fbus = row[:fbus]   
    tbus = row[:tbus] 
    power_rating = row[:power_rating]  
    _EUGO.add_dc_branch!(EU_grid, fbus, tbus, power_rating)
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
    _EUGO.add_generator!(EU_grid, gen_bus, power_rating, gen_zone, gen_type)
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
    _EUGO.add_load!(EU_grid, load_bus, peak_power, load_zone, powerportion,country_peak_load)
end

# map EU-Grid zones to TYNDP model zones
using XLSX
using DataFrames
using CSV

# Path to the Excel file
file_path = "c:/Users/SEM2/.julia/dev/EU_grid_operations/data_sources/Hypergrid-Terna.xlsx"



sheet_name = "new_bus_dc"
xlsx = XLSX.readxlsx(file_path)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(file_path, sheet_name)...)
for row in eachrow(df)
    dc_voltage = row[:dc_voltage]   
    zone = row[:zone]
    name = row[:Bus_name]
    dc_bus_id = hasproperty(row, :Bus_idx) ? row[:Bus_idx] : nothing
    lat = hasproperty(row, :lat) ? row[:lat] : 0
    lon = hasproperty(row, :lon) ? row[:lon] : 0
    _EUGO.add_dc_bus!(EU_grid, dc_voltage, zone, name; dc_bus_id=dc_bus_id, lat=lat, lon=lon)
end



# Read the sheet into a DataFrame
xlsx = XLSX.readxlsx(file_path)
sheet_name = "new_construction_terna"
sheet = xlsx[sheet_name]
df = DataFrame(XLSX.gettable(sheet)...)
# Display all column names
function find_branch(zone_grid::Dict, from_bus::Int, to_bus::Int)
    for (branch_id, branch_data) in zone_grid["branch"]
        if branch_data isa Dict
            f = branch_data["f_bus"]
            t = branch_data["t_bus"]
            if (f == from_bus && t == to_bus) || (f == to_bus && t == from_bus)
                return branch_id
            end
        else
            @warn "branch_data is not a dictionary" branch_id branch_data
        end
        #print(branch_id)
        #print(branch_data)
        #f = zone_grid["branch"][branch_id]["f_bus"]
        #t = zone_grid["branch"][branch_id]["t_bus"]
        #f = branch_data["f_bus"]
        #t = branch_data["t_bus"]
        
    end
    return nothing  # if no matching branch is found
end

function find_branch_dc(zone_grid::Dict, from_bus::Int, to_bus::Int)
    for (branch_id, branch_data) in zone_grid["branchdc"]
        if branch_data isa Dict
            f = branch_data["f_bus"]
            t = branch_data["t_bus"]
            if (f == from_bus && t == to_bus) || (f == to_bus && t == from_bus)
                return branch_id
            end
        else
            @warn "branch_data is not a dictionary" branch_id branch_data
            
        end
        
    end
    return nothing  # if no matching branch is found
end

for row in eachrow(df)
    if row[:type] == "AC"
        if row[:existing] == "yes"
            if row[:year_completment] <= parse(Int,year)
                fbus = row[:fbus]   
                tbus = row[:tbus] 
                branch_id = find_branch(zone_grid, fbus, tbus)            
                #delete!(zone_grid_un["branchdc"], str(number))
                EU_grid["branch"]["power_rating"]=row[:power_rating]
            end

        else
            if row[:year_completment] <= int(year)
                fbus = row[:fbus]   
                tbus = row[:tbus] 
                power_rating = row[:power_rating]
                _EUGO.add_ac_branch!(EU_grid, fbus, tbus, power_rating)
            end
        end

    else 
        if row[:year_completment] <= parse(Int,year)
            if row[:existing] == "yes"
                if row[:from_AC_to_DC] == "yes"
                    fbus = row[:fbus]   
                    tbus = row[:tbus]
                    branch_id = find_branch(zone_grid, fbus, tbus)          
                    delete!(EU_grid["branch"], string(branch_id))
                    dcfbus = row[:dcfbus]   
                    dctbus = row[:dctbus] 
                    power_rating = row[:power_rating]  
                    _EUGO.add_dc_branch!(EU_grid, dcfbus, dctbus, power_rating)
                    if row[:converter_need_from] == "yes"                         
                        power_rating = row[:power_rating]
                        
                        power_rating_conv = row[:converter_from_power_rating]
                        zone = row[:converter_from_zone]
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end
                    if row[:converter_need_to] == "yes"
                        power_rating = row[:power_rating]
                        zone = row[:converter_to_zone]
                        power_rating_conv = row[:converter_to_power_rating]
                        
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, tbus, dctbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end

                else
                    fbus = row[:dcfbus]   
                    tbus = row[:dctbus] 
                    branch_id = find_branch(zone_grid, fbus, tbus)  
                    EU_grid["branchdc"]["power_rating"]=row[:power_rating]
                    if row[:converter_need_from] == "yes"                         
                        power_rating = row[:power_rating]
                        zone = row[:converter_from_zone]
                        power_rating_conv = row[:converter_from_power_rating]
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end
                    if row[:converter_need_to] == "yes"
                        power_rating = row[:power_rating]
                        zone = row[:converter_to_zone]
                        power_rating_conv = row[:converter_to_power_rating]
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, tbus, dctbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end
                end
            else
                fbus = row[:fbus]   
                tbus = row[:tbus] 
                power_rating = row[:power_rating]  
                dcfbus = row[:dcfbus]   
                dctbus = row[:dctbus] 
                _EUGO.add_dc_branch!(EU_grid, dcfbus, dctbus, power_rating)
                if row[:converter_need_from] == "yes"                         
                        power_rating = row[:power_rating]
                        
                        power_rating_conv = row[:converter_from_power_rating]
                        zone = row[:converter_from_zone]
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                end
                if row[:converter_need_to] == "yes"
                        power_rating = row[:power_rating]
                        zone = row[:converter_to_zone]
                        power_rating_conv = row[:converter_to_power_rating]
                        
                        #converter_idx = row[:converter_idx]
                        _EUGO.add_converter!(EU_grid, tbus, dctbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                end

            end
        end

    end
end

delete!(EU_grid["branch"], "power_rating")

zone_mapping = _EUGO.map_zones()

gen_SICI = Dict(g => gen for (g, gen) in EU_grid["gen"] if gen["zone"] == "IT-SICI")
gen_SICI_SOLAR = Dict(g => gen for (g, gen) in gen_SICI if gen["type_tyndp"] == "Solar PV")
gen_SICI_SOLAR_cap = sum(gen["pmax"] for (g, gen) in gen_SICI if gen["type_tyndp"] == "Solar PV")
# Scale generation capacity based on TYNDP data
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)
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

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true,  "objective_components" => ["gen", "demand"])

mp_zone_grid = _EUGO.multiperiod_grid_data(zone_grid, hour_start_idx, hour_end_idx, timeseries_data)

gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer,     "Crossover" => 0,    "Method" => 2,)

result = _PMACDC.solve_acdcopf(mp_zone_grid, _PM.DCPPowerModel, gurobi; multinetwork=true, setting = s)

result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json"

# Save the dictionary as a JSON file
open(result_file, "w") do io
    JSON.print(io, result)
end

result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_grid.json"

# Save the dictionary as a JSON file
open(result_file, "w") do io
    JSON.print(io, zone_grid)
end


for n = 1:hour_end_idx
  println((n, sum([gen["pg"] for (g, gen) in result["solution"]["nw"]["$n"]["gen"]])))
end
for n = 1:hour_end_idx
   println((n, sum([load["pflex"] for (l, load) in result["solution"]["nw"]["$n"]["load"]])))
end

for n = 1: (hour_end_idx - hour_start_idx)
  println((n, sum([strg["ps"] for (s, strg) in result["solution"]["nw"]["$n"]["storage"]])))
end

total_generation=0
for n = 1:hour_end_idx
  total_generation= total_generation +sum([gen["pg"] for (g, gen) in result["solution"]["nw"]["$n"]["gen"]])
end
print(total_generation)
# This function will  create a dictionary with all hours as result. For all 8760 hours, this might be memory intensive
# result = _EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s)
# obj = [result["$(i)"]["termination_status"] for i in 1:8760]; countmap(obj) # chcek objective
 
# An alternative is to run it in chuncks of "batch_size", which will store the results as json files, e.g. hour_1_to_batch_size, ....
#batch_size = 8760
#_EUGO.batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, gurobi, s, batch_size, output_file_name)