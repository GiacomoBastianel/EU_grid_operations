#### Plots Matteo Catania


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

scenario = "DE"
year = "2050"
climate_year = "2009"
zonal_result, zonal_input, scenario_data = _EUGO.load_results("2024",scenario,year, climate_year)
file_name_marg = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results", "plots", join([scenario,"_", climate_year, "_zonal_marginal_prices.pdf"]))
file_name_avg = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results", "plots", join([scenario,"_", climate_year, "_zonal_average_costs.pdf"]))
zones = ["ITCA" "ITCN" "ITCO" "ITCS" "ITN1" "ITSA" "ITS1" "ITSI"]# "BE00" "AT00" "CH00" "UK00"]
_EUGO.plot_marginal_zonal_prices(zonal_result, zonal_input, file_name_marg; zones = zones)
_EUGO.plot_average_zonal_costs(zonal_result, zonal_input, file_name_avg; zones = zones)




use_case = "it"#"de_hvdc_backbone"
file_name = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/", join([use_case,"_",scenario,"_", climate_year])) #,"_inv"
hour_start = 1
hour_end = 8760 #720
batch_size = 24#365
load_data = true
zone = "ITN1"#"DE00"
#links = Dict("Suedostlink" => [] , "Suedostlink" => [], "Ultranet" => [])
############ LOAD EU grid data
file = "/Users/SEM2/.julia/dev/EU_grid_operations/data_sources/European_grid_no_nseh.json"
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)

#### LOAD TYNDP SCENARIO DATA ##########

if load_data == true
    zonal_result, zonal_input, scenario_data = _EUGO.load_results("2024",scenario,year, climate_year) # Import zonal results
    ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data("2024",scenario,year, climate_year) # import zonal input (mainly used for cost data)
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


isolated_zones = ["IT-CNOR","IT-CSUD","IT-NORD","IT-SUD","IT-SICI"]

# Isolate zone: input is vector of strings
# zone_grid = _EUGO.isolate_zones(EU_grid, ["DE"]; border_slack = 0.01)
zone_grid = _EUGO.isolate_zones(EU_grid, isolated_zones, border_slack = 0.01)


# add data grid for Sardinia

using XLSX
using DataFrames


xlsx_file = "c:/Users/SEM2/.julia/dev/EU_grid_operations/data_sources/Dati Rete sardegna.xlsx"


sheet_name = "BUS_AC"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    # Read required values
    row[:ac_voltage]
    ac_voltage = row[:ac_voltage]   
    zone = row[:zone]
    name = row[:Bus_name]
    # Optional parameters
    ac_bus_id = hasproperty(row, :Bus_idx) ? row[:Bus_idx] : nothing
    lat = hasproperty(row, :lat) ? row[:lat] : 0
    lon = hasproperty(row, :lon) ? row[:lon] : 0
    # Call your function
    add_ac_bus!(zone_grid, ac_voltage, zone, name; ac_bus_id=ac_bus_id, lat=lat, lon=lon)
end

sheet_name = "BUS_DC"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    # Read required values
    
    dc_voltage = row[:dc_voltage]   
    zone = row[:zone]
    name = row[:Bus_name]
    # Optional parameters
    dc_bus_id = hasproperty(row, :Bus_idx) ? row[:Bus_idx] : nothing
    lat = hasproperty(row, :lat) ? row[:lat] : 0
    lon = hasproperty(row, :lon) ? row[:lon] : 0
    # Call your function
    add_dc_bus!(zone_grid, dc_voltage, zone, name; dc_bus_id=dc_bus_id, lat=lat, lon=lon)
end

sheet_name = "Converter"
xlsx = XLSX.readxlsx(xlsx_file)
sheet = xlsx[sheet_name]  # get the specific sheet
df = DataFrame(XLSX.readtable(xlsx_file, sheet_name)...)
for row in eachrow(df)
    # Read required values
    
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
    # Read required values
    
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
    # Read required values
    
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
    # Read required values
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
    # Read required values
    
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
timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; )#zone = "IT"

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
zone_grid_un = zone_grid #_EUGO.add_hvdc_links(zone_grid, links)

ac_branch_flows, dc_branch_flows, results = _EUGO.get_branch_flows(hour_start, hour_end, batch_size, file_name) 

#delete!(dc_branch_flows, "101")
#delete!(zone_grid_un["branchdc"], "48")
#delete!(dc_branch_flows, "48")

flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = abs.(ac_branch_flows[b]) ./ zone_grid_un["branch"][b]["rate_a"]
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = abs.(dc_branch_flows[b]) ./ zone_grid_un["branchdc"][b]["rateA"]
end

