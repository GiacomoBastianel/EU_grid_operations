#####################################
# data.jl
# Author: Hakan Ergun 24.03.2022
# Functions make PowerModels dictionary from input data DataFrames
# and writing hour time series data into data dictionary to update
# hourly RES generation and demand values
#######################################

function construct_data_dictionary(ntcs, capacity, nodes, demand, scenario, climate_year, gen_types, pv, wind_onshore, wind_offshore, gen_costs, emission_factor, inertia_constants, node_positions)

    data = Dict{String, Any}()
    nodal_data = Dict{String, Any}()
    data["bus"] = Dict{String, Any}()
    data["gen"] = Dict{String, Any}()
    data["branch"] = Dict{String, Any}()
    data["load"] = Dict{String, Any}()
    data["dcline"] = Dict{String, Any}()
    data["storage"] = Dict{String, Any}()
    data["switch"] = Dict{String, Any}()
    data["areas"] = Dict{String, Any}()
    data["shunt"] = Dict{String, Any}()
    data["source_version"] = "2"
    data["name"] = "TYNDPzonal"
    data["baseMVA"] = 100.0
    data["per_unit"] = true
    
    global g_idx = 1
    
    print("######################################", "\n")
    print("PROCESSING ZONAL GENERATION AND DEMAND", "\n")
    print("######################################", "\n")
    
    for n in 1:size(nodes, 1)
        node_id = nodes.node_id[n]
        print(node_id, "\n")
        nodal_data[node_id] = Dict{String, Any}()
        nodal_data[node_id]["index"] = n
        nodal_data[node_id]["demand"] = [get_demand_data(demand, node_id, hour) for hour in 1:8760]
        nodal_data[node_id]["generation"] = Dict{String, Any}()
    
        for g in gen_types
            nodal_data[node_id]["generation"][g] = Dict{String, Any}()
            nodal_data[node_id]["generation"][g]["capacity"] = get_generation_capacity(capacity, scenario, g, climate_year, node_id)
    
            if g == "Solar PV" 
                pv_series = pv[pv[!, "area"] .== node_id, climate_year]
                if !any(pv_series .=== missing) && !isempty(nodal_data[node_id]["generation"][g]["capacity"])
                    nodal_data[node_id]["generation"][g]["timeseries"] =  pv_series .* nodal_data[node_id]["generation"][g]["capacity"]
                else
                    nodal_data[node_id]["generation"][g]["timeseries"] = zeros(1, 8760)
                end
            elseif g == "Onshore Wind"
                wind_series = wind_onshore[wind_onshore[!, "area"] .== node_id, climate_year]
                if  !any(wind_series .=== missing) && !isempty(nodal_data[node_id]["generation"][g]["capacity"])
                    nodal_data[node_id]["generation"][g]["timeseries"] =  wind_series .* nodal_data[node_id]["generation"][g]["capacity"]
                else
                    nodal_data[node_id]["generation"][g]["timeseries"] = zeros(1, 8760)
                end
            elseif g == "Offshore Wind"
                wind_series =  wind_offshore[wind_offshore[!, "area"] .== node_id, climate_year]
                if  !any(wind_series .=== missing) && !isempty(nodal_data[node_id]["generation"][g]["capacity"])
                    nodal_data[node_id]["generation"][g]["timeseries"] = wind_series .* nodal_data[node_id]["generation"][g]["capacity"]
                else
                    nodal_data[node_id]["generation"][g]["timeseries"] = zeros(1, 8760)
                end
            end
    
            add_gen!(data, g_idx, g, gen_costs, emission_factor, inertia_constants, n, nodal_data, node_id; ens = false)
            g_idx = g_idx + 1
        end
    
        # Add one ENS generator to each node with cost = VOLL
        add_gen!(data, g_idx, "ENS", gen_costs, emission_factor, inertia_constants, n, nodal_data, node_id; ens = true)
        g_idx = g_idx + 1    
    
        #write bus data
        add_bus!(data, n, node_id, nodes)
    
        #write load data
        add_load!(data, n, nodal_data, node_id)
    end
    
    # write branch data
    for b in 1:size(ntcs, 1)
        add_branch!(data, ntcs, b, nodal_data)
    end
    
    return data, nodal_data
