function add_offshore_wind_farms!(input_data)
    wind_farms = Dict{String,Any}()
    xf = XLSX.readxlsx(joinpath("./data_sources/offshore_wind_farms.xlsx"))
    XLSX.sheetnames(xf)
    for r in XLSX.eachrow(xf["OWFHUBS"])
        i = XLSX.row_number(r)
        if i > 1 # compensate for header
            wind_farms["$i"] = Dict{String,Any}()
            zone = r[1]
            wind_farms["$i"]["zone"] = deepcopy(zone)
            rating = r[2]
            wind_farms["$i"]["rating"] = deepcopy(rating/10^2) #pu
            lat = r[3]
            wind_farms["$i"]["lat"] = deepcopy(lat)
            lon = r[4]
            wind_farms["$i"]["lon"] = deepcopy(lon)
            cost = 0 * input_data["baseMVA"]
            #add_bus!(input_data, zone, lat, lon)
            #node = maximum([bus["index"] for (b, bus) in input_data["bus"]])
            print(zone, "\n")
            #add_gen!(input_data, zone, cost, node, rating, "Offshore Wind")
        end
    end

    return input_data, wind_farms
end



function run_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting)
    zone_grid_hourly = deepcopy(zone_grid)
    result = Dict{String, Any}(["$hour" => Dict{String, Any}() for hour in hour_start_idx : hour_end_idx])
    for hour_idx in hour_start_idx : hour_end_idx
        hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
        result["$hour_idx"] = _PMACDC.run_acdcopf(zone_grid_hourly, _PM.DCPPowerModel, solver; setting = setting) # solve the OPF 
    end 
    
    return result
end
