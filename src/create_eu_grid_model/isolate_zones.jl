function isolate_zones(grid_data, zones; border_slack = 0)
    zone_data = Dict{String, Any}()
    zone_data["zones"] = zones
    zone_data["dcpol"] = grid_data["dcpol"]
    zone_data["name"] = "Reduced Grid"
    zone_data["baseMVA"] = grid_data["baseMVA"]
    zone_data["per_unit"] = grid_data["per_unit"]
    zone_data["bus"] = Dict{String, Any}()
    zone_data["gen"] = Dict{String, Any}()
    zone_data["load"] = Dict{String, Any}()
    zone_data["branch"] = Dict{String, Any}()
    zone_data["storage"] = Dict{String, Any}()
    zone_data["convdc"] = Dict{String, Any}()
    zone_data["branchdc"] = Dict{String, Any}()
    zone_data["busdc"] = Dict{String, Any}()
    zone_data["pst"] = Dict{String, Any}()
    zone_data["shunt"] = Dict{String, Any}()
    zone_data["switch"] = Dict{String, Any}()
    zone_data["dcline"] = Dict{String, Any}()
    zone_data["zonal_peak_demand"] = 0

    # first add all buses to the actual zones
    for zone in zones
        for (b, bus) in grid_data["bus"]
            if haskey(bus, "zone") && bus["zone"] == zone
                zone_data["bus"][b] = bus
            end
        end
    end
    for zone in zones
        # then find all XB nodes and assign them to the first zone of ones in the list
        for (br, branch) in grid_data["branch"]
            # Only interested in interconnectors
            if branch["interconnector"] == true
                fbus_id = branch["f_bus"]
                tbus_id = branch["t_bus"]
                # check if the from bus belongs to the actual zone
                if haskey(grid_data["bus"]["$fbus_id"], "zone") && grid_data["bus"]["$fbus_id"]["zone"] == zone
                    # check here if the XB bus is already assigned to a zone -> this can happen when merging two neighbouring zones, we don;t want to double count!
                    if !haskey(zone_data["bus"],"$tbus_id") && haskey(grid_data["bus"]["$tbus_id"],"zone") &&  grid_data["bus"]["$tbus_id"]["zone"]  == "XB_node"
                        println("XB_node ", tbus_id, " assinged to zone ", zone)
                        zone_data["bus"]["$tbus_id"]= deepcopy(grid_data["bus"]["$tbus_id"])
                        zone_data["bus"]["$tbus_id"]["zone"] = zone
                    end
                end
                # check ifthe to bus belongs to the actual zone
                if haskey(grid_data["bus"]["$tbus_id"], "zone") && grid_data["bus"]["$tbus_id"]["zone"] == zone
                    # check here if the XB bus is already assigned to a zone -> this can happen when merging two neighbouring zones, we don;t want to double count!
                    if !haskey(zone_data["bus"],"$fbus_id") && haskey(grid_data["bus"]["$fbus_id"],"zone") &&  grid_data["bus"]["$fbus_id"]["zone"]  == "XB_node" 
                        println("XB_node ", fbus_id, " assinged to zone ", zone)
                        zone_data["bus"]["$fbus_id"] = deepcopy(grid_data["bus"]["$fbus_id"])
                        zone_data["bus"]["$fbus_id"]["zone"] = zone
                    end
                end
            end
        end
    end

    for zone in zones
        for (g, gen) in grid_data["gen"]
            if haskey(gen, "zone") && gen["zone"] == zone
                zone_data["gen"][g] = gen
            end
        end

        for (l, load) in grid_data["load"]
            if haskey(load, "zone") && load["zone"] == zone
                zone_data["load"][l] = load
            end
        end

        for (s, storage) in grid_data["storage"]
            if haskey(storage, "zone") && storage["zone"] == zone
                zone_data["storage"][s] = storage
            end
        end

        for (b, branch) in grid_data["branch"]
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            # Add any branch that has either the from or the to node connected to the isolated grid
            if (haskey(zone_data["bus"], "$f_bus") && zone_data["bus"]["$f_bus"]["zone"]  == zone) || (haskey(zone_data["bus"], "$t_bus") && zone_data["bus"]["$t_bus"]["zone"] == zone)
                zone_data["branch"][b] = branch
            end
        end

        for (c, conv) in grid_data["convdc"]
            bus_ac = conv["busac_i"]
            bus_dc = conv["busdc_i"]
            if (haskey(grid_data["bus"]["$bus_ac"], "zone") && grid_data["bus"]["$bus_ac"]["zone"]  == zone) 
                zone_data["convdc"][c] = conv
                zone_data["busdc"]["$bus_dc"] = grid_data["busdc"]["$bus_dc"]
            end
        end

        for (b, branch) in grid_data["branchdc"]
            f_bus = branch["fbusdc"]
            t_bus = branch["tbusdc"]
            if haskey(zone_data["busdc"], "$f_bus") || haskey(zone_data["busdc"], "$t_bus")
                zone_data["branchdc"][b] = branch
            end
        end
    end
    add_borders!(zone_data, grid_data, zones; border_slack = border_slack)

    return zone_data