end
    
    
function prepare_hourly_data!(data, nodal_data, hour)    
    for (l, load) in data["load"]
        node = load["node"]
        load["pd"] = nodal_data[node]["demand"][hour] / data["baseMVA"]
    end

    for (g, gen) in data["gen"]
        node = gen["node"]
        if gen["type"] == "Solar PV"
            gen["pmax"] = nodal_data[node]["generation"]["Solar PV"]["timeseries"][hour] / data["baseMVA"]
        elseif gen["type"] == "Onshore Wind"
            gen["pmax"] = nodal_data[node]["generation"]["Onshore Wind"]["timeseries"][hour] / data["baseMVA"]
        elseif gen["type"] == "Offshore Wind"
            gen["pmax"] = nodal_data[node]["generation"]["Offshore Wind"]["timeseries"][hour] / data["baseMVA"]
        elseif gen["type"] == "ENS"
            gen["pmax"] = nodal_data[node]["demand"][hour] / data["baseMVA"]
        end
    end

    return data
end
    
    
function add_gen!(data, g_idx, g, gen_costs, emission_factor, inertia_constants, n, nodal_data, node_id; ens = false)
    data["gen"]["$g_idx"] = Dict{String, Any}()
    data["gen"]["$g_idx"]["gen_bus"] = n
    data["gen"]["$g_idx"]["pg"] = 0.0
    data["gen"]["$g_idx"]["qg"] = 0.0
    data["gen"]["$g_idx"]["node"] = node_id
    data["gen"]["$g_idx"]["model"] = 2
    data["gen"]["$g_idx"]["shutdown"] = 0.0
    data["gen"]["$g_idx"]["startup"] = 0.0
    data["gen"]["$g_idx"]["vg"] = 1.0
    data["gen"]["$g_idx"]["mbase"] = data["baseMVA"]
    data["gen"]["$g_idx"]["source_id"] = ["gen", g_idx]
    data["gen"]["$g_idx"]["index"] = g_idx
    data["gen"]["$g_idx"]["n_cost"] = 3
    data["gen"]["$g_idx"]["pmin"] = 0.0
    data["gen"]["$g_idx"]["qmax"] = 0.0
    data["gen"]["$g_idx"]["qmin"] = 0.0

    if ens == true
        data["gen"]["$g_idx"]["pmax"] = nodal_data[node_id]["demand"][1]
        data["gen"]["$g_idx"]["gen_status"] = 1
        data["gen"]["$g_idx"]["cost"] = [0.0, 1.0, 0] .* gen_costs["VOLL"] .* data["baseMVA"]
        data["gen"]["$g_idx"]["type"] = "ENS"
    else
        if !isempty(nodal_data[node_id]["generation"][g]["capacity"])
            data["gen"]["$g_idx"]["pmax"] = nodal_data[node_id]["generation"][g]["capacity"][1] / data["baseMVA"]
            data["gen"]["$g_idx"]["gen_status"] = 1
        else
            data["gen"]["$g_idx"]["pmax"] = 0
            data["gen"]["$g_idx"]["gen_status"] = 0
        end
        data["gen"]["$g_idx"]["cost"] = [0.0, 1.0, 0] .* gen_costs[g] .* data["baseMVA"]   #To be updated
        data["gen"]["$g_idx"]["type"] = g
        data["gen"]["$g_idx"]["emissions"] = emission_factor[g]
        data["gen"]["$g_idx"]["inertia_constants"] = inertia_constants[g]
    end

    return data
end
    
