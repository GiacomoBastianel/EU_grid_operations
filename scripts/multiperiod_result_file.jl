#### Plots Matteo Catania


## Import required functions - Some of them in later stages....
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using EU_grid_operations; const _EUGO = EU_grid_operations

using Plots
import JuMP
import JSON
import DataFrames; const _DF = DataFrames
import CSV
import Feather
using XLSX
using Statistics
using Clustering
using StatsBase
import StatsPlots
using ColorSchemes
using DataFrames

scenario = "FENICE"
year = "2050"
climate_year = "2009"
zonal_result, zonal_input, scenario_data = _EUGO.load_results("2024",scenario,year, climate_year)

zones = ["ITCA" "ITCN" "ITCO" "ITCS" "ITN1" "ITSA" "ITS1" "ITSI"]# "BE00" "AT00" "CH00" "UK00"]

use_case = "it"
file_name = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/", join([use_case,"_",scenario,"_", climate_year])) #,"_inv"
hour_start = 1
hour_end = 8760 #720

result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json"
result = JSON.parsefile(result_file)

zone_grid_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_grid.json"
zone_grid = JSON.parsefile(zone_grid_file)


for n = 1:hour_end
  println((n, sum([gen["pg"] for (g, gen) in result["solution"]["nw"]["$n"]["gen"]])))
end
for n = 1:hour_end
   println((n, sum([load["pflex"] for (l, load) in result["solution"]["nw"]["$n"]["load"]])))
end

for n = 1: (hour_end - hour_start)
  println((n, sum([strg["ps"] for (s, strg) in result["solution"]["nw"]["$n"]["storage"]])))
end

# total_generation=0
# for n = 1:hour_end
#   total_generation= total_generation +sum([gen["pg"] for (g, gen) in result["solution"]["nw"]["$n"]["gen"]])
# end
# print(total_generation)

# total_demand=0
# for n = 1:hour_end
#   total_demand= total_generation +sum([load["pflex"] for (l, load) in result["solution"]["nw"]["$n"]["load"]])
# end
# print(total_demand)



zone_grid_un = zone_grid #_EUGO.add_hvdc_links(zone_grid, links)

ac_branch_flows, dc_branch_flows, results = _EUGO.get_branch_flows_multiperiod(1, 8760, "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json") 


flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = abs.(ac_branch_flows[b]) ./ zone_grid_un["branch"][b]["rate_a"]
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = abs.(dc_branch_flows[b]) ./ zone_grid_un["branchdc"][b]["rateA"]
end

colormap = ColorSchemes.jet1
plot_file_name = file_name = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results", "plots", join([use_case,"_",scenario,"_", climate_year,"_flows.pdf"]))
_EUGO.plot_grid(zone_grid_un, plot_file_name; color_branches = true,    flows_ac = flows_ac, flows_dc = flows_dc, plot_node_numbers_ac = true, maximum_flows = false)   #; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc
#colormap = colormap,



##### Getting the generation from genrators ####

# results_folder = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/"
# base_filename  = "result_multiperiod.json"
# filename       = results_folder * base_filename       # full path
# if !isfile(filename)
#     error("Result file not found: $filename")
# end
# result = JSON.parsefile(filename)                     # Dict

nw = result["solution"]["nw"]                         # Dict{String,Any}

gen_dict = Dict{String, Vector{Float64}}()
for h in 1:8760
    hour_key = string(h)
    if !haskey(nw, hour_key) || !haskey(nw[hour_key], "gen")
        continue
    end
    for (gen_id, ginfo) in nw[hour_key]["gen"]
        pg = ginfo["pg"]                            # (per unit or MW)
        if !haskey(gen_dict, gen_id)
            gen_dict[gen_id] = fill(NaN, 8760)      # NaN for hours with no value
        end
        gen_dict[gen_id][h] = pg * 100              # scale if desired
    end
end

gen_sum_dict = Dict{String, Float64}()

for (gen_id, production_vector) in gen_dict
    gen_sum_dict[gen_id] = sum(production_vector)
end

# Step 2: Group generators by bidding zone
zone_sum_dict = Dict{String, Float64}()