end


# This function is to add remaining XB lines, converters etc. to the system
function add_borders!(zone_data, grid_data, zones; border_slack = 0)
    zone_data["borders"] = Dict{String, Any}()
    borders = []
    for zone in zones
        for (b, branch) in zone_data["branch"]
            if branch["interconnector"] == true
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            border_buses = [0 0]
                # As we already processed the interconnectors connected to XB nodes, we only want to have the ones that come from the neighboring zone to the XB node.  
                if haskey(zone_data["bus"], "$f_bus") && !haskey(zone_data["bus"], "$t_bus")
                    border_buses = [0, grid_data["bus"]["$t_bus"]["zone"]  !== zone]
                end
                if haskey(zone_data["bus"], "$t_bus") && !haskey(zone_data["bus"], "$f_bus")
                    border_buses = [grid_data["bus"]["$f_bus"]["zone"]  !== zone, 0]
                end
                border_bus = Dict()
                if border_buses[1] == 1
                    border_bus = grid_data["bus"]["$f_bus"]
                    branch["direction"] = "to"
                    xb_zone =grid_data["bus"]["$f_bus"]["zone"]   
                elseif border_buses[2] == 1
                    border_bus = grid_data["bus"]["$t_bus"]
                    branch["direction"] = "from" 
                    xb_zone = grid_data["bus"]["$f_bus"]["zone"]
                else
                    xb_zone = ""
                end
                if !isempty(xb_zone)
                    if !any(xb_zone .== zones)
                        if !any(xb_zone .== borders)
                            push!(borders, xb_zone)
                            idx = length(zone_data["borders"]) + 1
                            zone_data["borders"]["$idx"] = Dict{String, Any}()
                            zone_data["borders"]["$idx"]["name"] = xb_zone
                            zone_data["borders"]["$idx"]["xb_lines"] = Dict{String, Any}()
                            zone_data["borders"]["$idx"]["xb_convs"] = Dict{String, Any}()
                            zone_data["borders"]["$idx"]["slack"] = border_slack
                        end
                        idx = findfirst(xb_zone .== borders)
                        zone_data["borders"]["$idx"]["xb_lines"][b] = branch
                        b_idx = border_bus["index"]
                        zone_data["bus"]["$b_idx"] = border_bus
                        add_border_gen!(zone_data, b_idx, xb_zone)
                    end
                end
            end
        end

        for (b, branchdc) in zone_data["branchdc"]
            f_bus = branchdc["fbusdc"]
            t_bus = branchdc["tbusdc"]
            if !(any("$f_bus" .== keys(zone_data["busdc"])) && any("$t_bus" .== keys(zone_data["busdc"])))
                if  !any("$f_bus" .== keys(zone_data["busdc"]))
                    conv_bus = f_bus
                elseif !any("$t_bus" .== keys(zone_data["busdc"]))
                    conv_bus = t_bus
                end
                for (c, convdc) in grid_data["convdc"]
                    if convdc["busdc_i"] == conv_bus
                        push!(zone_data["convdc"], c => deepcopy(convdc))
                        push!(zone_data["busdc"], "$conv_bus" => grid_data["busdc"]["$conv_bus"])
                        ac_bus = convdc["busac_i"]
                        xb_zone = grid_data["bus"]["$ac_bus"]["zone"]
                        if !any(xb_zone .== zones)
                            if !any(xb_zone .== borders)
                                push!(borders, xb_zone)
                                idx = length(zone_data["borders"]) + 1
                                zone_data["borders"]["$idx"] = Dict{String, Any}()
                                zone_data["borders"]["$idx"]["name"] = xb_zone
                                zone_data["borders"]["$idx"]["xb_lines"] = Dict{String, Any}()
                                zone_data["borders"]["$idx"]["xb_convs"] = Dict{String, Any}()
                                zone_data["borders"]["$idx"]["slack"] = border_slack
                            end
                            idx = findfirst(xb_zone .== borders)
                            zone_data["borders"]["$idx"]["xb_convs"][c] = convdc
                            zone_data["bus"]["$ac_bus"] = grid_data["bus"]["$ac_bus"]
                            add_border_gen!(zone_data, ac_bus, xb_zone)
                        end
                    end
                end
            end
        end
    end
    for (bo, border) in zone_data["borders"]
        border_cap = 0
        for (b, branch) in border["xb_lines"]
            border_cap = border_cap + branch["rate_a"]
        end
        for (c, conv) in border["xb_convs"]
            border_cap = border_cap + conv["Pacmax"]
        end
        border["border_cap"] = border_cap
    end

    return zone_data