function add_bus!(data, n, node_id, nodes)
        data["bus"]["$n"] = Dict{String, Any}()
        data["bus"]["$n"]["index"] = n
        data["bus"]["$n"]["string"] = node_id
        data["bus"]["$n"]["zone"] = 1
        data["bus"]["$n"]["number"] = n
        data["bus"]["$n"]["bus_i"] = n
        data["bus"]["$n"]["bus_type"] = 2
        data["bus"]["$n"]["vmax"] = 1.1
        data["bus"]["$n"]["vmin"] = 0.9
        data["bus"]["$n"]["source_id"] = ["bus", n]
        data["bus"]["$n"]["area"] = 1
        data["bus"]["$n"]["zone"] = 1
        data["bus"]["$n"]["va"] = 0
        data["bus"]["$n"]["vm"] = 1.0
        data["bus"]["$n"]["base_kv"] = 400
        data["bus"]["$n"]["lat"] = nodes[nodes[!, "node_id"] .== node_id, "latitude"][1]
        data["bus"]["$n"]["lon"] = nodes[nodes[!, "node_id"] .== node_id, "longitude"][1]

    return data 
end
    
function add_load!(data, n, nodal_data, node_id)
    data["load"]["$n"] = Dict{String, Any}()
    data["load"]["$n"]["source_id"] = ["bus", n]
    data["load"]["$n"]["node"]  = node_id
    data["load"]["$n"]["load_bus"] = n
    data["load"]["$n"]["status"] = 1
    data["load"]["$n"]["pd"] = nodal_data[node_id]["demand"][1] / data["baseMVA"]
    data["load"]["$n"]["qd"] = 0
    data["load"]["$n"]["index"] = n

    return data
end

    
function add_branch!(data, ntcs, b, nodal_data)
    branch_id = ntcs[b, "Border Names Based on PEMMDB 3.0 convention"]
    f_bus_idx = nodal_data[branch_id[1:4]]["index"]
    t_bus_idx = nodal_data[branch_id[6:9]]["index"]
    reverse_name = join([branch_id[6:9],"-",branch_id[1:4]])
    if b > 1
        branch_names = Dict{String, Any}(branch["name"] => nothing for (b, branch) in data["branch"])
    
        if !haskey(branch_names, reverse_name)
            data["branch"]["$b"] = Dict{String, Any}()
            data["branch"]["$b"]["f_bus"] = data["bus"]["$f_bus_idx"]["bus_i"]
            data["branch"]["$b"]["t_bus"] = data["bus"]["$t_bus_idx"]["bus_i"]
            data["branch"]["$b"]["rate_a"] =  ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
            data["branch"]["$b"]["rate_i"]  = ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
            data["branch"]["$b"]["rate_p"]  = ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
            data["branch"]["$b"]["name"] = branch_id
        
            data["branch"]["$b"]["transformer"] = false
            data["branch"]["$b"]["tap"] = 1
            data["branch"]["$b"]["shift"] = 0.0
            data["branch"]["$b"]["angmin"] = -pi/2
            data["branch"]["$b"]["angmax"] = -pi/2
            data["branch"]["$b"]["index"] = b
            data["branch"]["$b"]["br_r"] = 0.0
            data["branch"]["$b"]["br_x"] = 0.1
            data["branch"]["$b"]["g_fr"] = 0.0
            data["branch"]["$b"]["g_to"] = 0.0
            data["branch"]["$b"]["b_fr"] = 0.0
            data["branch"]["$b"]["b_to"] = 0.0
            data["branch"]["$b"]["source_id"] = ["branch", b]
            data["branch"]["$b"]["br_status"] = 1
            data["branch"]["$b"]["number_id"] = b
        end
    else
        data["branch"]["$b"] = Dict{String, Any}()
        data["branch"]["$b"]["f_bus"] = data["bus"]["$f_bus_idx"]["bus_i"]
        data["branch"]["$b"]["t_bus"] = data["bus"]["$t_bus_idx"]["bus_i"]
        data["branch"]["$b"]["rate_a"] =  ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
        data["branch"]["$b"]["rate_i"]  = ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
        data["branch"]["$b"]["rate_p"]  = ntcs[b, "Final Value for NTC (MW)"] / data["baseMVA"]
        data["branch"]["$b"]["name"] = branch_id
    
        data["branch"]["$b"]["transformer"] = false
        data["branch"]["$b"]["tap"] = 1
        data["branch"]["$b"]["shift"] = 0.0
        data["branch"]["$b"]["angmin"] = -pi/2
        data["branch"]["$b"]["angmax"] = -pi/2
        data["branch"]["$b"]["index"] = b
        data["branch"]["$b"]["br_r"] = 0.0
        data["branch"]["$b"]["br_x"] = 0.1
        data["branch"]["$b"]["g_fr"] = 0.0
        data["branch"]["$b"]["g_to"] = 0.0
        data["branch"]["$b"]["b_fr"] = 0.0
        data["branch"]["$b"]["b_to"] = 0.0
        data["branch"]["$b"]["source_id"] = ["branch", b]
        data["branch"]["$b"]["br_status"] = 1
        data["branch"]["$b"]["number_id"] = b
    end
    
    return data
