function process_results(hour_start, hour_end, batch_size, file_name::String)
    iterations = Int(hour_end - hour_start + 1) /batch_size

    result= Dict{String, Any}(["$i" => Dict{String, Any}() for i in 1:(hour_end - hour_start + 1)])
    for i in 1:iterations
        hs = Int(1 + (i-1) * batch_size)
        he = Int(hs + batch_size - 1)
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

    total_costs_ = zeros(1, length(result))
    for (h, hour) in result
        if !isempty(hour["solution"])
            total_costs_[1, parse(Int, h)] = hour["objective"]
        end
    end

    total_costs = sum(total_costs_)
    return result, total_costs
end