#delete!(zone_grid_un["branchdc"], "78")
#delete!(zone_grid_un["branchdc"], "79")
#delete!(zone_grid_un["branchdc"], "77")
#delete!(zone_grid_un["branchdc"], "80")



colormap = ColorSchemes.jet1

plot_file_name = file_name = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results", "plots", join([use_case,"_",scenario,"_", climate_year,"_flows.pdf"]))

_EUGO.plot_grid(zone_grid_un, plot_file_name; color_branches = true,    flows_ac = flows_ac, flows_dc = flows_dc, plot_node_numbers_ac = true, maximum_flows = false)   #; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc
#colormap = colormap,
flows_ac_summed = Dict(k => sum(v) for (k, v) in flows_ac)

sorted_flows = sort(collect(flows_ac_summed), by = x -> x[2])
# Three minimum
println("Three minimum values:")
for (k, v) in sorted_flows[1:3]
    println("Key: $k, Value: $v")
end
# Three maximum
println("\nThree maximum values:")
for (k, v) in sorted_flows[end-2:end]
    println("Key: $k, Value: $v")
end






result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/it_DE_2009_opf_1_to_24.json"
result_1_24 = JSON.parsefile(result_file)
 
zone_grid["gen"]["3409"]
gen_3409 = [result_1_24["$h"]["solution"]["gen"]["3409"]["pg"] for h in 1:24]







##### Getting the generation from genrators ####

# Path to the folder containing the JSON result files
results_folder = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/"
base_filename = "it_DE_2009_opf_"

# Initialize an empty dictionary to store results for each generator
gen_dict = Dict{String, Vector{Float64}}()

# Iterate over all 24-hour chunks
for start_hour in 1:24:8760
    end_hour = min(start_hour + 23, 8760)
    filename = results_folder * base_filename * string(start_hour, "_to_", end_hour, ".json")
    
    # Parse JSON file
    if isfile(filename)
        result = JSON.parsefile(filename)
        
        for h in start_hour:end_hour
            hour_data = result[string(h)]
            
            # Skip if the hour has no solution/gen data
            if !haskey(hour_data, "solution") || !haskey(hour_data["solution"], "gen")
                continue
            end

            for (gen_id, gen_info) in hour_data["solution"]["gen"]
                pg = gen_info["pg"]

                if !haskey(gen_dict, gen_id)
                    gen_dict[gen_id] = Vector{Float64}(undef, 8760)
                end

                gen_dict[gen_id][h] = pg *100
            end
        end
    else
        println("Warning: File not found - $filename")
    end
end

# At this point, gen_dict contains all generators, each with their 8760-hour production vector.

# Step 1: Create a dictionary with the annual sum for each generator
gen_sum_dict = Dict{String, Float64}()

for (gen_id, production_vector) in gen_dict
    gen_sum_dict[gen_id] = sum(production_vector)
end

# Step 2: Group generators by bidding zone
zone_sum_dict = Dict{String, Float64}()

for (gen_id, gen_data) in zone_grid_un["gen"]
    zone = gen_data["zone"]

    # Skip if generator is not in gen_sum_dict (e.g. it didn’t produce or isn’t in the OPF results)
    if !haskey(gen_sum_dict, gen_id)
        continue
    end

    gen_total = gen_sum_dict[gen_id]

    if !haskey(zone_sum_dict, zone)
        zone_sum_dict[zone] = 0.0
    end

    zone_sum_dict[zone] += gen_total
end


using XLSX

# Convert the zone_sum_dict to vectors for writing
zones = collect(keys(zone_sum_dict))
sums = collect(values(zone_sum_dict))

# Create the Excel file
XLSX.openxlsx("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_production_sums.xlsx", mode="w") do xf
    sheet = xf[1]  # First sheet
    sheet["A1"] = "Zone"
    sheet["B1"] = "Annual Production (MWhe)"
    
    for (i, (zone, sum)) in enumerate(zip(zones, sums))
        sheet["A$(i+1)"] = zone
        sheet["B$(i+1)"] = sum
    end
end




using JSON
using XLSX

# Dictionary to store each load's 8760 pflex values
load_dict = Dict{String, Vector{Float64}}()

