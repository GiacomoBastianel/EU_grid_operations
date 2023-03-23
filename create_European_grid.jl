# Script to create the European grid
# Refer to Tosatto's paper
# 7th March 2023

using Ipopt
using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using XLSX
using JSON

#using CSV
#using DataFrames; const _DF = DataFrames
#using JSON
#using PowerModelsAnalytics
#import ExcelFiles; const _EF = ExcelFiles
#using PowerPlots
#using Plots
#using DataFrames
#using XLSX
#using Tables
#using GMT
#using HTTP
#using PlotlyJS

# Uploading an example test system
test_file = "case5_acdc.m"
test_grid = _PM.parse_file(test_file)

# Calling the Excel file
xf = XLSX.readxlsx(joinpath(@__DIR__,"GRID_MODEL.xlsx"))
XLSX.sheetnames(xf)

# Creating a European grid dictionary in PowerModels format
European_grid = Dict{String,Any}()
European_grid["dcpol"] = 2
European_grid["name"] = "European_grid"
European_grid["baseMVA"] = 100
European_grid["per_unit"] = true

# Buses
buses_dict = xf["BUS"]["A2:Q6127"]
buses_names = buses_dict[:,1]

European_grid["bus"] = Dict{String,Any}()
for i in 1:length(buses_names)
    European_grid["bus"]["$i"] = Dict{String,Any}()
    European_grid["bus"]["$i"]["name"] = buses_dict[:,1][i]
    European_grid["bus"]["$i"]["index"] = i
    European_grid["bus"]["$i"]["bus_i"] = buses_dict[:,2][i]
    European_grid["bus"]["$i"]["bus_type"] = buses_dict[:,3][i]
    European_grid["bus"]["$i"]["pd"] = buses_dict[:,4][i]
    European_grid["bus"]["$i"]["qd"] = buses_dict[:,5][i]
    European_grid["bus"]["$i"]["gs"] = buses_dict[:,6][i]
    European_grid["bus"]["$i"]["bs"] = buses_dict[:,7][i]
    European_grid["bus"]["$i"]["area"] = buses_dict[:,8][i]
    European_grid["bus"]["$i"]["vm"] = buses_dict[:,9][i]
    European_grid["bus"]["$i"]["va"] = buses_dict[:,10][i]
    European_grid["bus"]["$i"]["base_kv"] = buses_dict[:,11][i]
    European_grid["bus"]["$i"]["zone"] = buses_dict[:,12][i]
    European_grid["bus"]["$i"]["vmax"] = buses_dict[:,13][i]
    European_grid["bus"]["$i"]["vmin"] = buses_dict[:,14][i]
    European_grid["bus"]["$i"]["lat"] = buses_dict[:,16][i]
    European_grid["bus"]["$i"]["lon"] = buses_dict[:,17][i]
    European_grid["bus"]["$i"]["source_id"] = []
    push!(European_grid["bus"]["$i"]["source_id"],"bus")
    push!(European_grid["bus"]["$i"]["source_id"],i)
end
# The last two buses are north sea energy island buses
# 5930 - 6125 are interconnection buses

# Bus dc -> it can be commented out if you want to keep only the AC system
buses_dc_dict = xf["BUS_DC"]["A2:Q210"]
buses_dc_names = buses_dc_dict[:,1]

