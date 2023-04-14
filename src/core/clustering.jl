function res_demand_clustering(hourly_indicators, number_of_clusters)

    total_demand =  [hour["demand"]["total_demand"] for (h, hour) in hourly_indicators]
    total_res =  [hour["generation"]["res_generation"] for (h, hour) in hourly_indicators]
    hours = [parse(Int, h) for (h, hour) in hourly_indicators]
    
    data = vcat(hours', total_demand', total_res')
    data[isnan.(data)] .= 0
    
    result = Clustering.kmeans(data, number_of_clusters)
    
    cluster_centers = result.centers[:, findall(result.centers[2, :] .!== 0.0)]
    
    clusters = Dict(["$c" => [] for c in 1:size(cluster_centers, 2)])
    for hour in 1:length(result.assignments)
        c_idx = result.assignments[hour]
        if haskey(clusters, "$c_idx") && length(clusters["$c_idx"]) < 10
            push!(clusters["$c_idx"], hour)
        end
    end
    
    return clusters
    
    end