# Iterate through all result files
for start_hour in 1:24:8737
    end_hour = min(start_hour + 23, 8760)
    result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/it_DE_2009_opf_$(start_hour)_to_$(end_hour).json"
    
    if isfile(result_file)
        result_data = JSON.parsefile(result_file)
        
        for h in start_hour:end_hour
            h_str = string(h)
            if haskey(result_data, h_str) && haskey(result_data[h_str]["solution"], "load")
                load_result = result_data[h_str]["solution"]["load"]
                
                for (load_id, vals) in load_result
                    pflex = vals["pflex"]
                    if !haskey(load_dict, load_id)
                        load_dict[load_id] = zeros(8760)
                    end
                    load_dict[load_id][h] = pflex *100
                end
            end
        end
    end
end

# Sum each load over 8760 hours
load_sum_dict = Dict(load_id => sum(pflex_vector) for (load_id, pflex_vector) in load_dict)

# Aggregate by bidding zone
load_zone_sum_dict = Dict{String, Float64}()

for (load_id, total_pflex) in load_sum_dict
    zone = zone_grid_un["load"][load_id]["zone"]
    load_zone_sum_dict[zone] = get(load_zone_sum_dict, zone, 0.0) + total_pflex
end

# Remove zones with 0 total flexible load
load_zone_sum_dict = Dict(k => v for (k, v) in load_zone_sum_dict if v > 0.0)