for (gen_id, gen_data) in zone_grid_un["gen"]
    zone = gen_data["zone"]

    # Skip if generator is not in gen_sum_dict (e.g. it didn’t produce or isn’t in the OPF results)
    if !haskey(gen_sum_dict, gen_id)
        continue
    end

    gen_total = gen_sum_dict[gen_id]

    if !haskey(zone_sum_dict, zone)
        zone_sum_dict[zone] = 0.0
    end

    zone_sum_dict[zone] += gen_total
end

zones = collect(keys(zone_sum_dict))
sums = collect(values(zone_sum_dict))
XLSX.openxlsx("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_production_sums.xlsx", mode="w") do xf
    sheet = xf[1]  # First sheet
    sheet["A1"] = "Zone"
    sheet["B1"] = "Annual Production (MWhe)"
    
    for (i, (zone, sum)) in enumerate(zip(zones, sums))
        sheet["A$(i+1)"] = zone
        sheet["B$(i+1)"] = sum
    end
end


result_file = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json"

if !isfile(result_file)
    error("Result file not found: $result_file")
end
result_data = JSON.parsefile(result_file)
nw = result_data["solution"]["nw"]
load_dict = Dict{String, Vector{Float64}}()
for h in 1:8760
    h_str = string(h)
    if haskey(nw, h_str) && haskey(nw[h_str], "load")
        load_result = nw[h_str]["load"]

        for (load_id, vals) in load_result
            pflex = vals["pflex"]
            if !haskey(load_dict, load_id)
                load_dict[load_id] = fill(NaN, 8760)  # Optional: fill with NaN for gaps
            end
            load_dict[load_id][h] = pflex * 100       # Scale if needed
        end
    end
end


# Sum each load over 8760 hours
load_sum_dict = Dict(load_id => sum(pflex_vector) for (load_id, pflex_vector) in load_dict)

# Aggregate by bidding zone
load_zone_sum_dict = Dict{String, Float64}()

for (load_id, total_pflex) in load_sum_dict
    zone = zone_grid_un["load"][load_id]["zone"]
    load_zone_sum_dict[zone] = get(load_zone_sum_dict, zone, 0.0) + total_pflex
end

# Remove zones with 0 total flexible load
load_zone_sum_dict = Dict(k => v for (k, v) in load_zone_sum_dict if v > 0.0)

# Write to Excel
XLSX.openxlsx("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zone_load_sums.xlsx", mode="w") do xf
    sheet = xf[1]
    sheet["A1"] = "Zone"
    sheet["B1"] = "Total Flexible Load (MWhe)"
    
    i = 2
    for (zone, total_pflex) in load_zone_sum_dict
        sheet["A$(i)"] = zone
        sheet["B$(i)"] = total_pflex
        i += 1
    end
end



# Initialize new dictionary to hold only interconnectors
branch_interconnector = Dict{String, Dict{String, Any}}()

# Loop over each branch in the "branch" part of the dictionary
for (key, value) in zone_grid_un["branch"]
    if value["interconnector"] == true
        branch_interconnector[key] = value
    end
end

# Initialize empty dictionary for grouped data
zoned_data = Dict{String, Dict{String, Dict{String, Any}}}()

# Sections you want to group by zone
sections = ["bus", "gen", "load", "storage", "convdc", "busdc"]

# Loop through each section and group by "zone"
for section in sections
    if haskey(zone_grid_un, section)
        for (id, item) in zone_grid_un[section]
            if haskey(item, "zone")
                zone = string(item["zone"])  # convert zone to String
                # Create nested dictionaries if they don’t exist yet
                if !haskey(zoned_data, zone)
                    zoned_data[zone] = Dict{String, Dict{String, Any}}()
                end
                if !haskey(zoned_data[zone], section)
                    zoned_data[zone][section] = Dict{String, Any}()
                end
                # Add the item to the appropriate spot
                zoned_data[zone][section][string(id)] = item
            end
        end
    end
end

# Assuming zoned_data["IT-SICI"]["load"] is the dictionary you showed

load_data1 = zoned_data["IT-SICI"]["load"]

total_powerportion = sum(v["powerportion"] for v in values(load_data1))
total_pd = sum(v["pd"] for v in values(load_data1))
total_pmax = sum(v["pmax"] for v in values(load_data1))

