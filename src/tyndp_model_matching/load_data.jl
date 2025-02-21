# Loading data from the tyndpdata folder installed on the Desktop of the user (data confidetiality)

###############################################################
#  load_data.jl
#############################################################################

function load_res_data()
 ## RES TIME SERIES as feather files (~ 350 MB)
 # DOWNLOAD FILES AND ADD THEM TO YOUR data_sources FOLDER
 # wind_onshore_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOnshore.feather?download=1"
 # wind_offhore_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOffshore.feather?download=1"
 # pv_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-PV.feather?download=1" 

 path = BASE_DIR
 # If files are saved locally under folder scenarios
 file_wind_onshore  = joinpath(path, "data_sources", "PECD-MAF2019-wide-WindOnshore.feather")
 file_wind_offshore = joinpath(path, "data_sources", "PECD-MAF2019-wide-WindOffshore.feather")
 file_pv            = joinpath(path, "data_sources", "PECD-MAF2019-wide-PV.feather")                 

 pv = Feather.read(file_pv) 
 wind_onshore = Feather.read(file_wind_onshore)
 wind_offshore = Feather.read(file_wind_offshore)
 # Alternatively one can use to download data: (this might take a couple of minutes)
 # pv = Feather.read(download(pv_file_link))
 # wind_onshore = Feather.read(download(wind_onshore_file_link))
 # wind_offshore = Feather.read(download(wind_offshore_file_link))

 return pv, wind_onshore, wind_offshore
end

function process_RES_time_series(wind_onshore,wind_offshore,pv,corrected_year) # corrected year makes sure you are calling the right year from the Feather files, it is defined as corrected_year = parse(Int64,year) - 1982 + 5 # 1982 corresponds to the 5th column
    RES_zones = Dict{String,Any}()
    l = 0
    zones = unique(wind_onshore[:,1])
    for i in 1:length(zones) 
        c = deepcopy(zones[i])
        RES_zones["$c"] = Dict{String,Any}()
        RES_zones["$c"]["Onshore wind"] = deepcopy(wind_onshore[:,corrected_year][(1+8760*l):(8760+8760*l)])
        RES_zones["$c"]["Offshore wind"] = deepcopy(wind_offshore[:,corrected_year][(1+8760*l):(8760+8760*l)])
        RES_zones["$c"]["Solar PV"] = deepcopy(pv[:,corrected_year][(1+8760*l):(8760+8760*l)])
        l += 1
    end
    for i in eachindex(RES_zones)
        if ismissing(RES_zones[i]["Offshore wind"][1])
            RES_zones[i]["Offshore wind"] = deepcopy(RES_zones["FR00"]["Offshore wind"])
        end
        if ismissing(RES_zones[i]["Onshore wind"][1])
            RES_zones[i]["Onshore wind"] = deepcopy(RES_zones["FR00"]["Onshore wind"])
        end
        if ismissing(RES_zones[i]["Solar PV"][1])
            RES_zones[i]["Solar PV"] = deepcopy(RES_zones["FR00"]["Solar PV"])
        end
    end
    return RES_zones
end

function add_load_series(scenario,year,hour_start,number_of_hours)
    load_file = joinpath("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/"*scenario*"_Demand_CY"*year*".csv")
    df = CSV.read(load_file,DataFrame)
    demand_zones = Dict{String,Any}()
    for l in 5:length(names(df))
        name_zone = names(df)[l]
        #b = df[:,l][hour_start:(hour_start+number_of_hours-1)]
        #b = df[:,5][1:1+number_of_hours-1]
        demand_zones["$name_zone"] = []
        for i in hour_start:(hour_start+number_of_hours-1)
            if typeof(df[:,l][i]) == Float64
                push!(demand_zones["$name_zone"],df[:,l][i]) #df[:,l][hour_start:(hour_start+number_of_hours-1)]
            else 
                new_value = convert(Float64,df[:,l][i])
                push!(demand_zones["$name_zone"],new_value)
            end
        end
        #for m in 1:length(demand_zones["$name_zone"])
        #    convert(Float64, demand_zones["$name_zone"][m])
        #end
    end
    demand_zones["LU00"] = deepcopy(demand_zones["LUG1"])
    delete!(demand_zones,"LUG1")
    return demand_zones
end


function add_data_gen(gen_costs, emission_factor, inertia_constants, start_up_cost, data)
    for (i_id,i) in data["gen"]
        for l in eachindex(gen_costs)
              if i["type"] == l
               i["cost"] = deepcopy(gen_costs[l])
               i["CO2_emission"] = deepcopy(emission_factor[l])
               i["inertia_constant"] = deepcopy(inertia_constants[l])
               i["start_up_cost"] = deepcopy(start_up_cost[l])
              end
        end
    end
end