European_grid["busdc"] = Dict{String,Any}()
for i in 1:length(buses_dc_names)
    European_grid["busdc"]["$i"] = Dict{String,Any}()
    European_grid["busdc"]["$i"]["name"] = buses_dc_dict[:,1][i]
    European_grid["busdc"]["$i"]["index"] = i
    European_grid["busdc"]["$i"]["busdc_i"] = buses_dc_dict[:,2][i]
    European_grid["busdc"]["$i"]["bus_type"] = buses_dc_dict[:,3][i]
    European_grid["busdc"]["$i"]["pd"] = buses_dc_dict[:,4][i]
    European_grid["busdc"]["$i"]["qd"] = buses_dc_dict[:,5][i]
    European_grid["busdc"]["$i"]["gs"] = buses_dc_dict[:,6][i]
    European_grid["busdc"]["$i"]["bs"] = buses_dc_dict[:,7][i]
    European_grid["busdc"]["$i"]["area"] = buses_dc_dict[:,8][i]
    European_grid["busdc"]["$i"]["vm"] = buses_dc_dict[:,9][i]
    European_grid["busdc"]["$i"]["va"] = buses_dc_dict[:,10][i]
    European_grid["busdc"]["$i"]["basekVdc"] = buses_dc_dict[:,11][i]
    European_grid["busdc"]["$i"]["zone"] = buses_dc_dict[:,12][i]
    European_grid["busdc"]["$i"]["Vdcmax"] = buses_dc_dict[:,13][i]
    European_grid["busdc"]["$i"]["Vdcmin"] = buses_dc_dict[:,14][i]
    European_grid["busdc"]["$i"]["lat"] = buses_dc_dict[:,16][i]
    European_grid["busdc"]["$i"]["lon"] = buses_dc_dict[:,17][i]
    European_grid["busdc"]["$i"]["Vdc"] = 1
    European_grid["busdc"]["$i"]["Pdc"] = 0
    European_grid["busdc"]["$i"]["Cdc"] = 0
    European_grid["busdc"]["$i"]["source_id"] = []
    push!(European_grid["busdc"]["$i"]["source_id"],"busdc")
    push!(European_grid["busdc"]["$i"]["source_id"],i)
end

# Branches
branches_dict = xf["BRANCH"]["A2:O8859"]
branches_types = branches_dict[:,2]

European_grid["branch"] = Dict{String,Any}()
for i in 1:length(branches_types)
    European_grid["branch"]["$i"] = Dict{String,Any}()
    European_grid["branch"]["$i"]["type"] = branches_dict[:,2][i]
    if European_grid["branch"]["$i"]["type"] ==  "AC line"
        European_grid["branch"]["$i"]["transformer"] = false
    else
        European_grid["branch"]["$i"]["transformer"] = true
    end
    European_grid["branch"]["$i"]["index"] = i
    if ismissing(branches_dict[:,1][i])
        European_grid["branch"]["$i"]["interconnector"] = false
    else
        European_grid["branch"]["$i"]["interconnector"] = true
    end
    European_grid["branch"]["$i"]["f_bus"] = branches_dict[:,3][i]
    European_grid["branch"]["$i"]["t_bus"] = branches_dict[:,4][i]
    European_grid["branch"]["$i"]["br_r"] = branches_dict[:,5][i]
    European_grid["branch"]["$i"]["br_x"] = branches_dict[:,6][i]
    European_grid["branch"]["$i"]["b_fr"] = branches_dict[:,7][i]
    European_grid["branch"]["$i"]["b_to"] = branches_dict[:,7][i]
    European_grid["branch"]["$i"]["g_fr"] = 0.0
    European_grid["branch"]["$i"]["g_to"] = 0.0
    European_grid["branch"]["$i"]["rate_a"] = branches_dict[:,8][i]/European_grid["baseMVA"]  #Adjusting with pu values
    European_grid["branch"]["$i"]["rate_b"] = branches_dict[:,9][i]/European_grid["baseMVA"] 
    European_grid["branch"]["$i"]["rate_c"] = branches_dict[:,10][i]/European_grid["baseMVA"] 
    European_grid["branch"]["$i"]["ratio"] = branches_dict[:,11][i]
    European_grid["branch"]["$i"]["angmin"] = deepcopy(test_grid["branch"]["1"]["angmin"])
    European_grid["branch"]["$i"]["angmax"] = deepcopy(test_grid["branch"]["1"]["angmax"])
    European_grid["branch"]["$i"]["br_status"] = 1
    European_grid["branch"]["$i"]["tap"] = 1.0
    European_grid["branch"]["$i"]["transformer"] = false
    European_grid["branch"]["$i"]["shift"] = 0.0
    European_grid["branch"]["$i"]["source_id"] = []
    push!(European_grid["branch"]["$i"]["source_id"],"branch")
    push!(European_grid["branch"]["$i"]["source_id"],i)
end

