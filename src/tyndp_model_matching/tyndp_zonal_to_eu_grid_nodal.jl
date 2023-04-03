

function assign_res()
end

# This function scales the "pmax" value of each generator based on the installed total capacity coming from the TYNDP data. 
# tyndp_capacity ::DataFrame - The installed generation capacity coming from the zonal model, per zone and generation type, climate year and scenario
# grid_data ::Dict{String, Any} - EU grid model
# scneario ::String - Name of the scenario, e.g. "GA2030"
# climate_year ::String - Climate year e.g. "2007"
# zone_mapping ::Dict{String, Any} - Dictionary containing the mapping of zone names between both models
# ns_hub_cap ::Float64 - Capacity of the North Sea energy hub as optional keyword argument. Default value coming from the grid model is 10 GW.
function scale_generation!(tyndp_capacity, grid_data, scenario, climate_year, zone_mapping; ns_hub_cap = nothing)
    for (g, gen) in grid_data["gen"]
        zone = gen["zone"]

        # Check if generator type exists in input data
        if haskey(gen, "type")
            type = gen["type"]
        else
            print(g, "\n")
        end

        # Calculate zonal capacity: For LU there are three different zones coming from the TYNDP data
        zonal_tyndp_capacity = 0
        if haskey(zone_mapping, zone)
            tyndp_zones = zone_mapping[zone]
        else
            tyndp_zones = Dict{String, Any}()
        end
        for tyndp_zone in tyndp_zones
            # obtain 
            zonal_capacity = get_generation_capacity(tyndp_capacity, scenario, type, climate_year, tyndp_zone)
            if !isempty(zonal_capacity)
                zonal_tyndp_capacity =  zonal_tyndp_capacity + zonal_capacity[1]
            end
        end

        # If the zonal capacity is different than zero, scale "pmax" based on the ratios of the zonal capacities
        if zonal_tyndp_capacity !=0
            for (z, zone_) in grid_data["zonal_generation_capacity"]
                if zone_["zone"] == zone
                    scaling_factor = zone_[type] / (zonal_tyndp_capacity / grid_data["baseMVA"])
                    gen["pmax"] = gen["pmax"] * scaling_factor
                end
            end
        end
                # TODO, check if it is better to put a zero in the else case

        # Check if a different capacity should be written into the offshore wind generator NSEH
        if !isnothing(ns_hub_cap)
            if zone == "NSEH"
                gen["pmax"] = ns_hub_cap
            end
        end
    end 
end

# This function maps the zone names in the EU Grid model to the zone names of the TYNDP model
function map_zones()
    zone_mapping = Dict{String, Any}()
    zone_mapping["AL"] = ["AL00"]
    zone_mapping["AT"] = ["AT00"]
    zone_mapping["BA"] = ["BA00"]
    zone_mapping["BE"] = ["BE00"]
    zone_mapping["BG"] = ["BG00"]
    zone_mapping["CH"] = ["CH00"]
    zone_mapping["CZ"] = ["CZ00"]
    zone_mapping["DE"] = ["DE00"]
    zone_mapping["DE-LU"] = ["LUG1"]
    zone_mapping["DK1"] = ["DKE1", "DEKF"]
    zone_mapping["DK2"] = ["DKW1","DKKF"]
    zone_mapping["ES"] = ["ES00"]
    zone_mapping["FI"] = ["FI00"]
    zone_mapping["FR"] = ["FR00"]
    zone_mapping["GR"] = ["GR00"]
    zone_mapping["HR"] = ["HR00"]
    zone_mapping["HU"] = ["HU00"]
    zone_mapping["IE"] = ["IE00"]
    zone_mapping["IT-NORD"] = ["ITN1"]
    zone_mapping["IT-CNOR"] = ["ITCN"]
    zone_mapping["IT-CSUD"] = ["ITCS"]
    zone_mapping["IT-SUD"] = ["ITS1"]
    zone_mapping["IT-SICI"] = ["ITSI"]
    zone_mapping["LU"] = [ "LUB1", "LUF1", "LUV1"]
    zone_mapping["ME"] = ["ME00"]
    zone_mapping["MK"] = ["MK00"]
    zone_mapping["NL"] =  ["NL00"]
    zone_mapping["NO1"] = ["NOS0"] # NOS1 demand is always 0!
    zone_mapping["NO2"] = ["NOS0"]
    zone_mapping["NO3"] = ["NOM1"]
    zone_mapping["NO4"] = ["NON1"]
    zone_mapping["NO5"] = ["NOM1"] # NO5 not in tyndp model
    zone_mapping["PL"] =  ["PL00"]
    zone_mapping["PT"] =  ["PT00"]
    zone_mapping["RO"] = ["RO00"]
    zone_mapping["RS"] = ["RS00"]
    zone_mapping["SE1"] = ["SE01"]
    zone_mapping["SE2"] = ["SE02"]
    zone_mapping["SE3"] = ["SE03"]
    zone_mapping["SE4"] =  ["SE04"]
    zone_mapping["SI"] = ["SI00"]
    zone_mapping["SK"] =  ["SK00"]
    zone_mapping["UK"] = ["UK00"]
    zone_mapping["NI"] = ["UKNI"]
  # TODO: Check these zones
  "CY00"
  "EE00"
  "FR15"
  "GR03"
  "IL00"
  "IS00"
  "ITCO"
  "ITSA"
  "LT00"
  "LV00"
  "MT00"
  "PLE0"
  "PLI0"
  "TN00"
  "TR00"
  "UA01"
  "UA02"
  return zone_mapping
