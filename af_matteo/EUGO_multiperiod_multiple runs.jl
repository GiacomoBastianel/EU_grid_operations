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
gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer,     "Crossover" => 0,    "Method" => 2,)

list_years = [2045,2055,2040]#[2025,2030,2035,2040,2045,2055] #[2025, 2030, 2035, 2040, 2045, 2050, 2055]#[2045, 2050 ,2055]#[2030, 2035, 2040, 2045, 2050, 2055] # [2025, 2030, 2035, 2040, 2045, 2050, 2055]

for year in list_years
    
    using JSON
    # # Build the path dynamically
    folder_path = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(year))
    file_path = joinpath(folder_path, "updated_zone_grid_with_regions_with_bus_shares.json")  #updated_

     # Load the JSON
    zone_grid = open(file_path, "r") do io
        JSON.parse(io)
    end
    # Build the path dynamically
    folder_path = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(year))
    file_path = joinpath(folder_path, "timeseries_data.jld2")
    using JLD2
    timeseries_data = jldopen(file_path, "r") do f
        read(f, "timeseries_data")
    end
    
    for (border, dict) in timeseries_data["xb_flows"]
        if haskey(dict, "flow")
            dict["flow"] .= -dict["flow"]   # broadcasted negation, modifies in place
        end
    end
    
    # Start runnning hourly OPF calculations
    hour_start_idx = 1 
    hour_end_idx =  8760

    folder_path_zonal = joinpath("D:/SEM/multi-period/abroad period EUGO/3-Zone grid EUGO", string(year))
    plot_filename = joinpath(folder_path_zonal, join(["grid_input_",year,".pdf"]))

    ### add new scale generation ####
    years_scale = string(year)
    if load_data == true
        #zonal_result, zonal_input, scenario_data = _EUGO.load_results(tyndp_version, scenario, year, climate_year) # Import zonal results
        ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(tyndp_version, scenario, years_scale, climate_year) # import zonal input (mainly used for cost data)
        
    end
    zone_mapping = _EUGO.map_zones()
    _EUGO.scale_generation_updated_regions_renshare!(tyndp_capacity, zone_grid, scenario, climate_year, zone_mapping,gen_costs; zones_noscaling = ["SI","AT","FR","CH","ME","GR"])


    #isolated_zones = ["IT-CSUD", "IT-SUD", "IT-NORD", "IT-CNOR", "IT-SICI","IT-SA"]
    #zone_grid = _EUGO.isolate_zones(zone_grid, isolated_zones, border_slack = 0.01)

    ###### end scale generation ####

    #zone_grid1, timeseries_data = load_zone_and_timeseries(year, "D:/SEM/multi-period/abroad period EUGO/2-Zone grid EUGO")

    _EUGO.plot_grid(zone_grid, plot_filename)
    
    mp_zone_grid = _EUGO.multiperiod_grid_data_regional(zone_grid, hour_start_idx, hour_end_idx, timeseries_data)
  
    println("Loaded mp_zone_grid for year $year")
    
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true,  "objective_components" => ["gen", "demand"])
    
    result = _PMACDC.solve_acdcopf(mp_zone_grid, _PM.DCPPowerModel, gurobi; multinetwork=true, setting = s)

    #result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json"
    folder_path = joinpath("D:/SEM/multi-period/abroad period EUGO/6-outputs EUGO/outputs EUGO", string(year))
    result_file = joinpath(folder_path, "result_multiperiod_FENICE.json" )
    # Make sure the folder exists
    isdir(folder_path) || mkpath(folder_path)
    
    # Save the dictionary as a JSON file
    open(result_file, "w") do io
        JSON.print(io, result)
    end

    result_file = joinpath(folder_path, "mp_zone_grid.json" )

    # Save the dictionary as a JSON file
    open(result_file, "w") do io
        JSON.print(io, mp_zone_grid)
    end

    println("Saved results for year $year in $result_file")

end