# DC Branches
branches_dc_dict = xf["BRANCH_DC"]["A2:M102"]
branches_dc_types = branches_dc_dict[:,2]

European_grid["branchdc"] = Dict{String,Any}()
for i in 1:length(branches_dc_types)
    European_grid["branchdc"]["$i"] = Dict{String,Any}()
    European_grid["branchdc"]["$i"]["type"] = branches_dc_dict[:,2][i]
    European_grid["branchdc"]["$i"]["name"] = branches_dc_dict[:,1][i]
    European_grid["branchdc"]["$i"]["index"] = i
    European_grid["branchdc"]["$i"]["fbusdc"] = branches_dc_dict[:,3][i]
    European_grid["branchdc"]["$i"]["tbusdc"] = branches_dc_dict[:,4][i]
    European_grid["branchdc"]["$i"]["r"] = branches_dc_dict[:,5][i]
    European_grid["branchdc"]["$i"]["c"] = branches_dc_dict[:,6][i]
    European_grid["branchdc"]["$i"]["l"] = branches_dc_dict[:,7][i]
    European_grid["branchdc"]["$i"]["status"] = 1
    European_grid["branchdc"]["$i"]["rateA"] = branches_dc_dict[:,8][i]/European_grid["baseMVA"]  #Adjusting with pu values
    European_grid["branchdc"]["$i"]["rateB"] = branches_dc_dict[:,9][i]/European_grid["baseMVA"] 
    European_grid["branchdc"]["$i"]["rateC"] = branches_dc_dict[:,10][i]/European_grid["baseMVA"] 
    European_grid["branchdc"]["$i"]["ratio"] = branches_dc_dict[:,11][i]
    European_grid["branchdc"]["$i"]["source_id"] = []
    push!(European_grid["branchdc"]["$i"]["source_id"],"branchdc")
    push!(European_grid["branchdc"]["$i"]["source_id"],i)
end

# DC Converters
conv_dc_dict = xf["CONVERTER"]["A2:L210"]
conv_dc_types = conv_dc_dict[:,2]

European_grid["convdc"] = Dict{String,Any}()
for i in 1:length(conv_dc_types)
    European_grid["convdc"]["$i"] = Dict{String,Any}()
    European_grid["convdc"]["$i"] = deepcopy(test_grid["convdc"]["1"])
    European_grid["convdc"]["$i"]["busdc_i"] = conv_dc_dict[:,3][i]
    European_grid["convdc"]["$i"]["busac_i"] = conv_dc_dict[:,2][i]
    European_grid["convdc"]["$i"]["index"] = i
    if ismissing(conv_dc_dict[:,1][i])
        European_grid["convdc"]["$i"]["interconnector"] = false
    else
        European_grid["convdc"]["$i"]["interconnector"] = true
    end
    European_grid["convdc"]["$i"]["rtf"] = conv_dc_dict[:,4][i]
    European_grid["convdc"]["$i"]["rc"] = conv_dc_dict[:,4][i]
    European_grid["convdc"]["$i"]["xtf"] = 0.001 #conv_dc_dict[:,5][i]
    European_grid["convdc"]["$i"]["xc"] = 0.001#conv_dc_dict[:,5][i]
    European_grid["convdc"]["$i"]["bf"] = conv_dc_dict[:,6][i]
    European_grid["convdc"]["$i"]["status"] = 1
    European_grid["convdc"]["$i"]["Pacmax"] = conv_dc_dict[:,7][i]/European_grid["baseMVA"]  #Adjusting with pu values
    European_grid["convdc"]["$i"]["Pacmin"] = -conv_dc_dict[:,7][i]/European_grid["baseMVA"]  #Adjusting with pu values
    European_grid["convdc"]["$i"]["Pg"] = 0.0 #Adjusting with pu values
    European_grid["convdc"]["$i"]["ratio"] = conv_dc_dict[:,10][i]
    European_grid["convdc"]["$i"]["transformer"] = 1
    European_grid["convdc"]["$i"]["reactor"] = 1
    European_grid["convdc"]["$i"]["source_id"] = []
    push!(European_grid["convdc"]["$i"]["source_id"],"convdc")
    push!(European_grid["convdc"]["$i"]["source_id"],i)
