# Including load and RES time series for each zone
# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using JSON
using Feather
using CSV
using DataFrames

include("load_data.jl")

#########################
# Upload European grid
file = joinpath(@__DIR__,"European_grid.json")
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
EU_grid["pst"] = Dict{String, Any}()
for (l, load) in EU_grid["load"]
    load["pred_rel_max"]  = 0
    load["cost_red"] = 100 * EU_grid["baseMVA"] 
    load["cost_curt"]  = 1000 * EU_grid["baseMVA"] 
    load["flex"] = 1
end
# Upload grid example
test_file = joinpath(@__DIR__,"case5_acdc.m")
test_grid = _PM.parse_file(test_file)
_PMACDC.process_additional_data!(test_grid)

############################
# include time series
pv, wind_onshore, wind_offshore = load_res_data()
year = "1984"
scenario = "DE2030"
number_of_hours = 8760

corrected_year = parse(Int64,year) - 1982 + 5 # 1982 corresponds to the 5th column

RES_time_series = process_RES_time_series(wind_onshore,wind_offshore,pv,corrected_year)
load_zones = add_load_series(scenario,year,1,number_of_hours)

RES_time_series_adjusted = adjust_time_series(RES_time_series)
EU_grid_adjusted = zones_alignment(EU_grid)

turn_off_high_curt_loads(EU_grid_adjusted)
turn_off_high_curt_loads(EU_grid)


results = Dict{String,Any}()
for i in 1:number_of_hours
    EU_grid_hour = deepcopy(EU_grid_adjusted)
    results["$i"] = Dict{String,Any}()
    EU_grid_hour = include_RES_and_load(EU_grid,EU_grid_hour,RES_time_series_adjusted,load_zones,i)
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => false, "objective_components" => ["gen", "demand"])
    results["$i"] = deepcopy(_PMACDC.solve_acdcopf(EU_grid_hour, DCPPowerModel, Gurobi.Optimizer; setting = s)) 
end



objs = [results[i]["objective"] for i in eachindex(results)]

tot_gen = sum(results["1"]["solution"]["gen"][i]["pg"] for i in eachindex(results["1"]["solution"]["gen"]))*100 #MW
tot_curt = [results["1"]["solution"]["load"][i]["pcurt"] for i in eachindex(results["1"]["solution"]["load"])]*100 #MW

curt = []
for i in 1:length(results["1"]["solution"]["load"])
    if haskey(results["1"]["solution"]["load"],"$i")
        push!(curt,results["1"]["solution"]["load"]["$i"]["pcurt"])
    end
end
maximum(curt)
for i in 1:length(curt)
    if curt[i] != 0
        print([i,curt[i]],"\n")
    end
end
maximum(curt)





#### Plot some results:
#average_electricity_price = result_cba["objective"] / (sum([load_zones[l][i] for l in eachindex(load_zones)) * EU_grid["baseMVA"])
#total_load_curtailment =  sum([load["pcurt"] for (l, load) in result_cba["solution"]["load"]]) * EU_grid["baseMVA"]

print("Average electricty price: ", average_electricity_price, " Euro / MWh", "\n")
print("Total curtailed load: ", total_load_curtailment, " MW")
plot([load["pcurt"] for (l, load) in result_cba["solution"]["load"]] * EU_grid["baseMVA"])
xlabel!("Load ID")
ylabel!("Pcurt in MW")
=#


#### Plot some results:
average_electricity_prices = []
for i in 1:720
    push!(average_electricity_prices,(results["$i"]["objective"] / sum(load_zones[l][i] for l in eachindex(load_zones))))
end

#=
results["1"]["objective"]
sum(EU_grid["gen"][i]["pmax"] for i in eachindex(EU_grid["gen"]))*100
sum(load_zones[l][1] for l in eachindex(load_zones))

print("Average electricty price: ", average_electricity_price, " Euro / MWh", "\n")
print("Total curtailed load: ", total_load_curtailment, " MW")
plot([load["pcurt"] for (l, load) in result_cba["solution"]["load"]] * EU_grid["baseMVA"])
xlabel!("Load ID")
ylabel!("Pcurt in MW")
=#