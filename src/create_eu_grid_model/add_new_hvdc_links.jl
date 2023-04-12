function find_closest_bus(grid_data, lat, lon)
    bus_lat_lon = zeros(length(grid_data["bus"]), 3)
    idx = 1
    for (b, bus) in grid_data["bus"]
        bus_lat_lon[idx, :] = [parse(Int, b), bus["lat"], bus["lon"]]
        idx = idx + 1
    end

    dist = (abs.(bus_lat_lon[:, 2] .- lat)).^2 .+ (abs.(bus_lat_lon[:, 3] .- lon)).^2
    mindist = findmin(dist)
    bus_idx = Int(bus_lat_lon[mindist[2], 1])

    return bus_idx
end

function add_dc_bus!(grid_data, dc_voltage; dc_bus_id = nothing, lat = 0, lon = 0)
    if isnothing(dc_bus_id)
        dc_bus_idx = maximum([bus["index"] for (b, bus) in grid_data["busdc"]]) + 1
    else
        dc_bus_idx = dc_bus_id
    end
    grid_data["busdc"]["$dc_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
    grid_data["busdc"]["$dc_bus_idx"]["busdc_i"] = dc_bus_idx # assign dc bus idx
    grid_data["busdc"]["$dc_bus_idx"]["grid"] = 1 # default, no meaning
    grid_data["busdc"]["$dc_bus_idx"]["Pdc"] = 0 # demand at DC bus, normally 0
    grid_data["busdc"]["$dc_bus_idx"]["Vdc"] = 1 # dc voltage set point 1 particular
    grid_data["busdc"]["$dc_bus_idx"]["basekVdc"] = dc_voltage # Binary indicator if reactor is installed
    grid_data["busdc"]["$dc_bus_idx"]["Vdcmax"] = 1.1 # maximum voltage 1.1 pu
    grid_data["busdc"]["$dc_bus_idx"]["Vdcmin"] = 0.9 # minimum voltage 0.9 pu
    grid_data["busdc"]["$dc_bus_idx"]["Cdc"] = 0 # not used
    grid_data["busdc"]["$dc_bus_idx"]["index"] = dc_bus_idx # not used
    grid_data["busdc"]["$dc_bus_idx"]["lat"] = lat
    grid_data["busdc"]["$dc_bus_idx"]["lat"] = lon

    return grid_data, dc_bus_idx
end


function add_converter!(grid_data, ac_bus_idx, dc_bus_idx, power_rating; zone = nothing, islcc = 0, conv_id = nothing, status = 1)
    if isnothing(conv_id)
        conv_idx = maximum([conv["index"] for (c, conv) in grid_data["convdc"]]) + 1
    else
        conv_idx = conv_id
    end
    grid_data["convdc"]["$conv_idx"] = Dict{String, Any}()  # create dictionary for each converter
    grid_data["convdc"]["$conv_idx"]["busdc_i"] = dc_bus_idx  # assign dc bus idx
    grid_data["convdc"]["$conv_idx"]["busac_i"] = ac_bus_idx  # assign ac bus idx
    grid_data["convdc"]["$conv_idx"]["type_dc"] = 1  # 1 -> const. dc power, 2-> constant dc voltage, 3 -> dc slack for grid. Not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["type_ac"] = 1  # 1 -> PQ, 2-> PV. Not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["P_g"] = 0 # converter P set point input
    grid_data["convdc"]["$conv_idx"]["Q_g"] = 0 # converter Q set point input
    grid_data["convdc"]["$conv_idx"]["islcc"] = islcc # LCC converter or not?
    grid_data["convdc"]["$conv_idx"]["Vtar"] = 1 # Target voltage for droop converter, not relevant for OPF!
    grid_data["convdc"]["$conv_idx"]["rtf"] = 0.01 # Transformer resistance in p.u.
    grid_data["convdc"]["$conv_idx"]["xtf"] = 0.01 # Transformer reactance in p.u.
    grid_data["convdc"]["$conv_idx"]["transformer"] = 1 # Binary indicator if transformer is installed
    grid_data["convdc"]["$conv_idx"]["tm"] = 1 # Transformer tap ratio
    grid_data["convdc"]["$conv_idx"]["bf"] = 0.01 # Filter susceptance in p.u.
    grid_data["convdc"]["$conv_idx"]["filter"] = 1 # Binary indicator if transformer is installed
    grid_data["convdc"]["$conv_idx"]["rc"] = 0.01 # Reactor resistance in p.u.
    grid_data["convdc"]["$conv_idx"]["xc"] = 0.01 # Reactor reactance in p.u.
    grid_data["convdc"]["$conv_idx"]["reactor"] = 1 # Binary indicator if reactor is installed
    grid_data["convdc"]["$conv_idx"]["basekVac"] = grid_data["bus"]["$ac_bus_idx"]["base_kv"]
    grid_data["convdc"]["$conv_idx"]["Vmmax"] = 1.1 # Range for AC voltage
    grid_data["convdc"]["$conv_idx"]["Vmmin"] = 0.9 # Range for AC voltage
    grid_data["convdc"]["$conv_idx"]["Imax"] = power_rating  # maximum AC current of converter
    grid_data["convdc"]["$conv_idx"]["LossA"] = 0 # power_rating * 0.001  # Aux. losses parameter in MW
    grid_data["convdc"]["$conv_idx"]["LossB"] = 0.6 / power_rating # 0.887  # Proportional losses losses parameter in MW
    grid_data["convdc"]["$conv_idx"]["LossCrec"] = 0#2.885  # Quadratic losses losses parameter in MW^2
    grid_data["convdc"]["$conv_idx"]["LossCinv"] = 0#2.885  # Quadratic losses losses parameter in MW^2
    grid_data["convdc"]["$conv_idx"]["droop"] = 0  # Power voltage droop, not relevant for OPF
    grid_data["convdc"]["$conv_idx"]["Pdcset"] = 0  # DC power setpoint for droop, not relevant OPF
    grid_data["convdc"]["$conv_idx"]["Vdcset"] = 0  # DC voltage setpoint for droop, not relevant OPF
    grid_data["convdc"]["$conv_idx"]["Pacmax"] =  power_rating   # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Pacmin"] = -power_rating  # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Pacrated"] =  power_rating * 1.1   # maximum AC power
    grid_data["convdc"]["$conv_idx"]["Qacrated"] =  0.4 * power_rating  * 1.1  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["Qacmax"] =  0.4 * power_rating  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["Qacmin"] =  -0.4 * power_rating  # maximum AC reactive power -> assumption
    grid_data["convdc"]["$conv_idx"]["index"] = conv_idx
    grid_data["convdc"]["$conv_idx"]["status"] = status
    grid_data["convdc"]["$conv_idx"]["inertia_constants"] = 10 # typical virtual inertia constant.
    if !isnothing(zone)
        grid_data["convdc"]["$conv_idx"]["zone"] = zone
    end

    return grid_data
end

function add_dc_branch!(grid_data, fbus_dc, tbus_dc, power_rating; status = 1, r = 0.06, branch_id = nothing)
    if isnothing(branch_id)
        dc_br_idx = maximum([branch["index"] for (br, branch) in grid_data["branchdc"]]) + 1
    else
        dc_br_idx = branch_id
    end
    grid_data["branchdc"]["$dc_br_idx"] = Dict{String, Any}()
    grid_data["branchdc"]["$dc_br_idx"]["fbusdc"] = fbus_dc
    grid_data["branchdc"]["$dc_br_idx"]["tbusdc"] = tbus_dc
    grid_data["branchdc"]["$dc_br_idx"]["r"] = r
    grid_data["branchdc"]["$dc_br_idx"]["l"] = 0   # zero in steady state
    grid_data["branchdc"]["$dc_br_idx"]["c"] = 0 # zero in steady state
    grid_data["branchdc"]["$dc_br_idx"]["rateA"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["rateB"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["rateC"] = power_rating
    grid_data["branchdc"]["$dc_br_idx"]["status"] = status
    grid_data["branchdc"]["$dc_br_idx"]["index"] = dc_br_idx

    return grid_data
end