# To Do: This should be part of the package later, but then would require CBAOPF as dependency. Therefore CBAOPF to be registered first.
function batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting)
    zone_grid_hourly = deepcopy(zone_grid)
    result = Dict{String, Any}(["$hour" => Dict{String, Any}() for hour in hour_start_idx : hour_end_idx])
    for hour_idx in hour_start_idx : hour_end_idx
        hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
        result["$hour_idx"] = CbaOPF.solve_cbaopf(zone_grid_hourly, _PM.DCPPowerModel, solver; setting = setting) # solve the OPF 
    end 
    
    return result
end

function hourly_grid_data!(grid_data, grid_data_orig, hour, res_demand)
    for (l, load) in grid_data["load"]
        zone = load["zone"]
        load["pd"] =  res_demand["demand"][zone][hour] * grid_data_orig["load"][l]["pd"] * grid_data_orig["load"][l]["powerportion"] 
        # [OLD] To Do, fix demand response potential!
        # load["pred_rel_max"] = ts_data["load"][l]["pred_rel_max"][1, hour] 
        # load["cost_red"] = ts_data["load"][l]["cost_red"][1, hour] 
        # load["cost_curt"] = ts_data["load"][l]["cost_curt"][1, hour]
    end
    for (g, gen) in grid_data["gen"]
        zone = gen["zone"]
        if gen["type"] == "Onshore Wind"
            gen["pg"] =  res_demand["wind_onshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]  
            gen["pmax"] =  res_demand["wind_onshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
        elseif gen["type"] == "Offshore Wind"
            gen["pg"] =  res_demand["wind_offshore"][zone][hour]* grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  res_demand["wind_offshore"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        elseif gen["type"] == "Solar PV"
            gen["pg"] =  res_demand["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
            gen["pmax"] =  res_demand["solar_pv"][zone][hour] * grid_data_orig["gen"][g]["pmax"]
        end
    end
    return grid_data
end

function batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting, batch_size, file_name::String)
    number_of_hours = hour_end_idx - hour_start_idx + 1
    iterations = Int(number_of_hours/ batch_size)

    for idx in 1 : iterations
        hs_idx = Int((hour_start_idx - 1) + (idx - 1) * batch_size + 1) 
        he_idx = Int((hour_start_idx - 1) + idx * batch_size)

        run_batch_opf(hs_idx, he_idx, zone_grid, timeseries_data, solver, setting, file_name)
    end
end

function run_batch_opf(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting, file_name)
    zone_grid_hourly = deepcopy(zone_grid)
    result = Dict{String, Any}()
    
    for hour_idx in hour_start_idx : hour_end_idx
        hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
        result["$hour_idx"] = CbaOPF.solve_cbaopf(zone_grid_hourly, _PM.DCPPowerModel, solver; setting = setting) # solve the OPF 
    end

    opf_file_name = join([file_name, "_opf_",hour_start_idx,"_to_",hour_end_idx,".json"])
    json_string = JSON.json(result)
    open(opf_file_name,"w") do f
    write(f, json_string)
    end
end

function batch_opf_AC(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting)
    zone_grid_hourly = deepcopy(zone_grid)
    result = Dict{String, Any}(["$hour" => Dict{String, Any}() for hour in hour_start_idx : hour_end_idx])
    for hour_idx in hour_start_idx : hour_end_idx
        hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
        result["$hour_idx"] = CbaOPF.solve_cbaopf(zone_grid_hourly, _PM.DCPPowerModel, solver; setting = setting) # solve the OPF 
    end 
    
    return result
end


function batch_opf_AC(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting, batch_size, file_name::String)
    number_of_hours = hour_end_idx - hour_start_idx + 1
    iterations = Int(number_of_hours/ batch_size)

    for idx in 1 : iterations
        hs_idx = Int((hour_start_idx - 1) + (idx - 1) * batch_size + 1) 
        he_idx = Int((hour_start_idx - 1) + idx * batch_size)

        run_batch_opf_AC(hs_idx, he_idx, zone_grid, timeseries_data, solver, setting, file_name)
    end
end

function run_batch_opf_AC(hour_start_idx, hour_end_idx, zone_grid, timeseries_data, solver, setting, file_name)
    zone_grid_hourly = deepcopy(zone_grid)
    result = Dict{String, Any}()
    
    for hour_idx in hour_start_idx : hour_end_idx
        hourly_grid_data!(zone_grid_hourly, zone_grid, hour_idx, timeseries_data) # write hourly values into the grid data
        result["$hour_idx"] = CbaOPF.solve_cbaopf(zone_grid_hourly, _PM.DCPPowerModel, solver; setting = setting) # solve the OPF 
    end

    opf_file_name = join([file_name, "_opf_",hour_start_idx,"_to_",hour_end_idx,".json"])
    json_string = JSON.json(result)
    open(opf_file_name,"w") do f
    write(f, json_string)
    end
end