println("Total powerportion: ", total_powerportion)
println("Total pd: ", total_pd)
println("Total pmax: ", total_pmax)


# ── Path to the result file ─────────────────────────────────────────────
results_folder = "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/"
base_filename = "result_multiperiod_1.json"
filename = results_folder * base_filename

# ── Parse the JSON file once ────────────────────────────────────────────
if !isfile(filename)
    error("File not found: $filename")
end
result = JSON.parsefile(filename)
nw = result["solution"]["nw"]

# ── Initialize the result dictionary: branch_id => Dict("pt" => [...], "pf" => [...])
branch_result = Dict{String, Dict{String, Vector{Float64}}}()

# ── Loop over all 8760 hours ────────────────────────────────────────────
for h in 1:8760
    h_str = string(h)

    if haskey(nw, h_str) && haskey(nw[h_str], "branch")
        branch_data = nw[h_str]["branch"]

        for (branch_id, branch_info) in branch_data
            pt = branch_info["pt"]
            pf = branch_info["pf"]

            # Check that this branch exists in the model
            if haskey(zone_grid_un["branch"], branch_id)
                # Initialize if first time
                if !haskey(branch_result, branch_id)
                    branch_result[branch_id] = Dict(
                        "pt" => fill(NaN, 8760),   # Or zeros(8760) if preferred
                        "pf" => fill(NaN, 8760)
                    )
                end

                branch_result[branch_id]["pt"][h] = pt * 100
                branch_result[branch_id]["pf"][h] = pf * 100
            end
        end
    end
end




# Create a new dictionary with zone info for each interconnector branch
branch_interconnector_results = Dict{String, Dict{String, Any}}()

for (branch_id, inter_data) in branch_interconnector
    if haskey(branch_result, branch_id)
        # Get f_bus and t_bus as Strings (zone_grid_un keys are strings)
        f_bus = string(inter_data["f_bus"])
        t_bus = string(inter_data["t_bus"])
        # Get zone from zone_grid_un
        zone_f = haskey(zone_grid_un["bus"], f_bus) ? zone_grid_un["bus"][f_bus]["zone"] : "UNKNOWN"
        zone_t = haskey(zone_grid_un["bus"], t_bus) ? zone_grid_un["bus"][t_bus]["zone"] : "UNKNOWN"
        # Add all data to the result dictionary
        branch_interconnector_results[branch_id] = Dict(
            "pt" => branch_result[branch_id]["pt"],
            "pf" => branch_result[branch_id]["pf"],
            "f_bus" => inter_data["f_bus"],
            "t_bus" => inter_data["t_bus"],
            "zone_f_bus" => zone_f,
            "zone_t_bus" => zone_t
        )
    end
end

branch_interconnector_results_by_zone = Dict{String, Dict{String, Dict{String, Any}}}()

for (branch_id, data) in branch_interconnector_results
    zone_f = data["zone_f_bus"]
    zone_t = data["zone_t_bus"]
    zone_pair = "$zone_f---$zone_t"
    if !haskey(branch_interconnector_results_by_zone, zone_pair)
        branch_interconnector_results_by_zone[zone_pair] = Dict{String, Dict{String, Any}}()
    end
    branch_interconnector_results_by_zone[zone_pair][branch_id] = data
end

branch_interconnector_sum_by_zone = Dict{String, Dict{String, Vector{Float64}}}()

for (zone_pair, branches) in branch_interconnector_results_by_zone
    pt_sum = nothing
    pf_sum = nothing
    for (_, data) in branches
        pt = data["pt"]
        pf = data["pf"]
        # Initialize with the first vector
        if pt_sum === nothing
            pt_sum = copy(pt)
            pf_sum = copy(pf)
        else
            pt_sum .+= pt
            pf_sum .+= pf
        end
    end
    branch_interconnector_sum_by_zone[zone_pair] = Dict(
        "pt" => pt_sum,
        "pf" => pf_sum
    )
end
total_ps_sum = sum(
    sum(st["ps"] for (_, st) in result["solution"]["nw"][string(t)]["storage"])
    for t in 1:8760
)