end

# Load
load_dict = xf["DEMAND"]["A2:E3443"]
load_types = load_dict[:,2]

European_grid["load"] = Dict{String,Any}()
for i in 1:length(load_types)
    European_grid["load"]["$i"] = Dict{String,Any}()
    European_grid["load"]["$i"]["country"] = load_dict[:,1][i]
    European_grid["load"]["$i"]["zone"] = load_dict[:,2][i]
    European_grid["load"]["$i"]["load_bus"] = load_dict[:,3][i]
    European_grid["load"]["$i"]["pmax"] = load_dict[:,4][i]/European_grid["baseMVA"] 
    if load_dict[:,5][i] == "-"
        European_grid["load"]["$i"]["cosphi"] = 1
    else
        European_grid["load"]["$i"]["cosphi"] = load_dict[:,5][i]
    end
    European_grid["load"]["$i"]["pd"] = load_dict[:,4][i]/European_grid["baseMVA"] 
    European_grid["load"]["$i"]["qd"] = load_dict[:,4][i]/European_grid["baseMVA"]  * sqrt(1 - European_grid["load"]["$i"]["cosphi"]^2)
    European_grid["load"]["$i"]["index"] = i
    European_grid["load"]["$i"]["status"] = 1
    European_grid["load"]["$i"]["source_id"] = []
    push!(European_grid["load"]["$i"]["source_id"],"bus")
    push!(European_grid["load"]["$i"]["source_id"],i)
end

# Including load
load_peak_dict = xf["DEMAND_OVERVIEW"]["A2:B44"]
load_peak_name = load_peak_dict[:,1]
load_peak_power = load_peak_dict[:,2]

for (l_id,l) in European_grid["load"]
    for i in 1:length(load_peak_name)
        if l["zone"] == load_peak_name[i]
            l["country_peak_load"] = load_peak_power[i]/European_grid["baseMVA"] 
        end
    end
    l["powerportion"] = l["pmax"]/l["country_peak_load"]
end


# Generators to be added -> GEN conventional
# RES on the side
gen_hydro_ror_dict = xf["ROR"]["A2:F650"]
gen_hydro_ror_types = gen_hydro_ror_dict[:,2]

European_grid["gen"] = Dict{String,Any}()
for i in 1:length(gen_hydro_ror_types)
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = gen_hydro_ror_dict[:,2][i]
    European_grid["gen"]["$i"]["country"] = gen_hydro_ror_dict[:,3][i]
    European_grid["gen"]["$i"]["zone"] = gen_hydro_ror_dict[:,4][i]
    European_grid["gen"]["$i"]["gen_bus"] = gen_hydro_ror_dict[:,5][i]
    European_grid["gen"]["$i"]["type"] = "Run-of-River"
    European_grid["gen"]["$i"]["pmax"] = gen_hydro_ror_dict[:,6][i]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [60.0,0.0] # Assumption here, to be checked
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end

gen_hydro_res_dict = xf["RES"]["A2:H401"]
gen_hydro_res_types = gen_hydro_res_dict[:,2]

