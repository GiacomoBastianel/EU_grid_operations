# Script to test the European grid
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations
using Gurobi
using JSON
using Plots

results_folder = "/Users/giacomobastianel/Desktop/Results_Merijn"

results_1_720 = JSON.parsefile(joinpath(results_folder,"BE_energy_island_simulations_1_720.json"))
results_4320_5040 = JSON.parsefile(joinpath(results_folder,"BE_energy_island_simulations_4320_5040.json"))
results_5760_6480 = JSON.parsefile(joinpath(results_folder,"BE_energy_island_simulations_5760_6480.json"))


######### DEFINE INPUT PARAMETERS
scenario = "GA2030"
climate_year = "2007"
load_data = true
use_case = "de_hvdc_backbone"
only_hvdc_case = false
links = Dict("BE_EI" => [], "Nautilus" => [] , "Triton" => [])
zone = "DE00"
output_base = "DE"
output_cba = "DE_HVDC"
number_of_clusters = 20
number_of_hours_rd = 5
hour_start = 1
hour_end = 8760
############ LOAD EU grid data
file = "./data_sources/European_grid.json"
output_file_name = joinpath("results", join([use_case,"_",scenario,"_", climate_year]))
gurobi = Gurobi.Optimizer
EU_grid = _PM.parse_file(file)
_PMACDC.process_additional_data!(EU_grid)
_EUGO.add_load_and_pst_properties!(EU_grid)


#### LOAD TYNDP SCENARIO DATA ##########
if load_data == true
    zonal_result, zonal_input, scenario_data = _EUGO.load_results(scenario, climate_year) # Import zonal results
    ntcs, zones, arcs, tyndp_capacity, tyndp_demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = _EUGO.get_grid_data(scenario) # import zonal input (mainly used for cost data)
    pv, wind_onshore, wind_offshore = _EUGO.load_res_data()
end

print("ALL FILES LOADED", "\n")
print("----------------------","\n")
######

zone_mapping = _EUGO.map_zones()
_EUGO.scale_generation!(tyndp_capacity, EU_grid, scenario, climate_year, zone_mapping)

# Isolate zone: input is vector of strings, if you need to relax the fixing border flow assumptions use:
zone_grid = _EUGO.isolate_zones(EU_grid, ["BE","UK","DK1","DK2","NL"])
#timeseries_data = _EUGO.create_res_and_demand_time_series(wind_onshore, wind_offshore, pv, scenario_data, climate_year, zone_mapping)
#push!(timeseries_data, "xb_flows" => _EUGO.get_xb_flows(zone_grid, zonal_result, zonal_input, zone_mapping)) 
_EUGO.get_demand_reponse!(zone_grid, zonal_input, zone_mapping, timeseries_data)

# There is no internal congestion as many of the lines are 5000 MVA, limit the lines....
for (b, branch) in zone_grid["branch"]
    branch["angmin"] = -pi
    branch["angmax"] = pi
end

###################
#####  Adding HVDC links
zone_grid_un = _EUGO.add_hvdc_links(zone_grid, links)
zone_grid_EI = _EUGO.add_full_Belgian_energy_island(zone_grid,5900.0)
zone_grid_EI_0 = _EUGO.add_full_Belgian_energy_island(zone_grid,0.0)

buses = []
for i in eachindex(zone_grid_EI["gen"])
    push!(buses,parse(Int64,i))
end
maximum(buses)


################## New grid elements with the energy island ###########################
zone_grid_EI["busdc"]["10210"] # BE EI
zone_grid_EI["busdc"]["10211"] # EI SW
zone_grid_EI["busdc"]["10212"] # BE ONSHORE I
zone_grid_EI["busdc"]["10213"] # UK EI
zone_grid_EI["busdc"]["10214"] # UK ONSHORE
zone_grid_EI["busdc"]["10215"] # DK 1
zone_grid_EI["busdc"]["10216"] # DK 2
zone_grid_EI["busdc"]["10217"] # EI SW (DK)
zone_grid_EI["busdc"]["10218"] # DK ONSHORE 
zone_grid_EI["busdc"]["10219"] # BE ONSHORE II

zone_grid_EI["bus"]["10005"]
zone_grid_EI["bus"]["10004"]
zone_grid_EI["bus"]["10003"]
zone_grid_EI["bus"]["10002"]
zone_grid_EI["bus"]["10001"]

zone_grid_EI["branch"]["8803"] # AC Line BE EI 1 -> Gezelle
zone_grid_EI["branch"]["8804"] # AC Line BE EI 2 -> Gezelle
zone_grid_EI["branch"]["8805"] # AC Line BE EI 3 -> Gezelle
zone_grid_EI["branch"]["8806"] # AC Line BE EI 4 -> Gezelle
zone_grid_EI["branch"]["8807"] # AC Line BE EI 5 -> Gezelle
zone_grid_EI["branch"]["8808"] # AC Line BE EI 6 -> Gezelle
zone_grid_EI["branch"]["8809"] # Switch BE EI AC -> BE EI DC