ac_branch_flows, dc_branch_flows, results = _EUGO.get_branch_flows_multiperiod(1, 8760, "/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/result_multiperiod_FENICE.json") 

flows_ac = Dict{String, Any}()
flows_dc = Dict{String, Any}()
for (b, branch) in ac_branch_flows
    flows_ac[b] = ac_branch_flows[b] ./ 10000
end

for (b, branch) in dc_branch_flows
    flows_dc[b] = dc_branch_flows[b] ./ 10000
end

using DataFrames, PlotlyJS, ColorSchemes

plot_file_name = file_name = joinpath("/Users/SEM2/.julia/dev/EU_grid_operations/results", "plots", join([use_case,"_",scenario,"_", climate_year,"_flows_aggregated.pdf"]))
#_EUGO.
_EUGO.plot_grid_with_arrows(zone_grid_un, plot_file_name;    flows_ac = ac_branch_flows, flows_dc = dc_branch_flows,)   #; color_branches = true, colormap = colormap, flows_ac = flows_ac, flows_dc = flows_dc
#colormap = colormap,

values_sum = Dict{String, Any}()
for (key, value) in flows_ac
    values_sum[key] = sum(value)
end

# === 1.  Convenience handles ============================================
branch_meta = zone_grid["branch"]    # Dict{String,Dict}
bus_meta    = zone_grid["bus"]       # Dict{String,Dict}
# === 2.  Prepare empty vectors for DataFrame =============================
branch_id  = String[]
net_flow   = Float64[]
f_bus_col  = Int[]
t_bus_col  = Int[]
zone_from  = String[]
zone_to    = String[]

# === 3.  Loop through every entry in values_sum ==========================
for (br_id, flow) in values_sum
    # Skip if branch not found in the network dictionary
    haskey(branch_meta, br_id) || continue
    br_info = branch_meta[br_id]
    f_bus   = br_info["f_bus"]
    t_bus   = br_info["t_bus"]
    # Look up zones for the two endpoint buses (fallback = "UNKNOWN")
    zone_f  = haskey(bus_meta, string(f_bus)) ? bus_meta[string(f_bus)]["zone"] : "UNKNOWN"
    zone_t  = haskey(bus_meta, string(t_bus)) ? bus_meta[string(t_bus)]["zone"] : "UNKNOWN"

    # Push to column vectors
    push!(branch_id,  br_id)
    push!(net_flow,   flow)
    push!(f_bus_col,  f_bus)
    push!(t_bus_col,  t_bus)
    push!(zone_from,  zone_f)
    push!(zone_to,    zone_t)
end
# === 4.  Assemble DataFrame =============================================
df_branches = DataFrame(
    BranchID = branch_id,
    NetFlow  = net_flow,
    F_bus    = f_bus_col,
    T_bus    = t_bus_col,
    Zone_F   = zone_from,
    Zone_T   = zone_to
)






values_sum_dc = Dict{String, Any}()
for (key, value) in flows_dc
    values_sum_dc[key] = sum(value)
end

# === 1.  Convenience handles ============================================
branch_meta = zone_grid["branchdc"]    # Dict{String,Dict}
bus_meta    = zone_grid["busdc"]       # Dict{String,Dict}
# === 2.  Prepare empty vectors for DataFrame =============================
branch_id  = String[]
net_flow   = Float64[]
f_bus_col  = Int[]
t_bus_col  = Int[]
zone_from  = Any[]
zone_to    = Any[]

# === 3.  Loop through every entry in values_sum ==========================
for (br_id, flow) in values_sum_dc
    # Skip if branch not found in the network dictionary
    haskey(branch_meta, br_id) || continue
    br_info = branch_meta[br_id]
    f_bus   = br_info["fbusdc"]
    t_bus   = br_info["tbusdc"]
    # Look up zones for the two endpoint buses (fallback = "UNKNOWN")
    zone_f  = haskey(bus_meta, string(f_bus)) ? bus_meta[string(f_bus)]["zone"] : "UNKNOWN"
    zone_t  = haskey(bus_meta, string(t_bus)) ? bus_meta[string(t_bus)]["zone"] : "UNKNOWN"

    # Push to column vectors
    push!(branch_id,  br_id)
    push!(net_flow,   flow)
    push!(f_bus_col,  f_bus)
    push!(t_bus_col,  t_bus)
    push!(zone_from,  zone_f)
    push!(zone_to,    zone_t)