l = 0
for i in (length(gen_hydro_ror_types)+1):(length(gen_hydro_ror_types)+length(gen_hydro_res_types))
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = i
    global l += 1
    European_grid["gen"]["$i"]["country"] = gen_hydro_res_dict[:,3][l]
    European_grid["gen"]["$i"]["zone"] = gen_hydro_res_dict[:,4][l]
    European_grid["gen"]["$i"]["gen_bus"] = gen_hydro_res_dict[:,5][l]
    European_grid["gen"]["$i"]["type"] = "Reservoir"
    European_grid["gen"]["$i"]["pmax"] = gen_hydro_res_dict[:,6][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["storage"] = gen_hydro_res_dict[:,7][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [65.0,0.0] # Assumption here, to be checked
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end

gen_conv_dict = xf["GEN"]["A2:M1230"]
gen_conv_types = gen_conv_dict[:,2]

l = 0
for i in (length(gen_hydro_ror_types)+length(gen_hydro_res_types)+1):(length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types))
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = i
    global l += 1
    European_grid["gen"]["$i"]["country"] = gen_conv_dict[:,4][l]
    European_grid["gen"]["$i"]["zone"] = gen_conv_dict[:,5][l]
    European_grid["gen"]["$i"]["gen_bus"] = gen_conv_dict[:,6][l]
    if gen_conv_dict[:,3][l] == "Biomass"
        European_grid["gen"]["$i"]["type"] = "Lignite old 1 Bio"
    elseif gen_conv_dict[:,3][l] == "Gas"
        European_grid["gen"]["$i"]["type"] = "Gas CCGT new"
    elseif gen_conv_dict[:,3][l] == "Hard Coal"
        European_grid["gen"]["$i"]["type"] = "Hard coal old 2 Bio"
    elseif gen_conv_dict[:,3][l] == "Lignite"
        European_grid["gen"]["$i"]["type"] = "Lignite old 1"
    elseif gen_conv_dict[:,3][l] == "Nuclear"
        European_grid["gen"]["$i"]["type"] = "Nuclear"
    elseif gen_conv_dict[:,3][l] == "Oil"
        European_grid["gen"]["$i"]["type"] = "Heavy oil old 1 Bio"
    end
    European_grid["gen"]["$i"]["pmax"] = gen_conv_dict[:,7][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [gen_conv_dict[:,12][l],0.0] # Without CO2
    European_grid["gen"]["$i"]["marginal_cost"] = gen_conv_dict[:,10][l]
    European_grid["gen"]["$i"]["CO2_cost"] = gen_conv_dict[:,11][l]
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end


gen_onshore_wind_dict = xf["ONSHORE"]["A2:F2044"]
gen_onshore_wind_types = gen_onshore_wind_dict[:,2]

l = 0
for i in (length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+1):(length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+length(gen_onshore_wind_types))
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = i
    global l += 1
    European_grid["gen"]["$i"]["country"] = gen_onshore_wind_dict[:,3][l]
    European_grid["gen"]["$i"]["zone"] = gen_onshore_wind_dict[:,4][l]
    European_grid["gen"]["$i"]["gen_bus"] = gen_onshore_wind_dict[:,5][l]
    European_grid["gen"]["$i"]["type"] = "Onshore Wind"
    European_grid["gen"]["$i"]["pmax"] = gen_onshore_wind_dict[:,6][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [25.0,0.0] 
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end


gen_offshore_wind_dict = xf["OFFSHORE"]["A2:F131"]
gen_offshore_wind_types = gen_offshore_wind_dict[:,2]

l = 0
for i in (length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+length(gen_onshore_wind_types)+1):(length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+length(gen_onshore_wind_types)+length(gen_offshore_wind_types))
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = i
    global l += 1
    European_grid["gen"]["$i"]["country"] = gen_offshore_wind_dict[:,3][l]
    European_grid["gen"]["$i"]["zone"] = gen_offshore_wind_dict[:,4][l]
    European_grid["gen"]["$i"]["gen_bus"] = gen_offshore_wind_dict[:,5][l]
    European_grid["gen"]["$i"]["type"] = "Offshore Wind"
    European_grid["gen"]["$i"]["pmax"] = gen_offshore_wind_dict[:,6][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [59.0,0.0] 
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end


gen_solar_dict = xf["SOLAR"]["A2:F3195"]
gen_solar_types = gen_solar_dict[:,2]

l = 0
for i in (length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+length(gen_onshore_wind_types)+length(gen_offshore_wind_types)+1):(length(gen_hydro_ror_types)+length(gen_hydro_res_types)+length(gen_conv_types)+length(gen_onshore_wind_types)+length(gen_offshore_wind_types)+length(gen_solar_types))
    European_grid["gen"]["$i"] = Dict{String,Any}()
    European_grid["gen"]["$i"]["index"] = i
    global l += 1
    European_grid["gen"]["$i"]["country"] = gen_solar_dict[:,3][l]
    European_grid["gen"]["$i"]["zone"] = gen_solar_dict[:,4][l]
    European_grid["gen"]["$i"]["gen_bus"] = gen_solar_dict[:,5][l]
    European_grid["gen"]["$i"]["type"] = "Solar PV"
    European_grid["gen"]["$i"]["pmax"] = gen_solar_dict[:,6][l]/European_grid["baseMVA"] 
    European_grid["gen"]["$i"]["pmin"] = 0.0
    European_grid["gen"]["$i"]["qmax"] = 0.0
    European_grid["gen"]["$i"]["qmin"] = 0.0
    European_grid["gen"]["$i"]["cost"] = [18.0,0.0] 
    European_grid["gen"]["$i"]["ncost"] = 2
    European_grid["gen"]["$i"]["model"] = 2
    European_grid["gen"]["$i"]["gen_status"] = 1
    European_grid["gen"]["$i"]["vg"] = 1.0
    European_grid["gen"]["$i"]["source_id"] = []
    push!(European_grid["gen"]["$i"]["source_id"],"gen")
    push!(European_grid["gen"]["$i"]["source_id"],i)
end

#######
zone_names = xf["BUS_OVERVIEW"]["F2:F43"]
European_grid["zonal_generation_capacity"] = Dict{String, Any}()
European_grid["zonal_peak_demand"] = Dict{String, Any}()

for zone in zone_names
    idx = findfirst(zone .== zone_names)
    # Generation
    European_grid["zonal_generation_capacity"][zone] = Dict{String, Any}()
        # Wind
        European_grid["zonal_generation_capacity"][zone]["Onshore Wind"] =  xf["WIND_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Offshore Wind"] =  xf["WIND_OVERVIEW"]["C2:C43"][idx]/European_grid["baseMVA"]
        # PV
        European_grid["zonal_generation_capacity"][zone]["Solar PV"] =  xf["SOLAR_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
        # Hydro
        European_grid["zonal_generation_capacity"][zone]["Run-of-River"] =  xf["HYDRO_OVERVIEW"]["B3:B44"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Reservoir"] =  xf["HYDRO_OVERVIEW"]["C3:C44"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Reservoir capacity"] =  xf["HYDRO_OVERVIEW"]["D3:D44"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["PHS"] =  xf["HYDRO_OVERVIEW"]["E3:E44"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["PHS capacity"] =  xf["HYDRO_OVERVIEW"]["F3:F44"][idx]/European_grid["baseMVA"]
        # Thermal
        European_grid["zonal_generation_capacity"][zone]["Biomass"] =  xf["THERMAL_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Gas CCGT new"] =  xf["THERMAL_OVERVIEW"]["C2:C43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Hard coal old 2 Bio"] =  xf["THERMAL_OVERVIEW"]["D2:D43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Lignite old 1"] =  xf["THERMAL_OVERVIEW"]["E2:E43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Nuclear"] =  xf["THERMAL_OVERVIEW"]["F2:F43"][idx]/European_grid["baseMVA"]
        European_grid["zonal_generation_capacity"][zone]["Heavy oil old 1 Bio"] =  xf["THERMAL_OVERVIEW"]["G2:G43"][idx]/European_grid["baseMVA"]
    # Demand
    European_grid["zonal_peak_demand"][zone] = xf["THERMAL_OVERVIEW"]["B2:B43"][idx]/European_grid["baseMVA"]
end
######
European_grid["source_type"] = deepcopy(test_grid["source_type"])
European_grid["switch"] = deepcopy(test_grid["switch"])
European_grid["storage"] = deepcopy(test_grid["storage"])
European_grid["shunt"] = deepcopy(test_grid["shunt"])
European_grid["dcline"] = deepcopy(test_grid["dcline"])

# Fixing NaN branches
European_grid["branch"]["6282"]["br_r"] = 0.001
European_grid["branch"]["8433"]["br_r"] = 0.001
European_grid["branch"]["8439"]["br_r"] = 0.001
European_grid["branch"]["8340"]["br_r"] = 0.001



string_data = JSON.json(European_grid)
open(joinpath(@__DIR__,"European_grid.json"),"w" ) do f
    write(f,string_data)
end
