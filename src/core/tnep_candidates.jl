function get_tnep_candidates(result, opf_data)
    
    branch_duals = Dict{String, Any}([n => [branch["mu_sm_to"] for (b, branch) in nw["solution"]["branch"]] for (n, nw) in result])
    branch_ids = sort(collect(parse.(Int, keys(result["1"]["solution"]["branch"]))))
    bus_duals = Dict{String, Any}([n => [bus["lam_kcl_r"] for (b, bus) in nw["solution"]["bus"]] for (n, nw) in result])
    bus_ids = sort(collect(parse.(Int, keys(result["1"]["solution"]["bus"]))))

    bus_duals_ = Dict{String, Any}([b => StatsBase.mean([hour["solution"]["bus"][b]["lam_kcl_r"] for (h, hour) in result]) for (b, bus) in opf_data["bus"]])



    
    ## to find out which bus is a candidate for branch connection, determine which bus has the most significant pos/neg dual variation
    sensitive_buses = []
    for (i, bus_id) in enumerate(bus_ids)
        bus_daily_duals = [duals[i] for (h, duals) in bus_duals]
        bus_max_abs = maximum(abs.(bus_daily_duals))
        if !isempty(bus_daily_duals[bus_daily_duals.>0])
            bus_max_pos_normalised = maximum(bus_daily_duals[bus_daily_duals.>0]) / bus_max_abs
        else 
            bus_max_pos_normalised = 0
        end
        if !isempty(bus_daily_duals[bus_daily_duals.<0])
            bus_min_neg_normalised = minimum(bus_daily_duals[bus_daily_duals.<0]) / bus_max_abs
        else
            bus_min_neg_normalised = 0
        end
        bus_mean_variation = abs((bus_max_pos_normalised + bus_min_neg_normalised) / 2)

        if abs(bus_max_pos_normalised) .> 0.07 && abs(bus_min_neg_normalised) .> 0.02 #0.07
            if opf_data["bus"]["$bus_id"]["base_kv"] > 220
                # @show (bus_id, opf_data["bus"]["$bus_id"]["area"], bus_max_pos_normalised*bus_max_abs, bus_min_neg_normalised*bus_max_abs)
                push!(sensitive_buses, (bus_id, opf_data["bus"]["$bus_id"]["base_kv"], opf_data["bus"]["$bus_id"]["area"], bus_max_pos_normalised*bus_max_abs, bus_min_neg_normalised*bus_max_abs))
            end
        end
    end
    @show sensitive_buses

    total_variation_sorted =  [x[3]/maximum([abs(x[3]),abs(x[4])]) + x[4]/maximum([abs(x[3]),abs(x[4])]) for x in sensitive_buses]
    sorted_buses = sort(sensitive_buses, by=x->x[3]/maximum([abs(x[3]),abs(x[4])]) + x[4]/maximum([abs(x[3]),abs(x[4])]))


    return sensitive_buses, total_variation_sorted, sorted_buses, bus_duals, bus_duals_
end