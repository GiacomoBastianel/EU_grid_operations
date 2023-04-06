function isolate_zones(grid_data, zones)
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
    for zone in zones
        for (b, bus) in grid_data["bus"]
            if haskey(bus, "zone") && bus["zone"] == zone
                zone_data["bus"][b] = bus
            end
        end
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
            if (haskey(grid_data["bus"]["$f_bus"], "zone") && grid_data["bus"]["$f_bus"]["zone"]  == zone) || (haskey(grid_data["bus"]["$t_bus"], "zone") && grid_data["bus"]["$t_bus"]["zone"] == zone)
                zone_data["branch"][b] = branch
            end
            # To Do, check also for xb lines
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
        add_borders!(zone_data, grid_data, zone)
    end


    
    return zone_data
end


function add_borders!(zone_data, grid_data, zone)
    zone_data["borders"] = Dict{String, Any}()
    borders = []
    
    for (b, branch) in zone_data["branch"]
        if branch["interconnector"] == true
            f_bus = branch["f_bus"]
            t_bus = branch["t_bus"]
            border_buses = [grid_data["bus"]["$f_bus"]["zone"]  !== zone, grid_data["bus"]["$t_bus"]["zone"]  !== zone]
            if findall(border_buses) == 1
               border_bus = grid_data["bus"]["$f_bus"]   
            else
               border_bus = grid_data["bus"]["$t_bus"]
            end
            xb_zone = find_xb_zone(grid_data, border_bus, zone)
            if !isempty(xb_zone)
                if !any(xb_zone .== borders)
                    push!(borders, xb_zone)
                    idx = length(zone_data["borders"]) + 1
                    zone_data["borders"]["$idx"] = Dict{String, Any}()
                    zone_data["borders"]["$idx"]["name"] = xb_zone
                    zone_data["borders"]["$idx"]["xb_lines"] = Dict{String, Any}()
                    zone_data["borders"]["$idx"]["xb_convs"] = Dict{String, Any}()
                end
                idx = findfirst(xb_zone .== borders)
                zone_data["borders"]["$idx"]["xb_lines"][b] = branch
                b_idx = border_bus["index"]
                zone_data["bus"]["$b_idx"] = border_bus
                add_border_gen!(zone_data, border_bus, xb_zone)
            end
        end
    end

    for (b, branchdc) in zone_data["branchdc"]
        f_bus = branchdc["fbusdc"]
        t_bus = branchdc["tbusdc"]
        if !(any("$f_bus" .== keys(zone_data["busdc"])) && any("$t_bus" .== keys(zone_data["busdc"])))
            if  !any("$f_bus" .== keys(zone_data["busdc"]))
                conv_bus = f_bus
            elseif  !any("$t_bus" .== keys(zone_data["busdc"]))
                conv_bus = t_bus
            end
            for (c, convdc) in grid_data["convdc"]
                if convdc["busdc_i"] == conv_bus
                    ac_bus = convdc["busac_i"]
                    xb_zone = grid_data["bus"]["$ac_bus"]["zone"]
                    if !any(xb_zone .== borders)
                        push!(borders, xb_zone)
                        idx = length(zone_data["borders"]) + 1
                        zone_data["borders"]["$idx"] = Dict{String, Any}()
                        zone_data["borders"]["$idx"]["name"] = xb_zone
                        zone_data["borders"]["$idx"]["xb_lines"] = Dict{String, Any}()
                        zone_data["borders"]["$idx"]["xb_convs"] = Dict{String, Any}()
                    end
                    idx = findfirst(xb_zone .== borders)
                    zone_data["borders"]["$idx"]["xb_convs"][c] = convdc
                    zone_data["bus"]["$ac_bus"] = grid_data["bus"]["$ac_bus"]
                    add_border_gen!(zone_data, ac_bus, xb_zone)
                end
            end
        end
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

function add_border_gen!(zone_data, border_bus, border_zone)

    number_of_gens = maximum([gen["index"] for (g, gen) in zone_data["gen"]])
    idx = number_of_gens + 1

    zone_data["gen"]["$idx"] = Dict{String, Any}()
    zone_data["gen"]["$idx"]["index"] = idx 
    zone_data["gen"]["$idx"]["country"] = border_zone
    zone_data["gen"]["$idx"]["zone"] = border_zone
    zone_data["gen"]["$idx"]["gen_bus"] = border_bus #gen_hydro_ror_dict[:,5][i]
    zone_data["gen"]["$idx"]["type"] = "XB_dummy"
    zone_data["gen"]["$idx"]["type_tyndp"] = "XB_dummy"
    zone_data["gen"]["$idx"]["pmax"] = 5000 / zone_data["baseMVA"] #gen_hydro_ror_dict[:,6][i]/zone_data["baseMVA"] 
    zone_data["gen"]["$idx"]["pmin"] = -5000 / zone_data["baseMVA"]
    zone_data["gen"]["$idx"]["qmax"] =  zone_data["gen"]["$idx"]["pmax"] * 0.5
    zone_data["gen"]["$idx"]["qmin"] = -zone_data["gen"]["$idx"]["pmax"] * 0.5
    zone_data["gen"]["$idx"]["cost"] = [25.0  * zone_data["baseMVA"], 0.0] # Assumption here, to be checked
    zone_data["gen"]["$idx"]["ncost"] = 2
    zone_data["gen"]["$idx"]["model"] = 2
    zone_data["gen"]["$idx"]["gen_status"] = 1
    zone_data["gen"]["$idx"]["vg"] = 1.0
    zone_data["gen"]["$idx"]["source_id"] = []
    push!(zone_data["gen"]["$idx"]["source_id"],"gen")
    push!(zone_data["gen"]["$idx"]["source_id"], idx)

    return zone_data
end


function find_xb_zone(grid_data, xb_bus, zone)
    xb_zone = ""
    for (b, branch) in grid_data["branch"]
        if branch["interconnector"] == true
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
    end
    
    return xb_zone
end

# f_bus = branch["f_bus"]
# t_bus = branch["t_bus"]
# print((f_bus, t_bus), "\n")
# border_buses = [grid_data["bus"]["$f_bus"]["zone"]  !== zones, grid_data["bus"]["$t_bus"]["zone"]  !== zones]
# if !isempty(border_buses)
#     if findall(border_buses) == 1
#         border_bus = f_bus   
#     else
#         border_bus = t_bus
#     end
#     border_zone = grid_data["bus"]["$border_bus"]["zone"]
#     if !any(border_zone .== borders)
#         add_border!(zone_data, borders, grid_data, border_bus)
#     end
#     for (bo, border) in zone_data["borders"]
#         if border["name"] == border_zone
#             number_of_lines = length(border["xb_lines"])
#             l_idx = number_of_lines + 1
#             border["xb_lines"]["$l_idx"] = branch
#         end
#     end
#     zone_data["bus"]["$border_bus"] = grid_data["bus"]["$border_bus"]
#     add_border_gen!(zone_data, border_bus, border_zone)
# end