end
    
    
    
    # function prepare_hourly_data_opf(grid_data, grid_data_raw, input_data, scenario_data, result, hour, zone, wind_onshore, wind_offshore, pv)       
    #     ## Hourly demand data
    #     total_hourly_load = scenario_data[zone]["demand"][hour] / grid_data["baseMVA"]
    #     total_grid_load = sum([load["pd"] for (l, load) in grid_data_raw["load"]])
    #     for (l, load) in grid_data["load"]
    #         load["pd"] = grid_data_raw["load"][l]["pd"] * total_hourly_load / total_grid_load
    #         load["pred_rel_max"] = scenario_data[zone]["generation"]["DSR"]["capacity"][1] / (total_grid_load * grid_data["baseMVA"])
    #         load["cost_red"] = grid_data["gencost"]["DSR"] * grid_data["baseMVA"]
    #         load["cost_curt"] = grid_data["gencost"]["VOLL"] * grid_data["baseMVA"]
    #         load["flex"] = 1
    #     end
    
    #     for (g, gen) in grid_data["gen"]
    #         if gen["type"] == "Solar PV" 
    #             gen["pg"]   = deepcopy(grid_data_raw["gen"][g]["pmax"] * pv[hour])
    #             gen["pmax"] = deepcopy(grid_data_raw["gen"][g]["pmax"] * pv[hour])
    #         end
    #         if  gen["type"] == "Offshore Wind" 
    #             gen["pg"]   = deepcopy(grid_data_raw["gen"][g]["pmax"] * wind_onshore[hour])
    #             gen["pmax"] = deepcopy(grid_data_raw["gen"][g]["pmax"] * wind_onshore[hour])
    #         end
    #         if  gen["type"] == "Onshore Wind"
    #             gen["pg"]   = deepcopy(grid_data_raw["gen"][g]["pmax"] * wind_offshore[hour])
    #             gen["pmax"] = deepcopy(grid_data_raw["gen"][g]["pmax"] * wind_offshore[hour])
    #         end
    #     end    
    #     grid_data = determine_total_xb_flow!(input_data, grid_data, grid_data_raw, result, hour, zone)
    
    #     return grid_data
    # end
