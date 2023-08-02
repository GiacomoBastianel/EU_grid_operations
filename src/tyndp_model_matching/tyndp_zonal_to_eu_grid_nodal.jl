# This function scales the "pmax" value of each generator based on the installed total capacity coming from the TYNDP data. 
# tyndp_capacity ::DataFrame - The installed generation capacity coming from the zonal model, per zone and generation type, climate year and scenario
# grid_data ::Dict{String, Any} - EU grid model
# scneario ::String - Name of the scenario, e.g. "GA2030"
# climate_year ::String - Climate year e.g. "2007"
# zone_mapping ::Dict{String, Any} - Dictionary containing the mapping of zone names between both models
# ns_hub_cap ::Float64 - Capacity of the North Sea energy hub as optional keyword argument. Default value coming from the grid model is 10 GW.
function scale_generation!(tyndp_capacity, grid_data, scenario, climate_year, zone_mapping; ns_hub_cap = nothing, exclude_offshore_wind = false)
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
                    scaling_factor = max(1, (zonal_tyndp_capacity / grid_data["baseMVA"] / zone_[type]) )
                    if !exclude_offshore_wind
                        if gen["type"] != "Offshore Wind"
                            gen["pmax"] = gen["pmax"] * scaling_factor
                        end
                    else
                        gen["pmax"] = gen["pmax"] * scaling_factor
                    end
                end
            end
        end

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


