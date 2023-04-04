function isolate_zones(grid_data, zones)
    zone_data = Dict{String, Any}()
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
                
            end
        end
    end
    
    return zone_data
end