function prepare_mn_data_opf(grid_data, grid_data_raw, input_data, scenario_data, result, hour_start, hour_end, zone, wind_onshore, wind_offshore, pv)
    number_of_hours = hour_end - hour_start + 1
    hours = hour_start : hour_end
    extradata = Dict{String,Any}()
    extradata["dim"] = Dict{String,Any}()
    extradata["dim"] = number_of_hours
    extradata["load"] = Dict{String,Any}(l => Dict{String, Any}("pd" => zeros(1, number_of_hours), "pred_rel_max" => zeros(1, number_of_hours), "cost_red" => zeros(1, number_of_hours), "cost_curt" => zeros(1, number_of_hours))  for (l, load) in grid_data["load"])
    extradata["gen"] = Dict{String,Any}(g => Dict{String, Any}("pg" => zeros(1, number_of_hours), "pmax" => zeros(1, number_of_hours), "gen_status" => zeros(1, number_of_hours)) for (g, gen) in grid_data["gen"])
    extradata["borders"] = Dict{String,Any}(b => Dict{String, Any}("flow" => zeros(1, number_of_hours)) for (b, border) in grid_data["borders"])

    for hour_idx in 1 : number_of_hours
        hour = hours[hour_idx]
        total_hourly_load = scenario_data[zone]["demand"][hour] / grid_data["baseMVA"]
        total_grid_load = sum([load["pd"] for (l, load) in grid_data_raw["load"]])
        for (l, load) in grid_data["load"]
            extradata["load"][l]["pd"][1, hour_idx] = grid_data_raw["load"][l]["pd"] * total_hourly_load / total_grid_load
            extradata["load"][l]["pred_rel_max"][1, hour_idx]  = scenario_data[zone]["generation"]["DSR"]["capacity"][1] / (total_grid_load * grid_data["baseMVA"])
            extradata["load"][l]["cost_red"][1, hour_idx]  = grid_data["gencost"]["DSR"] * grid_data["baseMVA"]
            extradata["load"][l]["cost_curt"][1, hour_idx]  = grid_data["gencost"]["VOLL"] * grid_data["baseMVA"]
        end
    
        for (g, gen) in grid_data["gen"]
            if gen["type"] == "Solar PV" 
                extradata["gen"][g]["pg"][1, hour_idx]   = grid_data_raw["gen"][g]["pmax"] * pv[hour]
                extradata["gen"][g]["pmax"][1, hour_idx] = grid_data_raw["gen"][g]["pmax"] * pv[hour]
                extradata["gen"][g]["gen_status"][1, hour_idx] = grid_data_raw["gen"][g]["gen_status"]
            elseif  gen["type"] == "Offshore Wind" 
                extradata["gen"][g]["pg"][1, hour_idx]  = grid_data_raw["gen"][g]["pmax"] * wind_onshore[hour]
                extradata["gen"][g]["pmax"][1, hour_idx] = grid_data_raw["gen"][g]["pmax"] * wind_onshore[hour]
                extradata["gen"][g]["gen_status"][1, hour_idx] = grid_data_raw["gen"][g]["gen_status"]
            elseif  gen["type"] == "Onshore Wind"
                extradata["gen"][g]["pg"][1, hour_idx]  = grid_data_raw["gen"][g]["pmax"] * wind_offshore[hour]
                extradata["gen"][g]["pmax"][1, hour_idx] = grid_data_raw["gen"][g]["pmax"] * wind_offshore[hour]
                extradata["gen"][g]["gen_status"][1, hour_idx] = grid_data_raw["gen"][g]["gen_status"]
            elseif  gen["type"] == "HVDC"   # deactivate dummy generators added in raw files, as proper DC links are added.
                extradata["gen"][g]["pg"][1, hour_idx]  = 0
                extradata["gen"][g]["pmax"][1, hour_idx] = 0
                extradata["gen"][g]["gen_status"][1, hour_idx] = 0
            else
                extradata["gen"][g]["pg"][1, hour_idx]  = grid_data_raw["gen"][g]["pmax"]
                extradata["gen"][g]["pmax"][1, hour_idx] = grid_data_raw["gen"][g]["pmax"]
                extradata["gen"][g]["gen_status"][1, hour_idx] = grid_data_raw["gen"][g]["gen_status"]
            end
        end    

        for (b, border) in grid_data_raw["borders"]
            if haskey(border, "zone_from")
                zone_from = border["zone_from"]
                int_name_fr = join([zone_from,"-",border["name"]])
                int_name_to = join([border["name"],"-",zone_from])
            else    
                int_name_fr = join([zone,"-",border["name"]])
                int_name_to = join([border["name"],"-",zone])
            end
            flow = 0
        
            for (b, branch) in input_data["branch"]
                if branch["name"] == int_name_fr
                    flow = result["$hour"]["solution"]["branch"][b]["pf"]
                elseif branch["name"] == int_name_to
                    flow = result["$hour"]["solution"]["branch"][b]["pt"]
                end
            end
    
            extradata["borders"][b]["flow"][1, hour_idx] = flow
        end
    end

    return extradata
end


