function process_results(hour_start, hour_end, batch_size, grid_data, timeseries_data, number_of_clusters, file_name::String)

    file_name_ind = join([file_name, "_ind.json"])
    file_name_cl = join([file_name, "_cl.json"])
    iterations = Int(hour_end - hour_start + 1) /batch_size

    result = Dict{String, Any}(["$i" => Dict{String, Any}() for i in hour_start:hour_end])
    for i in 1:iterations
        hs = Int(hour_start + (i-1) * batch_size)
        he = Int(hs + batch_size - 1)
        print("Processing results from hour ", hs, " to " , he, "\n")
        fn = join([file_name, "_opf_","$hs","_to_","$he",".json"])
        res = Dict{String, Any}()
        open(fn) do f
            dicttxt = read(f,String)  # file information to string
            res = JSON.parse(dicttxt)  # parse and transform data
        end

        for k in keys(res)
            result[k] = res[k]
        end
    end

    total_costs_ = Dict{String, Any}()
    load_shedding = Dict{String, Any}()
    for (h, hour) in result
        if !isempty(hour["solution"])
            total_costs_[h] = hour["objective"]
            load_shedding[h] = sum([load["pcurt"] for (l, load) in hour["solution"]["load"]])
        else
            print("No feasible solution for hour ", h,".", "\n")
        end
    end

    result_con = Dict{String, Any}() 
    result_con["total_cost"] = sum([cost for (c, cost) in total_costs_])
    result_con["load_shedding"] = load_shedding

    # do cluserting for redispatch calcualtions
    hourly_indicators = calculate_hourly_indicators(result, grid_data, timeseries_data)
    clusters, cluster_centers = res_demand_clustering(hourly_indicators, number_of_clusters)

    cluster_results = Dict{String, Any}(["$c" => result["$c"] for c in clusters])

    # Save re-dispatch results
    json_string = JSON.json(hourly_indicators)
    open(file_name_ind,"w") do f
    write(f, json_string)
    end

    # Save re-dispatch results
    json_string = JSON.json(cluster_results)
    open(file_name_cl,"w") do f
    write(f, json_string)
    end

    return result_con
end


function calculate_hourly_indicators(result, grid_data, timeseries_data)
    grid_data_hourly = deepcopy(grid_data)
    hourly_indicators = Dict{String, Any}([h => Dict{String, Any}("demand" => Dict{String, Any}(), "generation" => Dict{String, Any}()) for (h, hour) in result])

    for (h, hour) in result
        hourly_grid_data!(grid_data_hourly, grid_data, parse(Int, h), timeseries_data)
        hourly_indicators[h]["demand"]["total_demand"] = sum([load["pd"] for (l, load) in grid_data_hourly["load"]])
        hourly_indicators[h]["generation"]["res_generation"] = get_res_generation(result, grid_data_hourly, h)
    end
    return hourly_indicators
end

function get_res_generation(result, grid_data, hour)
    res_gen = 0.0
    if haskey(result[hour]["solution"], "gen")
        for (g, gen) in result[hour]["solution"]["gen"]
            type = grid_data["gen"][g]["type_tyndp"]
            if type == "Onshore Wind" || type == "Offshore Wind" || type == "Solar PV" 
                res_gen = res_gen + gen["pg"]
            end
        end
    else
        print("No feasible solution for hour ", hour,".", "\n")
    end
    return res_gen
end



function get_branch_flows(hour_start, hour_end, batch_size, file_name::String)
    iterations = Int(hour_end - hour_start + 1) /batch_size

    result = Dict{String, Any}(["$i" => Dict{String, Any}() for i in hour_start:hour_end])
    for i in 1:iterations
        hs = Int(hour_start + (i-1) * batch_size)
        he = Int(hs + batch_size - 1)
        print("Processing results from hour ", hs, " to " , he, "\n")
        fn = join([file_name, "_opf_","$hs","_to_","$he",".json"])
        res = Dict{String, Any}()
        open(fn) do f
            dicttxt = read(f,String)  # file information to string
            res = JSON.parse(dicttxt)  # parse and transform data
        end

        for k in keys(res)
            result[k] = res[k]
        end
    end

    print("Extracting branch flows", "\n")
    ac_branch_flows = Dict{String, Any}([b => zeros(length(result)) for (b, branch) in result["1"]["solution"]["branch"]])
    dc_branch_flows = Dict{String, Any}([b => zeros(length(result)) for (b, branch) in result["1"]["solution"]["branchdc"]])
    for hour in sort(parse.(Int, collect(keys(result))))
         for (b, branch) in result["1"]["solution"]["branch"]
            if haskey(result["$hour"]["solution"], "branch") && haskey(result["$hour"]["solution"]["branch"], b) 
                ac_branch_flows[b][hour] = result["$hour"]["solution"]["branch"][b]["pf"]
            end
         end
         for (b, branch) in result["1"]["solution"]["branchdc"]
            if haskey(result["$hour"]["solution"], "branchdc") && haskey(result["$hour"]["solution"]["branchdc"], b) 
                dc_branch_flows[b][hour] = result["$hour"]["solution"]["branchdc"][b]["pf"]
            end
         end
    end

    return ac_branch_flows, dc_branch_flows, result
end

