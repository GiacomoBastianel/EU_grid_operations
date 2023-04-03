#####################################
# get_value.jl
# Author: Hakan Ergun 24.03.2022
# Functions to extract hourly demand and installed generation capacity
#######################################

# Gets hourly demand data from dataframe demand
# area{String} ... name of zone, e.g. "AL00"
# hour{Int} selected hour {1,2, ...., 8760}
function get_demand_data(demand, area, hour)
    if    sum(names(demand) .== area) !=0
        value = demand[!, area][hour]
    else
        value = 0
    end
       
    return value
end

# Extract generation capacity for each scenario, generation type, climate year and zone
# Capacity: Input data frame with generation capacity
# scenario{String}, e.g. "NT2025"
# type{String}: Generation type, e.g. "Solar PV"
# climate_year{Int}: {1982, 1984, 2007} 
# node{String}: zone name, e.g. "AL00"
function get_generation_capacity(capacity, scenario, type, climate_year, node)
    if scenario == "DE2040"
        scenario = "DE2040 Update"
    end
    nodal_gen = capacity[capacity[!, "Node/Line"] .== node, :]
    nodal_gen_type = nodal_gen[nodal_gen[!, "Generator_ID"] .== type, :]
    values = nodal_gen_type[nodal_gen_type[!, "Simulation_ID"] .== scenario, :]
    value = values[values[!, "Climate Year"] .== parse(Int, climate_year), "Value"]
    return value
end

# Extract hourly RES capacity factors from RES time series
# source{DataFrame} with time series data for each climate year, zone and hour
# area{String}: zone name, e.g. "AL00"
# climate_year{Int}: {1982, 1984, 2007} 
# hour{Int} selected hour {1,2, ...., 8760}
function get_res_data(source, area, climate_year, hour)
    if sum(source[!, "area"].== area) != 0
        value = source[source[!, "area"] .== area, climate_year][hour]
    else
        value = 0
    end
    
    return value
end