function prepare_hourly_data_opf!(grid_data, ts_data, hour)
    for (l, load) in grid_data["load"]
        load["pd"] =  ts_data["load"][l]["pd"][1, hour]
        load["pred_rel_max"] = ts_data["load"][l]["pred_rel_max"][1, hour] 
        load["cost_red"] = ts_data["load"][l]["cost_red"][1, hour] 
        load["cost_curt"] = ts_data["load"][l]["cost_curt"][1, hour]
    end
    for (g, gen) in grid_data["gen"]
        gen["pg"] =  ts_data["gen"][g]["pg"][1, hour]
        gen["pmax"] =  ts_data["gen"][g]["pmax"][1, hour]
        gen["gen_status"] =  ts_data["gen"][g]["gen_status"][1, hour]
    end
    for (b, border) in grid_data["borders"]
        border["flow"] = ts_data["borders"][b]["flow"][1, hour]
    end

    return grid_data
end
    
    
    
function determine_total_xb_flow!(input_data, grid_data, grid_data_raw, result, hour, zone)

    for (b, border) in grid_data_raw["borders"]
        int_name_fr = join([zone,"-",border["name"]])
        int_name_to = join([border["name"],"-",zone])
    
        flow = 0
    
        for (b, branch) in input_data["branch"]
            if branch["name"] == int_name_fr
                flow = result["$hour"]["solution"]["branch"][b]["pf"]
            elseif branch["name"] == int_name_to
                flow = result["$hour"]["solution"]["branch"][b]["pt"]
            end
        end

        grid_data["borders"][b]["flow"] = flow
    end

    return grid_data
end
    
    
function fix_data!(grid_data; fix_borders = false, min_branch_rating = nothing, max_branch_rating = 99, gen_slack = 0, all_lines_on = false, border_slack = nothing)

    # add dummy ratings for branches with no rating:
    for (b, branch) in grid_data["branch"]
        # add dummy ratings for branches with no rating:
        # if the length of the branch is 0 -> mostly breakers 
        if branch["source_id"][1] == "branch" && branch["len"] == 0
            branch["rate_a"] = max_branch_rating
            branch["rate_b"] = max_branch_rating
            branch["rate_c"] = max_branch_rating
        elseif !haskey(branch, "rate_a") || branch["rate_a"] == 0
            branch["rate_a"] = max_branch_rating
            branch["rate_b"] = max_branch_rating
            branch["rate_c"] = max_branch_rating
        end
        if !isnothing(min_branch_rating)
            branch["rate_a"] = max(branch["rate_a"], min_branch_rating)
            branch["rate_b"] = max(branch["rate_a"], min_branch_rating)
            branch["rate_c"] = max(branch["rate_a"], min_branch_rating)
        end
        # Limit branch ratings to 0.9 pu to account for AC vas DC load branch_flows
        branch["rate_a"] = branch["rate_a"] * 0.9
        branch["rate_b"] = branch["rate_a"] * 0.9
        branch["rate_c"] = branch["rate_a"] * 0.9
        branch["br_x"] = max(1e-5, abs(branch["br_x"]))
        branch["br_r"] = abs(branch["br_r"])
    end

    if all_lines_on == true
        for (b, branch) in grid_data["branch"]
            state = 1
            for (bo, border) in grid_data["borders"]
                for (l, xb_line) in border["xb_lines"]
                    if xb_line["index"] == parse(Int, b)
                        state = xb_line["br_status"]
                    end
                end
            end
            branch["br_status"] = min(1, state)
        end
    end

    for (g, gen) in grid_data["gen"]
        # if gen["pmin"] > 0 
        #     gen["pmin"] = 0
        # end
        gen["pmin"] = 0
        #gen["pmax"] = max(gen["pmax"], gen["pg"] + gen_slack)
        # if  gen["pg"] < 0
        #     gen["pmin"] = gen["pg"] #- gen_slack
        # end
    end

    for (l, load) in grid_data["load"]
        load["pred_rel_max"]  = 0
        load["cost_red"] = 0
        load["cost_curt"]  = 0
        load["flex"] = 1
    end
    if fix_borders == true
    #et ratings of XB generators to 99.99 pu, if data is bad.....
        for (bo, border) in grid_data["borders"]
            xb_nodes = border["xb_nodes"]
            xb_bus = []
            for (b, bus) in grid_data["bus"]
                if any(bus["name"] .== xb_nodes)
                    xb_bus= push!(xb_bus, bus["index"])
                end
            end 
            for xb_bus_ in xb_bus
                for (g, gen) in grid_data["gen"]
                    if (gen["gen_bus"] == xb_bus_) && (xb_bus_ !=0)
                        gen["pmax"] = 99.99
                        gen["pmin"] = -99.99
                        gen["gen_status"] = 1
                    end
                end
            end
            if !isnothing(border_slack)
                border["slack"] = border_slack
            else
                border["slack"] = 0
            end
            for (b, bus) in grid_data["bus"]
                if any(bus["name"] .== xb_nodes)
                    for (l, load) in grid_data["load"]
                        if bus["index"] == load["load_bus"]
                            load["pd"] = 0
                            load["qd"] = 0
                        end
                    end
                end
            end 
        end
    end

    for (g, gen) in grid_data["gen"]
        if gen["pmin"] > gen["pmax"]
            print(g, "\n")
        end
        if gen["pmax"] == 99.99 && gen["pmin"] == -99.99
            gen["cost"][1] = 150.0
        end
    end

    return grid_data
