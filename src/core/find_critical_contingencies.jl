# Function to find the most critical N-1 contingencies for each hour specified in the OPF result. The definition of the cricital contingency is:
# (1) Branch rating >= 1000 MVA
# (2) Power flow of the branch >= 50 % of branch rating

function find_critical_contingencies(opf_result, grid_data, hour; min_rating = 10, loading = 0.5)
    contingencies = Dict{String, Any}()
    push!(contingencies, "$hour" => Dict{String, Any}())
    for (b, branch) in opf_result["$hour"]["solution"]["branch"]
        rating = grid_data["branch"][b]["rate_a"]
        flow = branch["pf"]
        if rating >= min_rating && abs(flow / rating) >= loading
            push!(contingencies["$hour"], b => parse(Int, b))
        end  
    end

    return contingencies
end