# Write to Excel
XLSX.openxlsx("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_load_sums.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["A1"] = "Zone"
    sheet["B1"] = "Total Flexible Load (MWhe)"
    
    i = 2
    for (zone, total_pflex) in load_zone_sum_dict
        sheet["A$(i)"] = zone
        sheet["B$(i)"] = total_pflex
        i += 1
    end
end



# Initialize new dictionary to hold only interconnectors
branch_interconnector = Dict{String, Dict{String, Any}}()

# Loop over each branch in the "branch" part of the dictionary
for (key, value) in zone_grid_un["branch"]
    if value["interconnector"] == true
        branch_interconnector[key] = value
    end
end

# Loop over each branch in the "branch" part of the dictionary
#for (key, value) in zone_grid_un["bus"]
#    if value["interconnector"] == true
#        branch_interconnector[key] = value
#    end
#end

gen_by_zone = Dict{String, Dict{String, Any}}()

for (gen_id, gen_data) in zone_grid_un["gen"]
    zone = gen_data["zone"]
    if !haskey(gen_by_zone, zone)
        gen_by_zone[zone] = Dict{String, Any}()
    end
    gen_by_zone[zone][gen_id] = gen_data
end

using JSON

gen_by_zone_result = Dict{String, Dict{String, Vector{Float64}}}()

# Loop over all 24-hour chunks
for start_hour in 1:24:8760
    end_hour = min(start_hour + 23, 8760)
    filename = results_folder * base_filename * string(start_hour, "_to_", end_hour, ".json")
    
    if isfile(filename)
        result = JSON.parsefile(filename)
        
        for h in start_hour:end_hour
            hour_data = result[string(h)]
            
            # Skip if no generation data
            if !haskey(hour_data, "solution") || !haskey(hour_data["solution"], "gen")
                continue
            end

            for (gen_id, gen_info) in hour_data["solution"]["gen"]
                pg = gen_info["pg"]

                # Check if the generator exists in the input dictionary
                if haskey(zone_grid_un["gen"], gen_id)
                    gen_meta = zone_grid_un["gen"][gen_id]
                    zone = gen_meta["zone"]

                    # Initialize zone and generator entry if not yet created
                    if !haskey(gen_by_zone_result, zone)
                        gen_by_zone_result[zone] = Dict{String, Vector{Float64}}()
                    end
                    if !haskey(gen_by_zone_result[zone], gen_id)
                        gen_by_zone_result[zone][gen_id] = zeros(Float64, 8760)
                    end

                    # Store generation in correct hour (multiply by 100 as in your example)
                    gen_by_zone_result[zone][gen_id][h] = pg * 100
                end
            end
        end
    else
        println("Warning: File not found - $filename")
    end
end



# Initialize empty dictionary for grouped data
zoned_data = Dict{String, Dict{String, Dict{String, Any}}}()

# Sections you want to group by zone
sections = ["bus", "gen", "load", "storage", "convdc", "busdc"]

# Loop through each section and group by "zone"
for section in sections
    if haskey(zone_grid_un, section)
        for (id, item) in zone_grid_un[section]
            if haskey(item, "zone")
                zone = string(item["zone"])  # convert zone to String

                # Create nested dictionaries if they don’t exist yet
                if !haskey(zoned_data, zone)
                    zoned_data[zone] = Dict{String, Dict{String, Any}}()
                end
                if !haskey(zoned_data[zone], section)
                    zoned_data[zone][section] = Dict{String, Any}()
                end

                # Add the item to the appropriate spot
                zoned_data[zone][section][string(id)] = item
            end
        end
    end
end

# Assuming zoned_data["IT-SICI"]["load"] is the dictionary you showed

load_data1 = zoned_data["IT-SICI"]["load"]

total_powerportion = sum(v["powerportion"] for v in values(load_data1))
total_pd = sum(v["pd"] for v in values(load_data1))
total_pmax = sum(v["pmax"] for v in values(load_data1))

println("Total powerportion: ", total_powerportion)
println("Total pd: ", total_pd)
println("Total pmax: ", total_pmax)



# Initialize the result dictionary: branch_id => Dict("pt" => [...], "pf" => [...])
branch_result = Dict{String, Dict{String, Vector{Float64}}}()

# Loop over all 24-hour chunks in a year (8760 hours total)
for start_hour in 1:24:8760
    end_hour = min(start_hour + 23, 8760)
    filename = results_folder * base_filename * string(start_hour, "_to_", end_hour, ".json")
    
    if isfile(filename)
        result = JSON.parsefile(filename)

        for h in start_hour:end_hour
            hour_data = result[string(h)]
            
            # Skip if no generation/branch data
            if !haskey(hour_data, "solution") || !haskey(hour_data["solution"], "branch")
                continue
            end

            for (branch_id, branch_info) in hour_data["solution"]["branch"]
                pt = branch_info["pt"]
                pf = branch_info["pf"]

                # Only include branches that exist in the model
                if haskey(zone_grid_un["branch"], branch_id)
                    # Initialize data structure if not already created
                    if !haskey(branch_result, branch_id)
                        branch_result[branch_id] = Dict(
                            "pt" => zeros(Float64, 8760),
                            "pf" => zeros(Float64, 8760)
                        )
                    end

                    # Store the values in the correct hour (1-based index)
                    branch_result[branch_id]["pt"][h] = pt * 100
                    branch_result[branch_id]["pf"][h] = pf * 100
                end
            end
        end
    else
        println("Warning: File not found - $filename")
    end
end


# Create a new dictionary with zone info for each interconnector branch
branch_interconnector_results = Dict{String, Dict{String, Any}}()

for (branch_id, inter_data) in branch_interconnector
    if haskey(branch_result, branch_id)
        # Get f_bus and t_bus as Strings (zone_grid_un keys are strings)
        f_bus = string(inter_data["f_bus"])
        t_bus = string(inter_data["t_bus"])

        # Get zone from zone_grid_un
        zone_f = haskey(zone_grid_un["bus"], f_bus) ? zone_grid_un["bus"][f_bus]["zone"] : "UNKNOWN"
        zone_t = haskey(zone_grid_un["bus"], t_bus) ? zone_grid_un["bus"][t_bus]["zone"] : "UNKNOWN"

        # Add all data to the result dictionary
        branch_interconnector_results[branch_id] = Dict(
            "pt" => branch_result[branch_id]["pt"],
            "pf" => branch_result[branch_id]["pf"],
            "f_bus" => inter_data["f_bus"],
            "t_bus" => inter_data["t_bus"],
            "zone_f_bus" => zone_f,
            "zone_t_bus" => zone_t
        )
    end
end

branch_interconnector_results_by_zone = Dict{String, Dict{String, Dict{String, Any}}}()

for (branch_id, data) in branch_interconnector_results
    zone_f = data["zone_f_bus"]
    zone_t = data["zone_t_bus"]
    zone_pair = "$zone_f---$zone_t"
    if !haskey(branch_interconnector_results_by_zone, zone_pair)
        branch_interconnector_results_by_zone[zone_pair] = Dict{String, Dict{String, Any}}()
    end
    branch_interconnector_results_by_zone[zone_pair][branch_id] = data
end

branch_interconnector_sum_by_zone = Dict{String, Dict{String, Vector{Float64}}}()

for (zone_pair, branches) in branch_interconnector_results_by_zone
    pt_sum = nothing
    pf_sum = nothing

    for (_, data) in branches
        pt = data["pt"]
        pf = data["pf"]

        # Initialize with the first vector
        if pt_sum === nothing
            pt_sum = copy(pt)
            pf_sum = copy(pf)
        else
            pt_sum .+= pt
            pf_sum .+= pf
        end
    end

    branch_interconnector_sum_by_zone[zone_pair] = Dict(
        "pt" => pt_sum,
        "pf" => pf_sum
    )
end


total_ps_sum = sum(
    sum(st["ps"] for (_, st) in results[string(t)]["solution"]["storage"])
    for t in 1:8760
)