function adjust_time_series(RES_time_series)
    RES_time_series_adjusted = deepcopy(RES_time_series)
    for i in keys(RES_time_series)
    if i[1:2] == "ES" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "FR" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "DE" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "UK" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "BE" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "PT" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "DK" && i[3:4] != "E1"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "PL" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "NL" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "CZ" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "IT" && i[3:4] != "S1"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "AT" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    #if i[1:2] == "LU" && i[3:4] != "G1"
    #    delete!(RES_time_series_adjusted,i)
    #end
    if i[1:2] == "BG" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "NO" && i[3:4] != "S0"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "RO" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "SE" && i[3:4] != "01"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "GR" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "UA" && i[3:4] != "01"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "HU" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "FI" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "RS" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    if i[1:2] == "HR" && i[3:4] != "00"
        delete!(RES_time_series_adjusted,i)
    end
    end
    return RES_time_series_adjusted
end

function zones_alignment(data)
    for (g_id,g) in data["gen"]
    if length(g["zone"]) == 2
        b = g["zone"]
        g["zone"] = b*"00"
    end
    if g["zone"] == "IT-CNOR"
        g["zone"] = "ITCN"
    elseif g["zone"] == "IT-SICI"
        g["zone"] = "ITSI"
    elseif g["zone"] == "IT-CSUD"
        g["zone"] = "ITCS"
    elseif g["zone"] == "IT-NORD"
        g["zone"] = "ITN1"
    elseif g["zone"] == "IT-SUD"
        g["zone"] = "ITS1"
    elseif g["zone"] == "DE-LU"
        g["zone"] = "DE00"
    elseif g["zone"] == "NO01"
        g["zone"] = "NOS0"
    elseif g["zone"] == "NO02"
        g["zone"] = "NOM1"
    elseif g["zone"] == "NO03"
        g["zone"] = "NON1"
    elseif g["zone"] == "DK01"
        g["zone"] = "DKE1"
    elseif g["zone"] == "DK02"
        g["zone"] = "DKW1"
    elseif length(g["zone"]) == 3
        zone = g["zone"]
        g["zone"] = zone[1:2]*"0"*zone[3:3]
    end
    end

    for (g_id,g) in data["load"]
    if length(g["zone"]) == 2
        b = g["zone"]
        g["zone"] = b*"00"
    end
    if g["zone"] == "IT-CNOR"
        g["zone"] = "ITCN"
    elseif g["zone"] == "IT-SICI"
        g["zone"] = "ITSI"
    elseif g["zone"] == "IT-CSUD"
        g["zone"] = "ITCS"
    elseif g["zone"] == "IT-NORD"
        g["zone"] = "ITN1"
    elseif g["zone"] == "IT-SUD"
        g["zone"] = "ITS1"
    elseif g["zone"] == "DK01"
        g["zone"] = "DKE1"
    elseif g["zone"] == "DK02"
        g["zone"] = "DKW1"
    elseif g["zone"] == "NO01"
        g["zone"] = "NOS0"
    elseif g["zone"] == "NO02"
        g["zone"] = "NOM1"
    elseif g["zone"] == "NO03"
        g["zone"] = "NON1"
    elseif length(g["zone"]) == 3
        zone = g["zone"]
        g["zone"] = zone[1:2]*"0"*zone[3:3]
    end
    end
    return data
end

function include_RES_and_load(data,data_hour,RES_series,load_zones,hour)
    for (g_id,g) in data["gen"]
        for i in eachindex(RES_series)
            if g["zone"][1:2] == i[1:2]
                if g["type_tyndp"] == "Solar PV"
                    data_hour["gen"][g_id]["pmax"] = g["pmax"]*RES_series["$i"]["Solar PV"][hour]
                elseif g["type_tyndp"] == "Offshore Wind"
                    data_hour["gen"][g_id]["pmax"] = g["pmax"]*RES_series["$i"]["Offshore wind"][hour]
                elseif g["type_tyndp"] == "Onshore Wind"
                    data_hour["gen"][g_id]["pmax"] = g["pmax"]*RES_series["$i"]["Onshore wind"][hour]
                end
            end
        end
    end
    for (g_id,g) in data["load"]
        for i in eachindex(load_zones)
            if g["zone"] == i
                if data_hour["load"][g_id]["pmax"] != 0.0 
                    data_hour["load"][g_id]["pmax"] = load_zones["$i"][hour]/100*g["powerportion"]
                end
            end
        end
    end
    return data_hour
end

function turn_off_high_curt_loads(data)
    data["load"]["2682"]["status"] = 0
    data["load"]["2684"]["status"] = 0
    data["load"]["2685"]["status"] = 0
    data["load"]["2686"]["status"] = 0
    data["load"]["2192"]["status"] = 0
    data["load"]["2679"]["status"] = 0
end