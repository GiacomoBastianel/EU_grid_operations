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






total_cost = 0
total_cost_un = 0
i = 1
# for i in 1:12
    hs = 1 + (i-1) * batch_size
    he = hs + batch_size - 1
    fn = join([output_file_name, "_opf_","$hs","_to_","$he",".json"])
    res = Dict()
    open(fn) do f
        dicttxt = read(f,String)  # file information to string
        global res = JSON.parse(dicttxt)  # parse and transform data
    end
    # for (h, hour) in res
    #     if isempty(hour["solution"])
    #         print(h, " -> ", hour["termination_status"],  "\n")
    #     else
    #         total_cost = total_cost + hour["objective"]
    #     end
    # end
    fn_un = join([output_file_name_un, "_opf_","$hs","_to_","$he",".json"])
    res_un = Dict()
    open(fn_un) do f
        dicttxt = read(f,String)  # file information to string
        global res_un = JSON.parse(dicttxt)  # parse and transform data
    end
    # for (h, hour) in res_un
    #     if isempty(hour["solution"])
    #         print(h, " -> ", hour["termination_status"],  "\n")
    #     else
    #         total_cost_un = total_cost_un + hour["objective"]
    #     end
    # end
# # end