end
# === 4.  Assemble DataFrame =============================================
df_branches_dc = DataFrame(
    BranchID = branch_id,
    NetFlow  = net_flow,
    F_bus    = f_bus_col,
    T_bus    = t_bus_col,
    Zone_F   = zone_from,
    Zone_T   = zone_to
)



CSV.write("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/merged_transmission_data_dc.csv", df_branches)
CSV.write("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/merged_transmission_data.csv", df_branches)




gen_SARD = Dict(g => gen for (g, gen) in zone_grid_un["gen"] if gen["zone"] == "IT-SA")
gen_SICI = Dict(g => gen for (g, gen) in zone_grid_un["gen"] if gen["zone"] == "IT-SICI")
gen_SICI_SOLAR = Dict(g => gen for (g, gen) in gen_SICI if gen["type_tyndp"] == "Solar PV")
gen_SICI_SOLAR_cap = sum(gen["pmax"] for (g, gen) in gen_SICI if gen["type_tyndp"] == "Solar PV")





# for (g, gen) in zone_grid_un["gen"]
#         zone = gen["zone"]

#         # Check if generator type exists in input data
#         if haskey(gen, "type")
#             type = gen["type"]
#         else
#             print(g, "\n")
#         end

#         # Calculate zonal capacity: For LU there are three different zones coming from the TYNDP data
#         zonal_tyndp_capacity = 0
#         if haskey(zone_mapping, zone)
#             tyndp_zones = zone_mapping[zone]
#         else
#             tyndp_zones = Dict{String, Any}()
#         end
#         for tyndp_zone in tyndp_zones
#             # obtain 
#             zonal_capacity = _EUGO.get_generation_capacity(tyndp_capacity, scenario, type, climate_year, tyndp_zone)
#             if !isempty(zonal_capacity)
#                 zonal_tyndp_capacity =  zonal_tyndp_capacity + zonal_capacity[1]
#                 print(zonal_tyndp_capacity)
#             end
#         end
#     end



# zones =[]

# for (g, gen) in EU_grid["gen"]
#         zone = gen["zone"]
#         print(zone)
#         push!(zones,zone)
# end
# unique(zones)


# gen_NORD = Dict(g => gen for (g, gen) in zone_grid_un["gen"] if gen["zone"] == "IT-NORD")
# gen_NORD_SOLAR = Dict(g => gen for (g, gen) in gen_NORD if gen["type_tyndp"] == "Solar PV")
# gen_NORD_SOLAR_cap = sum(gen["pmax"] for (g, gen) in gen_NORD if gen["type_tyndp"] == "Solar PV")

# gen_NORD = Dict(g => gen for (g, gen) in EU_grid["gen"] if gen["zone"] == "IT-NORD")
# gen_NORD_SOLAR = Dict(g => gen for (g, gen) in gen_NORD if gen["type_tyndp"] == "Solar PV")
# gen_NORD_SOLAR_cap = sum(gen["pmax"] for (g, gen) in gen_NORD if gen["type_tyndp"] == "Solar PV")








# ---- Step 1: Get the list of all branch IDs from the first hour
branches = collect(keys(zonal_result["1"]["solution"]["branch"]))
branch_pt_data = Dict(b => Float64[] for b in branches)

for hour in 1:8760
    for b in branches
        push!(branch_pt_data[b], zonal_result[string(hour)]["solution"]["branch"][b]["pf"]/10)
    end
end

df = DataFrame(branch_pt_data)

df_header = DataFrame()
for b in branches
    f = zonal_input["branch"][b]["f_bus"]
    t = zonal_input["branch"][b]["t_bus"]
    n = zonal_input["branch"][b]["name"]
    df_header[!, b] = [f, t, n]  # add column named `b`
end

common_cols = intersect(names(df_header), names(df))
df_combined = vcat(df_header[:, common_cols], df[:, common_cols])

CSV.write("/Users/SEM2/.julia/dev/EU_grid_operations/results/TYNDP2024/zonal_branches_results.csv", df_combined)