function create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping; zone = nothing)
    if !isnothing(zone)
        zones = [zone]
    else
        zones = [z for (z, zone) in zone_mapping]
    end
    timeseries_data = Dict{String, Any}(
    "wind_onshore" => Dict{String, Any}(),
    "wind_offshore" => Dict{String, Any}(),
    "solar_pv" => Dict{String, Any}(),
    "demand" => Dict{String, Any}(),
    "max_demand" => Dict{String, Any}())

    print("creating RES time series for zone:" , "\n")
    for zone in zones
        print(zone, "\n")
        push!(timeseries_data["wind_onshore"], zone => [])
        push!(timeseries_data["wind_offshore"], zone => [])
        push!(timeseries_data["solar_pv"], zone => [])
        push!(timeseries_data["demand"], zone => [])
        push!(timeseries_data["max_demand"], zone => [])

        if haskey(zone_mapping, zone)
            tyndp_zone = zone_mapping[zone][1]
        end


        wind_series_onshore = wind_onshore[wind_onshore[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["wind_onshore"][zone] = wind_series_onshore

        wind_series_offshore = wind_offshore[wind_offshore[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["wind_offshore"][zone] = wind_series_offshore

        pv_series = pv[pv[!, "area"] .== tyndp_zone, climate_year]
        timeseries_data["solar_pv"][zone] = pv_series

        for i in 1:length(wind_onshore[!,1])
            if i <= length(scenario_data[tyndp_zone]["demand"])
                push!(timeseries_data["demand"][zone], scenario_data[tyndp_zone]["demand"][i] / maximum(scenario_data[tyndp_zone]["demand"]))   
            end
         end
         timeseries_data["max_demand"][zone] = maximum(scenario_data[tyndp_zone]["demand"])
    end

    return timeseries_data
end


function hourly_grid_data!(grid_data, grid_data_orig, hour, timeseries_data)
    for (l, load) in grid_data["load"]
        zone = load["zone"]
        ratio = (timeseries_data["max_demand"][zone] / grid_data["baseMVA"]) / load["country_peak_load"]
        load["pd"] =  timeseries_data["demand"][zone][hour] * grid_data_orig["load"][l]["pd"] * ratio
    end
    for (g, gen) in grid_data["gen"]
        zone = gen["zone"]
        if gen["type_tyndp"] == "Onshore Wind"
            gen["pg"] =  timeseries_data["wind_onshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"] 
            gen["pmax"] =  timeseries_data["wind_onshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
        elseif gen["type_tyndp"] == "Offshore Wind"
            gen["pg"] =  timeseries_data["wind_offshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  timeseries_data["wind_offshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        elseif gen["type_tyndp"] == "Solar PV"
            gen["pg"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  timeseries_data["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        end
    end
    for (b, border) in grid_data["borders"]
        flow = timeseries_data["xb_flows"][border["name"]]["flow"][1, hour]
        if abs(flow) > border["border_cap"]
            border["flow"] = sign(flow) * border["border_cap"] * 0.95  # to avoid numerical infeasibility & compensate for possible HVDC losses
        else
            border["flow"] = flow
        end
    end
    return grid_data
end


function get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)
    zone = zone_grid["zones"][1]
    borders = Dict{String, Any}()
    for (b, border) in zone_grid["borders"]
        borders[border["name"]] = Dict{String, Any}("flow" => zeros(1, length(zonal_result)))
        if haskey(zone_mapping, border["name"])
            tyndp_zone_fr = zone_mapping[zone][1]
            tyndp_zone_to = zone_mapping[border["name"]][1]
        
            int_name_fr = join([tyndp_zone_fr,"-",tyndp_zone_to])
            int_name_to = join([tyndp_zone_to,"-",tyndp_zone_fr])
            flow = 0
            for (r, res) in zonal_result
                for (b, branch) in zonal_input["branch"]
                    if branch["name"] == int_name_fr
                        flow = res["solution"]["branch"][b]["pf"]
                    elseif branch["name"] == int_name_to
                        flow = res["solution"]["branch"][b]["pt"]
                    end
                end
                borders[border["name"]]["flow"][1, parse(Int, r)] = flow
            end   
        end
     end
     return borders
end

function get_demand_reponse!(zone_grid, zonal_input, zone_mapping, timeseries_data; cost = 140)
    zone = zone_grid["zones"][1]
    tyndp_zone = zone_mapping[zone][1]
    dr_ratio = 0
    for (g, gen) in zonal_input["gen"]
        if gen["node"] == tyndp_zone && gen["type"] == "DSR"
            dr_ratio = gen["pmax"] / (timeseries_data["max_demand"][zone] / zone_grid["baseMVA"])
        end
    end
    for (l, load) in zone_grid["load"]
        load["pred_rel_max"] = dr_ratio
        load["cost_red"] = cost * zone_grid["baseMVA"] 
    end
    return zone_grid
end

function fix_data!(grid_data)

    for (b, branch) in grid_data["branch"]
        b_b = imag(1 / (branch["br_r"] + branch["br_x"]im))
        theta_max = branch["rate_a"] / b_b
        if theta_max > pi || theta_max < -pi
            print("Updating rate_a of branch ", b, " due to high reactance.", "\n")
            branch["rate_a"] = abs(pi * b_b)
        end
    end

    return grid_data
end

function add_north_sea_wind_zonal!(input_data, nodal_data, power; branch_cap = 0)
    # first remove OWF capacity of the existing model for the particular zones
    for (g, gen) in input_data["gen"]
        if gen["type"] == "Offshore Wind"
            gen_bus = gen["gen_bus"]
            if any(input_data["bus"]["$gen_bus"]["string"] .== ["FR00", "UK00", "BE00", "NL00", "DE00", "NOS0","SE03", "DKW1"]) == true
                gen["pmax"] = 0.0
                gen["gen_status"] = 0
            end
        end
    end
    bus_id_ = maximum(parse.(Int, collect(keys(input_data["bus"]))))
    bus_id = maximum(parse.(Int, collect(keys(input_data["bus"])))) + 1
    input_data["bus"]["$bus_id"] = deepcopy(input_data["bus"]["$bus_id_"])
    input_data["bus"]["$bus_id"]["lat"] = 54.990994
    input_data["bus"]["$bus_id"]["lon"] = 3.279410
    input_data["bus"]["$bus_id"]["string"] = "NSOW"
    input_data["bus"]["$bus_id"]["source_id"] = ["bus", bus_id]
    input_data["bus"]["$bus_id"]["index"] = input_data["bus"]["$bus_id"]["number"] = bus_id

    gen_id_ = maximum(parse.(Int, collect(keys(input_data["gen"]))))
    gen_id = maximum(parse.(Int, collect(keys(input_data["gen"])))) + 1
    input_data["gen"]["$gen_id"] = deepcopy(input_data["gen"]["$gen_id_"])
    input_data["gen"]["$gen_id"]["source_id"] = ["gen", gen_id]
    input_data["gen"]["$gen_id"]["index"] = gen_id
    input_data["gen"]["$gen_id"]["gen_bus"] = bus_id
    input_data["gen"]["$gen_id"]["pmax"] = power / input_data["baseMVA"]
    input_data["gen"]["$gen_id"]["type"] = "Offshore Wind"
    input_data["gen"]["$gen_id"]["node"] = "NSOW"
    input_data["gen"]["$gen_id"]["cost"] = [0.0 3500.0 0.0]

    add_ns_branches!(input_data; branch_cap = branch_cap)

    nodal_data["NSOW"] = Dict{String, Any}("generation" => Dict("Offshore Wind" => Dict("timeseries" => [], "capacity" => (power))), "demand" => zeros(size(nodal_data["UK00"]["demand"])))
    nodal_data["NSOW"]["generation"]["Offshore Wind"]["timeseries"]= nodal_data["UK00"]["generation"]["Offshore Wind"]["timeseries"] ./ maximum(nodal_data["UK00"]["generation"]["Offshore Wind"]["timeseries"]) * power


    return input_data, nodal_data
end


function add_ns_branches!(input_data; branch_cap = 0)
    for zone in ["FR00", "UK00", "BE00", "NL00", "DE00", "NOS0","SE03", "DKW1"]
        branch_id_ = maximum(parse.(Int, collect(keys(input_data["branch"]))))
        branch_id = maximum(parse.(Int, collect(keys(input_data["branch"])))) + 1
        input_data["branch"]["$branch_id"] = deepcopy(input_data["branch"]["$branch_id_"])
        input_data["branch"]["$branch_id"]["index"] =  input_data["branch"]["$branch_id"]["number_id"] = branch_id
        input_data["branch"]["$branch_id"]["source_id"] = ["branch", branch_id]  
        input_data["branch"]["$branch_id"]["rate_a"] = input_data["branch"]["$branch_id"]["rate_i"] = input_data["branch"]["$branch_id"]["rate_p"] = branch_cap / input_data["baseMVA"]
        input_data["branch"]["$branch_id"]["delta_cap_max"]  = 1000.0
        input_data["branch"]["$branch_id"]["name"] = join(zone, "-NSOW")
        for (b, bus) in input_data["bus"]
            if bus["string"] == zone
                input_data["branch"]["$branch_id"]["f_bus"] = parse(Int, b)
            elseif bus["string"] == "NSOW"
                input_data["branch"]["$branch_id"]["t_bus"] = parse(Int, b)
            end
        end
        input_data["branch"]["$branch_id"]["offshore"] = true
    end

    return input_data
end


function branch_capacity_cost!(input_data)
    for (b, branch) in input_data["branch"]
        distance = latlon2distance(input_data, branch)
        if haskey(branch, "offshore") && branch["offshore"] == true
            # Assumption: 2M€ per km for 2 GW + 700 M€ for converter costs for 2 GW           
            branch["capacity_cost"] = ((1000.0 * distance + 3.5e5) / (25 * 8760)) * input_data["baseMVA"]

        else
            branch["delta_cap_max"] = branch["rate_a"] * 2 # Allow to double capacity
            # Assumption: 5M€ per km for 3 GVA
            # -> 167 k€ / km / (100 MVA)
            branch["capacity_cost"] = 167e5 * distance / (25 * 8760) 
        end
    end
end

function scale_costs!(input_data, hours)
    for (g, gen) in input_data["gen"]
        gen["cost"] = gen["cost"] .* 8760 / length(hours)
    end

    for (b, branch) in input_data["branch"]
        branch["capacity_cost"] = branch["capacity_cost"] .* 8760 / length(hours)
    end

    return input_data
end

function add_offshore_wind_farms!(input_data)
    xf = XLSX.readxlsx(joinpath("./data_sources/offshore_wind_farms.xlsx"))
    XLSX.sheetnames(xf)
    for r in XLSX.eachrow(xf["OWFHUBS"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            zone = r[1]
            rating = r[2]
            lat = r[3]
            lon = r[4]
            cost = 0 * input_data["baseMVA"]
            add_bus!(input_data, zone, lat, lon)
            node = maximum([bus["index"] for (b, bus) in input_data["bus"]])
            print(zone, "\n")
            add_gen!(input_data, zone, cost, node, rating, "Offshore Wind")
        end
    end

    return input_data
end

function add_offshore_wind_connections!(input_data)
    dc_voltage = 525
    for (g, gen) in input_data["gen"]
        if haskey(gen, "name") && gen["name"] == "OWFHUB"
            ow_bus = gen["gen_bus"]
            ow_zone = gen["zone"]
            distance = 5000
            onshore_bus = 0
            for (b, bus) in input_data["bus"]
                if bus["zone"] == ow_zone && bus["name"] != "OWFHUB"
                    d = latlon2distance(input_data, ow_bus, parse(Int, b))
                    if d <= distance
                        onshore_bus = parse(Int, b)
                        distance = d
                    end
                end
            end

            # Add offshore dc bus:
            input_data, dc_bus_idx_ow = add_dc_bus!(input_data, dc_voltage; lat = input_data["bus"]["$ow_bus"]["lat"], lon = input_data["bus"]["$ow_bus"]["lon"])
            # Add offshore converter:    
            add_converter!(input_data, ow_bus, dc_bus_idx_ow, gen["pmax"])
            # Add onshore dc bus:
            input_data, dc_bus_idx_on = add_dc_bus!(input_data, dc_voltage; lat = input_data["bus"]["$onshore_bus"]["lat"], lon = input_data["bus"]["$onshore_bus"]["lon"])
            # Add onshore converter:
            add_converter!(input_data, onshore_bus, dc_bus_idx_on, gen["pmax"])
            # Add offshore cable:
            add_dc_branch!(input_data, dc_bus_idx_ow, dc_bus_idx_on, gen["pmax"])
        end
    end

    return input_data
end