zone_grid_EI["branchdc"]["110"] # EI SW (DK) -> BE ONSHORE II
zone_grid_EI["branchdc"]["109"] # DK ONSHORE
zone_grid_EI["branchdc"]["108"] # EI SW (DK) -> EI SW
zone_grid_EI["branchdc"]["107"] # DK 1 -> EI SW (DK)
zone_grid_EI["branchdc"]["106"] # DK 1 -> DK 2
zone_grid_EI["branchdc"]["105"] # UK ONSHORE -> UK EI
zone_grid_EI["branchdc"]["104"] # EI SW -> UK EI
zone_grid_EI["branchdc"]["103"] # EI SW -> BE ONSHORE I
zone_grid_EI["branchdc"]["102"] # BE EI -> EI SW

zone_grid_EI["gen"]["7337"] # DK 1.4 GW, AC BUS 10005
zone_grid_EI["gen"]["7336"] # DK 2.0 GW, AC BUS 10004
zone_grid_EI["gen"]["7335"] # UK 1.4 GW, AC BUS 10003
zone_grid_EI["gen"]["7334"] # BE 1.4 GW, AC BUS 10002
zone_grid_EI["gen"]["7333"] # BE 2.1 GW, AC BUS 10001


for (br_id,br) in zone_grid_EI["branch"]
    if br["f_bus"] == 131 || br["t_bus"] == 131
        print(br_id,"\n")
    end
end


br_dc_110 = []
br_dc_109 = []
br_dc_108 = []
br_dc_107 = []
br_dc_106 = []
br_dc_105 = []
br_dc_104 = []
br_dc_103 = []
br_dc_102 = []

gen_7337 = []
gen_7336 = []
gen_7335 = []
gen_7334 = []
gen_7333 = []

br_8803 = []
br_8804 = []
br_8805 = []
br_8806 = []
br_8807 = []
br_8808 = []
br_8809 = []


for i in 1:720
    print(i,"\n")
    if results_1_720["EI_0"]["$i"]["termination_status"] != "INFEASIBLE"
        push!(br_dc_102,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["102"]["pt"])
        push!(br_dc_103,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["103"]["pt"])
        push!(br_dc_104,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["104"]["pt"])
        push!(br_dc_105,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["105"]["pt"])
        push!(br_dc_106,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["106"]["pt"])
        push!(br_dc_107,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["107"]["pt"])
        push!(br_dc_108,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["108"]["pt"])
        push!(br_dc_109,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["109"]["pt"])
        push!(br_dc_110,results_1_720["EI_0"]["$i"]["solution"]["branchdc"]["110"]["pt"])
        push!(gen_7337,results_1_720["EI_0"]["$i"]["solution"]["gen"]["7337"]["pg"])
        push!(gen_7336,results_1_720["EI_0"]["$i"]["solution"]["gen"]["7336"]["pg"])
        push!(gen_7335,results_1_720["EI_0"]["$i"]["solution"]["gen"]["7335"]["pg"])
        push!(gen_7334,results_1_720["EI_0"]["$i"]["solution"]["gen"]["7334"]["pg"])
        push!(gen_7333,results_1_720["EI_0"]["$i"]["solution"]["gen"]["7333"]["pg"])
        push!(br_8803,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8803"]["pt"])
        push!(br_8804,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8804"]["pt"])
        push!(br_8805,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8805"]["pt"])
        push!(br_8806,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8806"]["pt"])
        push!(br_8807,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8807"]["pt"])
        push!(br_8808,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8808"]["pt"])
        push!(br_8809,results_1_720["EI_0"]["$i"]["solution"]["branch"]["8809"]["pt"])
    end
end


plot(gen_7333*100/10^3)
plot!(gen_7334*100/10^3)
plot!(gen_7335*100/10^3)
plot!(gen_7336*100/10^3)
plot!(gen_7337*100/10^3)


plot(br_dc_102)
plot(br_dc_103)
plot!(br_dc_104)

scatter(br_dc_102)
scatter!(br_dc_103)
scatter(br_dc_108)


scatter(br_8809)


count(>(0),br_8804)


obj_no_inv = []
obj_ei_0 = []

for i in 1:720
    if results_1_720["EI_0"]["$i"]["termination_status"] != "INFEASIBLE"
        push!(obj_no_inv,results_1_720["no_investment"]["$i"]["objective"])
        push!(obj_ei_0,results_1_720["EI_0"]["$i"]["objective"])
    else
    end
end

scatter(obj_no_inv)
scatter!(obj_ei_0)

diff = obj_no_inv .- obj_ei_0