end



function add_border!(zone_data, borders, grid_data, border_bus)
    push!(borders, grid_data["bus"]["$border_bus"]["zone"])
    idx = length(zone_data["borders"]) + 1
    zone_data["borders"]["$idx"] = Dict{String, Any}()
    zone_data["borders"]["$idx"]["name"] = grid_data["bus"]["$border_bus"]["zone"]
    zone_data["borders"]["$idx"]["xb_lines"] = Dict{String, Any}()
    zone_data["borders"]["$idx"]["xb_nodes"] = Dict{String, Any}()
    zone_data["borders"]["$idx"]["xb_convs"] = Dict{String, Any}()

    return zone_data
end

function add_border_gen!(zone_data, border_bus, border_zone; use_regions = false)

    number_of_gens = maximum([gen["index"] for (g, gen) in zone_data["gen"]])
    idx = number_of_gens + 1

    zone_data["gen"]["$idx"] = Dict{String, Any}()
    zone_data["gen"]["$idx"]["index"] = idx 
    zone_data["gen"]["$idx"]["country"] = border_zone
    zone_data["gen"]["$idx"]["zone"] = border_zone
    zone_data["gen"]["$idx"]["gen_bus"] = border_bus 
    zone_data["gen"]["$idx"]["type"] = "XB_dummy"
    zone_data["gen"]["$idx"]["type_tyndp"] = "XB_dummy"
    zone_data["gen"]["$idx"]["pmax"] = 7000 / zone_data["baseMVA"] 
    zone_data["gen"]["$idx"]["pmin"] = -7000 / zone_data["baseMVA"]
    zone_data["gen"]["$idx"]["qmax"] =  zone_data["gen"]["$idx"]["pmax"] * 0.5
    zone_data["gen"]["$idx"]["qmin"] = -zone_data["gen"]["$idx"]["pmax"] * 0.5
    zone_data["gen"]["$idx"]["cost"] = [25.0  * zone_data["baseMVA"], 0.0] # Assumption here, to be checked
    zone_data["gen"]["$idx"]["ncost"] = 2
    zone_data["gen"]["$idx"]["model"] = 2
    zone_data["gen"]["$idx"]["gen_status"] = 1
    zone_data["gen"]["$idx"]["vg"] = 1.0
    zone_data["gen"]["$idx"]["source_id"] = []
    if use_regions == true
        zone_data["gen"]["$idx"]["region"] = border_zone
    end
    push!(zone_data["gen"]["$idx"]["source_id"],"gen")
    push!(zone_data["gen"]["$idx"]["source_id"], idx)

    return zone_data
end


function find_xb_zone(grid_data, xb_bus, zone)
    xb_zone = ""
    for (b, branch) in grid_data["branch"]
        if branch["f_bus"] == xb_bus["index"] || branch["t_bus"] == xb_bus["index"]
            if branch["f_bus"] == xb_bus["index"]
                t_bus = branch["t_bus"] 
                if grid_data["bus"]["$t_bus"]["zone"] !== zone
                    xb_zone = grid_data["bus"]["$t_bus"]["zone"]
                end 
            end
            if branch["t_bus"] == xb_bus["index"]
                f_bus = branch["f_bus"] 
                if grid_data["bus"]["$f_bus"]["zone"] !== zone
                    xb_zone = grid_data["bus"]["$f_bus"]["zone"]
                end 
            end
        end
    end
    
    return xb_zone
end