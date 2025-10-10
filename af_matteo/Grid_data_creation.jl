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
using DataFrames
using JLD2
using XLSX
using DataFrames
using CSV

######### DEFINE INPUT PARAMETERS
tyndp_version = "2024"
scenario = "FENICE"
#year = "2050"
climate_year = "2009"
load_data = true
use_case = "it"
hour_start = 1
hour_end = 8760
isolated_zones = ["IT-CSUD", "IT-SUD", "IT-NORD", "IT-CNOR", "IT-SICI","IT-SA"]

df_by_type = JSON.parsefile("D:/SEM/multi-period/abroad period EUGO/2-First output FENICE/df_by_type.json")
list_years = [2025]#[2035,2040,2045,2055]#[2030,2035,2040,2045,2050] #[2025,2030,2035,2040,2045,2050,2055]
for years in list_years

    file = "D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO/European_grid_no_nseh.json" #"./data_sources/European_grid_no_nseh.json"
    output_file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year]))
    #gurobi = Gurobi.Optimizer
    EU_grid = _PM.parse_file(file)
    _PMACDC.process_additional_data!(EU_grid)
    _EUGO.add_load_and_pst_properties!(EU_grid)

    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()    
    ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, node_positions = _EUGO.get_grid_data(tyndp_version, scenario, years, climate_year)

    zones_region = [
    "IT-1","IT-2","IT-3","IT-4","IT-5",
    "IT-6","IT-7","IT-8","IT-9","IT-10",
    "IT-11","IT-12","IT-13","IT-14","IT-15",
    "IT-16","IT-17","IT-18","IT-19","IT-20"
    ]

    # find which of those are not already present in nodes.node_id
    existing_ids = Set(string.(nodes[!, :node_id]))   # ensure comparison as String
    to_add = [z for z in zones_region if !(z in existing_ids)]

    if isempty(to_add)
        @info "No new IT region rows to add — all present already."
    else
        n = length(to_add)
        new_node_id      = to_add
        new_country_text = ["Italy $(split(z, '-')[end]) region" for z in to_add]  # "Italy xx region"
        new_country      = fill("IT", n)
        new_previous     = fill(missing, n)
        new_latitude     = fill(missing, n)
        new_longitude    = fill(missing, n)
        new_region       = fill(missing, n)
        new_EU28         = fill(missing, n)

        newdf = DataFrame(
            node_id = new_node_id,
            country_text = new_country_text,
            country = new_country,
            previous_node = new_previous,
            latitude = new_latitude,
            longitude = new_longitude,
            region = new_region,
            EU28 = new_EU28
        )

        # append rows while preserving column order and types
        nodes = vcat(nodes, newdf)

        @info "Added $(n) new rows to nodes."
    end




    # Construct input data dictionary in PowerModels style
    input_data, nodal_data = _EUGO.construct_data_dictionary(tyndp_version, ntcs, arcs, capacity, nodes, demand, scenario, climate_year, gen_types, pv, wind_onshore, wind_offshore, gen_costs, emission_factor, inertia_constants, node_positions)
    
    zonal_input = input_data
    scenario_data = nodal_data

    folder_path_zonal = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(years))
    file_path_zonal = joinpath(folder_path_zonal, "zonal_result.json")

    # Load the JSON
    zonal_result = open(file_path_zonal, "r") do io
        JSON.parse(io)
    end

    println("Loaded zonal_result for year $years")

    #### END ZONAL INPUT ####




    #### LOAD TYNDP SCENARIO DATA ##########
    year = string(years)
    if load_data == true
        #zonal_result, zonal_input, scenario_data = _EUGO.load_results(tyndp_version, scenario, year, climate_year) # Import zonal results
        ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(tyndp_version, scenario, year, climate_year) # import zonal input (mainly used for cost data)
        pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
    end
     

    print("ALL FILES LOADED", "\n")
    print("----------------------","\n")
    ######


    ##################### addded 27 08 ##################

    function add_zone_copy_from!(EU_grid::Dict{String,Any};
                                copy_from_key::String = "32",
                                peak_value::Float64 = 25.248,
                                new_zone_name::Union{Nothing,String}=nothing)
        # Basic checks
        @assert haskey(EU_grid, "zonal_peak_demand") "EU_grid has no 'zonal_peak_demand' key"
        @assert haskey(EU_grid, "zonal_generation_capacity") "EU_grid has no 'zonal_generation_capacity' key"

        zpd = EU_grid["zonal_peak_demand"]
        zgc = EU_grid["zonal_generation_capacity"]

        # collect integer keys (safe parse)
        nums = Int[]
        for k in keys(zpd)
            n = tryparse(Int, k)
            if n !== nothing
                push!(nums, n)
            end
        end

        maxk = isempty(nums) ? 0 : maximum(nums)
        new_k = string(maxk + 1)   # new key as string

        # set new peak demand (in-place)
        zpd[new_k] = float(peak_value)

        # copy generation capacity from copy_from_key
        if !haskey(zgc, copy_from_key)
            error("Source key '$copy_from_key' not found in zonal_generation_capacity")
        end
        zgc[new_k] = deepcopy(zgc[copy_from_key])

        # optionally override the internal zone name inside the copied generation capacity
        if new_zone_name !== nothing
            zgc[new_k]["zone"] = new_zone_name
        end

        # If EU_grid has "zones" vector, append the zone name (avoid duplicates)
        if haskey(EU_grid, "zones") && isa(EU_grid["zones"], AbstractVector)
            zone_name = get(zgc[new_k], "zone", nothing)
            if zone_name !== nothing && !(zone_name in EU_grid["zones"])
                push!(EU_grid["zones"], zone_name)
            end
        end

        # In-place update done. No return (mutates EU_grid).
        println("EU_grid updated: added keys zonal_peak_demand[$new_k] and zonal_generation_capacity[$new_k].")
    end


    # or with a custom zone name:
    add_zone_copy_from!(EU_grid; copy_from_key="22", peak_value=25.248, new_zone_name="IT-SA")

    ##################### addded 27 08 ##################

    # add data grid for Sardinia
    using DataFrames
    xlsx_file = "D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO/Dati Rete sardegna.xlsx"
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



    # Path to the Excel file
    file_path = "D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO/Hypergrid-Terna.xlsx"

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
                    branch_id = find_branch(EU_grid, fbus, tbus)            
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
                        branch_id = find_branch(EU_grid, fbus, tbus)          
                        delete!(EU_grid["branch"], string(branch_id))
                        dcfbus = row[:dcfbus]   
                        dctbus = row[:dctbus] 
                        power_rating = row[:power_rating]  
                        _EUGO.add_dc_branch!(EU_grid, dcfbus, dctbus, power_rating)
                        if row[:converter_need_from] == "yes"                         
                            power_rating = row[:power_rating]                            
                            power_rating_conv = row[:converter_from_power_rating]
                            zone = row[:converter_from_zone]
                            _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                        end
                        if row[:converter_need_to] == "yes"
                            power_rating = row[:power_rating]
                            zone = row[:converter_to_zone]
                            power_rating_conv = row[:converter_to_power_rating]
                            _EUGO.add_converter!(EU_grid, tbus, dctbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                        end

                    else
                        fbus = row[:dcfbus]   
                        tbus = row[:dctbus] 
                        branch_id = find_branch(EU_grid, fbus, tbus)  
                        EU_grid["branchdc"]["power_rating"]=row[:power_rating]
                        if row[:converter_need_from] == "yes"                         
                            power_rating = row[:power_rating]
                            zone = row[:converter_from_zone]
                            power_rating_conv = row[:converter_from_power_rating]
                            _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                        end
                        if row[:converter_need_to] == "yes"
                            power_rating = row[:power_rating]
                            zone = row[:converter_to_zone]
                            power_rating_conv = row[:converter_to_power_rating]
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
                            _EUGO.add_converter!(EU_grid, fbus, dcfbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end
                    if row[:converter_need_to] == "yes"
                            power_rating = row[:power_rating]
                            zone = row[:converter_to_zone]
                            power_rating_conv = row[:converter_to_power_rating]
                            _EUGO.add_converter!(EU_grid, tbus, dctbus, power_rating_conv,zone = zone)#, conv_id=converter_idx )
                    end

                end
            end

        end
    end

    delete!(EU_grid["branch"], "power_rating")
    zone_mapping = _EUGO.map_zones()
    zone_grid = _EUGO.isolate_zones(EU_grid, isolated_zones, border_slack = 0.01)

    # Scale generation capacity based on TYNDP data
    #_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)
    #_EUGO.scale_generation_updated!(tyndp_capacity, zone_grid, scenario, climate_year, zone_mapping,gen_costs; zones_noscaling = ["SI","AT","FR","CH","ME","GR"])
    # Isolate zone: input is vector of strings, if you need to relax the fixing border flow assumptions use:
    
    hydro_ror   = CSV.read("D:/SEM/multi-period/abroad period EUGO/2-First output FENICE/profiles/hydro_ror_profiles_$(years).csv", DataFrame)
    pv          = CSV.read("D:/SEM/multi-period/abroad period EUGO/2-First output FENICE/profiles/solar_pv_profiles_$(years).csv", DataFrame)
    wind_onshore = CSV.read("D:/SEM/multi-period/abroad period EUGO/2-First output FENICE/profiles/wind_profiles_$(years).csv", DataFrame)
    wind_offshore = CSV.read("D:/SEM/multi-period/abroad period EUGO/2-First output FENICE/profiles/wind_off_profiles_$(years).csv", DataFrame)
    
    zones_region = ["IT-1","IT-2","IT-3","IT-4","IT-5",
        "IT-6","IT-7","IT-8","IT-9","IT-10",
        "IT-11","IT-12","IT-13","IT-14","IT-15",
        "IT-16","IT-17","IT-18","IT-19","IT-20"
        ]

    timeseries_data = _EUGO.create_res_and_demand_time_series(hydro_ror, wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zones = zones_region)

    push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 

    plot_filename = joinpath(folder_path_zonal, join(["grid_input_",year,".pdf"]))
    _EUGO.plot_grid(zone_grid, plot_filename)

    folder_path = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(year))    
    result_file = joinpath(folder_path, "zone_grid.json")

    # Make sure the folder exists
    isdir(folder_path) || mkpath(folder_path)

    # Save the file
    open(result_file, "w") do io
        JSON.print(io, zone_grid)
    end

    folder_path = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(year))
    result_file = joinpath(folder_path, "timeseries_data.jld2")

    # timeseries_data is your Dict{String,Any}
    JLD2.@save result_file timeseries_data
    print("mp_zone_grid saved", "\n")

end