end


function create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, zone_mapping; zone = nothing)
    if !isnothing(zone)
        zones = [zone]
    else
        zones = [z for (z, zone) in zone_mapping]
    end
    res_demand = Dict{String, Any}(
    "wind_onshore" => Dict{String, Any}(),
    "wind_offshore" => Dict{String, Any}(),
    "solar_pv" => Dict{String, Any}(),
    "demand" => Dict{String, Any}())

    print("creating RES time series for zone:" , "\n")
    for zone in zones
        print(zone, "\n")
        push!(res_demand["wind_onshore"], zone => [])
        push!(res_demand["wind_offshore"], zone => [])
        push!(res_demand["solar_pv"], zone => [])
        push!(res_demand["demand"], zone => [])

        if haskey(zone_mapping, zone)
            tyndp_zone = zone_mapping[zone][1]
        end

        for i in 1:length(wind_onshore[!,1])
            if wind_onshore[!,1][i] == tyndp_zone
                push!(res_demand["wind_onshore"][zone], wind_onshore[!,5][i])
            end
            if wind_offshore[!,1][i] == tyndp_zone
                push!(res_demand["wind_offshore"][zone], wind_offshore[!,5][i])
            end
            if pv[!,1][i] == tyndp_zone
                push!(res_demand["solar_pv"][zone], pv[!,5][i])
            end
            if i <= length(scenario_data[tyndp_zone]["demand"])
                push!(res_demand["demand"][zone], scenario_data[tyndp_zone]["demand"][i] / maximum(scenario_data[tyndp_zone]["demand"]))   
            end
         end
    end

    return res_demand
end


function hourly_grid_data!(grid_data, grid_data_orig, hour, res_demand)
    for (l, load) in grid_data["load"]
        zone = load["zone"]
        load["pd"] =  res_demand["demand"][zone][hour] * grid_data_orig["load"][l]["pd"] 
        # To Do, fix demand response potential!
        # load["pred_rel_max"] = ts_data["load"][l]["pred_rel_max"][1, hour] 
        # load["cost_red"] = ts_data["load"][l]["cost_red"][1, hour] 
        # load["cost_curt"] = ts_data["load"][l]["cost_curt"][1, hour]
    end
    for (g, gen) in grid_data["gen"]
        zone = gen["zone"]
        if gen["type"] == "Wind Onshore"
            gen["pg"] =  res_demand["wind_onshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"] 
            gen["pmax"] =  res_demand["wind_onshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
        elseif gen["type"] == "Wind Offshore"
            gen["pg"] =  res_demand["wind_offshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  res_demand["wind_offshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        elseif gen["type"] == "Solar PV"
            gen["pg"] =  res_demand["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  res_demand["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        end
    end
    return grid_data
end