end


function prepare_redispatch_data(opf_result, grid_data, hour; contingency = nothing, rd_cost_factor = 4, inertia_limit = nothing, zonal_input = nothing, zonal_result = nothing, zone = nothing, border_slack = nothing)
    grid_data_rd = deepcopy(grid_data)
    result = opf_result["$hour"]["solution"]

    for (g, gen) in grid_data_rd["gen"]
        if haskey(result["gen"], g)
            gen["pg"] = result["gen"][g]["pg"]
            if gen["pg"] < 0.1
                gen["dispatch_status"] = 0
            else
                gen["dispatch_status"] = 1
            end 
        else
            gen["dispatch_status"] = 0
        end
        
        gen["rdcost_up"] = gen["cost"][1] * rd_cost_factor
        gen["rdcost_down"] = gen["cost"][1] * rd_cost_factor
        if !haskey(gen, "start_up_cost")
            gen["start_up_cost"] = 500
        end
    end

    for (l, load) in grid_data_rd["load"]
        if haskey(result["load"], l)
            load["pd"] = result["load"][l]["pflex"]
        end
    end

    for (c, conv) in grid_data_rd["convdc"]
        conv["P_g"] = -result["convdc"][c]["ptf_to"]
    end

    if !isnothing(contingency)
        for (b, border) in grid_data_rd["borders"]
            for (br, branch) in  border["xb_lines"]
                if branch["index"] == contingency
                    print(b, " ", br)
                    delete!(grid_data_rd["borders"][b]["xb_lines"], br)
                end
            end
        end
        grid_data_rd["branch"]["$contingency"]["br_status"] = 0
    end

    if !isnothing(inertia_limit)
        grid_data_rd["inertia_limit"] = inertia_limit
    end

    if  !isnothing(zone)
        determine_total_xb_flow!(zonal_input, grid_data_rd, grid_data_rd, zonal_result, hour, zone)
    end

    for (bo, border) in grid_data_rd["borders"]
        if !isnothing(border_slack)
            border["slack"] = border_slack
        else
            border["slack"] = 0
        end
    end
    return grid_data_rd
end


function add_load_and_pst_properties!(grid_data; pst = true)
    for (l, load) in grid_data["load"]
        load["pd"] = load["pmax"]
        load["qd"] = load["pd"] / load["cosphi"] * sqrt(1 - load["cosphi"]^2)
    end

    if pst ==true
        grid_data["pst"] = Dict{String, Any}()
        for (l, load) in grid_data["load"]
            load["pred_rel_max"]  = 0
            load["cost_red"] = 0
            load["cost_curt"]  = 10000 * grid_data["baseMVA"]
            load["flex"] = 1
        end
    end
    return grid_data
end