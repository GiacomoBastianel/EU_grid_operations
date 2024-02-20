function fix_hourly_loads(grid,hour,hourly_timeseries) # -> doing nothing
    for (l_id,l) in grid["load"]
        l["pd"] = deepcopy(hourly_timeseries["max_demand"]["$(l["zone"])"]/100*hourly_timeseries["demand"]["$(l["zone"])"][hour]*l["powerportion"])
    end   
end

function fix_RES_time_series(grid,hour,hourly_timeseries)
    for (g_id,g) in grid["gen"]
        if g["type_tyndp"] == "Onshore Wind" 
            g["pmax"] = deepcopy(g["pmax"]*hourly_timeseries["wind_onshore"]["$(g["zone"])"][hour]) #pu
        elseif g["type_tyndp"] == "Offshore Wind" 
            g["pmax"] = deepcopy(g["pmax"]*hourly_timeseries["wind_offshore"]["$(g["zone"])"][hour]) #pu
        elseif g["type_tyndp"] == "Solar PV" 
            g["pmax"] = deepcopy(g["pmax"]*hourly_timeseries["solar_pv"]["$(g["zone"])"][hour]) #pu
        end
    end
end

function hourly_opf(grid,number_of_hours,hourly_timeseries)
    results = Dict{String,Any}()
    grid_hour = Dict{String,Any}()
    for hour in 1:number_of_hours
        hourly_grid = deepcopy(grid)
        fix_hourly_loads(hourly_grid,hour,hourly_timeseries)
        fix_RES_time_series(hourly_grid,hour,hourly_timeseries)
        s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true, "fix_cross_border_flows" => true)
        hourly_results = deepcopy(_PMACDC.run_acdcopf(hourly_grid, DCPPowerModel, Gurobi.Optimizer; setting = s))
        results["$hour"] = deepcopy(hourly_results)
        grid_hour["$hour"] = deepcopy(hourly_grid)
    end
    return results#, grid_hour
end