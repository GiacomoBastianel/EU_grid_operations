# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using JSON

file = joinpath(@__DIR__,"European_grid.json")
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)


s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(EU_grid, DCPPowerModel, Gurobi.Optimizer; setting = s)

r_tf    = []
x_tf    = []
busac_i = []
tm      = []
for (b_id,b) in EU_grid["convdc"]
    push!(r_tf,b["rtf"])
    push!(x_tf,b["xtf"])
    push!(busac_i,b["busac_i"])
    push!(tm,b["tm"])
end


types_r_tf    = []
types_x_tf    = []
types_busac_i = []
types_tm      = []
for i in 1:length(r_tf)
    push!(types_r_tf,typeof(r_tf[i]))
    push!(types_x_tf,typeof(x_tf[i]))
    push!(types_busac_i,typeof(busac_i[i]))
    push!(types_tm,typeof(tm[i]))
end
unique(types_r_tf)
unique(types_x_tf)
unique(types_busac_i)
unique(types_tm)


for i in 1:length(br_r)
    if typeof(br_r[i]) == String
        print(i,"\n")
    end
end




for (b_id,b) in EU_grid["convdc"]
    if b["busac_i"] == 2462
        print(b_id)
    end
end
EU_grid["convdc"]["110"]

