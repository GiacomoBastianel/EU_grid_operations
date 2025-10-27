
# function find_closest_bus(grid_data, lat, lon)
#     bus_lat_lon = zeros(length(grid_data["bus"]), 3)
#     idx = 1
#     for (b, bus) in grid_data["bus"]
#         bus_lat_lon[idx, :] = [parse(Int, b), bus["lat"], bus["lon"]]
#         idx = idx + 1
#     end

#     dist = (abs.(bus_lat_lon[:, 2] .- lat)).^2 .+ (abs.(bus_lat_lon[:, 3] .- lon)).^2
#     mindist = findmin(dist)
#     bus_idx = Int(bus_lat_lon[mindist[2], 1])

#     return bus_idx
# end

# function add_dc_bus!(grid_data, dc_voltage, zone, name; dc_bus_id = nothing, lat = 0, lon = 0)
#     if isnothing(dc_bus_id)
#         dc_bus_idx = maximum([bus["index"] for (b, bus) in grid_data["busdc"]]) + 1
#     else
#         dc_bus_idx = dc_bus_id
#     end
#     grid_data["busdc"]["$dc_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
#     grid_data["busdc"]["$dc_bus_idx"]["busdc_i"] = dc_bus_idx # assign dc bus idx
#     grid_data["busdc"]["$dc_bus_idx"]["grid"] = 1 # default, no meaning
#     grid_data["busdc"]["$dc_bus_idx"]["Pdc"] = 0 # demand at DC bus, normally 0
#     grid_data["busdc"]["$dc_bus_idx"]["Vdc"] = 1 # dc voltage set point 1 particular
#     grid_data["busdc"]["$dc_bus_idx"]["basekVdc"] = dc_voltage # Binary indicator if reactor is installed
#     grid_data["busdc"]["$dc_bus_idx"]["Vdcmax"] = 1.1 # maximum voltage 1.1 pu
#     grid_data["busdc"]["$dc_bus_idx"]["Vdcmin"] = 0.9 # minimum voltage 0.9 pu
#     grid_data["busdc"]["$dc_bus_idx"]["Cdc"] = 0 # not used
#     grid_data["busdc"]["$dc_bus_idx"]["index"] = dc_bus_idx # not used
#     grid_data["busdc"]["$dc_bus_idx"]["lat"] = lat
#     grid_data["busdc"]["$dc_bus_idx"]["lon"] = lon
#     grid_data["busdc"]["$dc_bus_idx"]["zone"] = zone
#     grid_data["busdc"]["$dc_bus_idx"]["name"] = name
#     return dc_bus_idx
# end

# function add_ac_bus!(grid_data, ac_voltage, zone, name; ac_bus_id = nothing, lat = 0, lon = 0)
#     if isnothing(ac_bus_id)
#         ac_bus_idx = maximum([bus["index"] for (b, bus) in grid_data["bus"]]) + 1
#     else
#         ac_bus_idx = ac_bus_id
#     end
#     grid_data["bus"]["$ac_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
#     grid_data["bus"]["$ac_bus_idx"]["lat"] = lat
#     grid_data["bus"]["$ac_bus_idx"]["lon"] = lon
#     grid_data["bus"]["$ac_bus_idx"]["bus_i"] = ac_bus_idx # assign dc bus idx
#     grid_data["bus"]["$ac_bus_idx"]["name"] = name
#     grid_data["bus"]["$ac_bus_idx"]["zone"] = zone
#     grid_data["bus"]["$ac_bus_idx"]["bus_type"] = 2 # assign bus type
#     grid_data["bus"]["$ac_bus_idx"]["vmax"] = 1.10 # maximum voltage 1.1 pu
#     grid_data["bus"]["$ac_bus_idx"]["qd"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["gs"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["bs"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["source_id"] = [] # demand at DC bus, normally 0
#     push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],"bus") # demand at DC bus, normally 0
#     push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],ac_bus_idx) # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["area"] = 1 # default, no meaning
#     grid_data["bus"]["$ac_bus_idx"]["vmin"] = 0.90 # minimum voltage 0.9 pu
#     grid_data["bus"]["$ac_bus_idx"]["index"] = ac_bus_idx # not used
#     grid_data["bus"]["$ac_bus_idx"]["va"] = 0 # dc voltage set point 1 particular
#     grid_data["bus"]["$ac_bus_idx"]["vm"] = 0 # dc voltage set point 1 particular
#     grid_data["bus"]["$ac_bus_idx"]["base_kV"] = ac_voltage # Binary indicator if reactor is installed
#     grid_data["bus"]["$ac_bus_idx"]["pd"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["transformer"] = false # demand at DC bus, normally 0
    
#     return ac_bus_idx
# end

# function add_ac_bus_offshore!(grid_data, ac_voltage, ac_bus_idx, name, zone; lat = 0, lon = 0)
#     grid_data["bus"]["$ac_bus_idx"] = Dict{String, Any}()  # create dictionary for each bus
#     grid_data["bus"]["$ac_bus_idx"]["lat"] = lat
#     grid_data["bus"]["$ac_bus_idx"]["lon"] = lon
#     grid_data["bus"]["$ac_bus_idx"]["bus_i"] = ac_bus_idx # assign dc bus idx
#     grid_data["bus"]["$ac_bus_idx"]["name"] = name
#     grid_data["bus"]["$ac_bus_idx"]["zone"] = zone
#     grid_data["bus"]["$ac_bus_idx"]["bus_type"] = 2 # assign bus type
#     grid_data["bus"]["$ac_bus_idx"]["vmax"] = 1.1 # maximum voltage 1.1 pu
#     grid_data["bus"]["$ac_bus_idx"]["qd"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["gs"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["bs"] = 0 # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["source_id"] = [] # demand at DC bus, normally 0
#     push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],"bus") # demand at DC bus, normally 0
#     push!(grid_data["bus"]["$ac_bus_idx"]["source_id"],ac_bus_idx) # demand at DC bus, normally 0
#     grid_data["bus"]["$ac_bus_idx"]["area"] = 1 # default, no meaning
#     grid_data["bus"]["$ac_bus_idx"]["vmin"] = 0.90 # minimum voltage 0.9 pu
#     grid_data["bus"]["$ac_bus_idx"]["index"] = ac_bus_idx # not used
#     grid_data["bus"]["$ac_bus_idx"]["va"] = 0 # dc voltage set point 1 particular
#     grid_data["bus"]["$ac_bus_idx"]["vm"] = 0 # dc voltage set point 1 particular
#     grid_data["bus"]["$ac_bus_idx"]["base_kv"] = ac_voltage # Binary indicator if reactor is installed
#     grid_data["bus"]["$ac_bus_idx"]["pd"] = 0 # demand at DC bus, normally 0
#     return grid_data, ac_bus_idx
#end

# function add_converter!(grid_data, ac_bus_idx, dc_bus_idx, power_rating; zone = nothing, islcc = 0, conv_id = nothing, status = 1)
#     if isnothing(conv_id)
#         conv_idx = maximum([conv["index"] for (c, conv) in grid_data["convdc"]]) + 1
#     else
#         conv_idx = conv_id
#     end
#     grid_data["convdc"]["$conv_idx"] = Dict{String, Any}()  # create dictionary for each converter
#     grid_data["convdc"]["$conv_idx"]["busdc_i"] = dc_bus_idx  # assign dc bus idx
#     grid_data["convdc"]["$conv_idx"]["busac_i"] = ac_bus_idx  # assign ac bus idx
#     grid_data["convdc"]["$conv_idx"]["type_dc"] = 1  # 1 -> const. dc power, 2-> constant dc voltage, 3 -> dc slack for grid. Not relevant for OPF!
#     grid_data["convdc"]["$conv_idx"]["type_ac"] = 1  # 1 -> PQ, 2-> PV. Not relevant for OPF!
#     grid_data["convdc"]["$conv_idx"]["P_g"] = 0 # converter P set point input
#     grid_data["convdc"]["$conv_idx"]["Q_g"] = 0 # converter Q set point input
#     grid_data["convdc"]["$conv_idx"]["islcc"] = islcc # LCC converter or not?
#     grid_data["convdc"]["$conv_idx"]["Vtar"] = 1 # Target voltage for droop converter, not relevant for OPF!
#     grid_data["convdc"]["$conv_idx"]["rtf"] = 0.01 # Transformer resistance in p.u.
#     grid_data["convdc"]["$conv_idx"]["xtf"] = 0.01 # Transformer reactance in p.u.
#     grid_data["convdc"]["$conv_idx"]["transformer"] = 1 # Binary indicator if transformer is installed
#     grid_data["convdc"]["$conv_idx"]["tm"] = 1 # Transformer tap ratio
#     grid_data["convdc"]["$conv_idx"]["bf"] = 0.01 # Filter susceptance in p.u.
#     grid_data["convdc"]["$conv_idx"]["filter"] = 1 # Binary indicator if transformer is installed
#     grid_data["convdc"]["$conv_idx"]["rc"] = 0.01 # Reactor resistance in p.u.
#     grid_data["convdc"]["$conv_idx"]["xc"] = 0.01 # Reactor reactance in p.u.
#     grid_data["convdc"]["$conv_idx"]["reactor"] = 1 # Binary indicator if reactor is installed
#     grid_data["convdc"]["$conv_idx"]["basekVac"] = 400#grid_data["bus"]["1"]["base_kV"]       #modifica matteo
#     grid_data["convdc"]["$conv_idx"]["Vmmax"] = 1.1 # Range for AC voltage
#     grid_data["convdc"]["$conv_idx"]["Vmmin"] = 0.9 # Range for AC voltage
#     grid_data["convdc"]["$conv_idx"]["Imax"] = power_rating  # maximum AC current of converter
#     grid_data["convdc"]["$conv_idx"]["LossA"] = 0 #power_rating * 0.001  # Aux. losses parameter in MW
#     grid_data["convdc"]["$conv_idx"]["LossB"] = 0 #0.6 / power_rating # 0.887  # Proportional losses losses parameter in MW
#     grid_data["convdc"]["$conv_idx"]["LossCrec"] = 0#2.885  # Quadratic losses losses parameter in MW^2
#     grid_data["convdc"]["$conv_idx"]["LossCinv"] = 0#2.885  # Quadratic losses losses parameter in MW^2
#     grid_data["convdc"]["$conv_idx"]["droop"] = 0  # Power voltage droop, not relevant for OPF
#     grid_data["convdc"]["$conv_idx"]["Pdcset"] = 0  # DC power setpoint for droop, not relevant OPF
#     grid_data["convdc"]["$conv_idx"]["Vdcset"] = 0  # DC voltage setpoint for droop, not relevant OPF
#     grid_data["convdc"]["$conv_idx"]["Pacmax"] =  power_rating   # maximum AC power
#     grid_data["convdc"]["$conv_idx"]["Pacmin"] = -power_rating  # maximum AC power
#     grid_data["convdc"]["$conv_idx"]["Pacrated"] =  power_rating * 1.1   # maximum AC power
#     grid_data["convdc"]["$conv_idx"]["Qacrated"] =  0.4 * power_rating  * 1.1  # maximum AC reactive power -> assumption
#     grid_data["convdc"]["$conv_idx"]["Qacmax"] =  0.4 * power_rating  # maximum AC reactive power -> assumption
#     grid_data["convdc"]["$conv_idx"]["Qacmin"] =  -0.4 * power_rating  # maximum AC reactive power -> assumption
#     grid_data["convdc"]["$conv_idx"]["index"] = conv_idx
#     grid_data["convdc"]["$conv_idx"]["status"] = status
#     grid_data["convdc"]["$conv_idx"]["inertia_constants"] = 10 # typical virtual inertia constant.
#     if !isnothing(zone)
#         grid_data["convdc"]["$conv_idx"]["zone"] = zone
#     end

#     return conv_idx
# end

function add_OFW_generator!(grid_data, gen_bus, power_rating, gen_cost, gen_zone; gen_id = nothing, status = 1) 
    if isnothing(gen_id)
        gen_idx = maximum([gen["index"] for (g, gen) in grid_data["gen"]]) + 1
    else
        gen_idx = gen_id
    end
    grid_data["gen"]["$gen_idx"] = Dict{String, Any}()  
    grid_data["gen"]["$gen_idx"]["zone"] = gen_zone  
    grid_data["gen"]["$gen_idx"]["type_tyndp"] = "Offshore Wind"
    grid_data["gen"]["$gen_idx"]["model"] = 2  
    grid_data["gen"]["$gen_idx"]["gen_bus"] = gen_bus
    grid_data["gen"]["$gen_idx"]["pmax"] = power_rating 
    grid_data["gen"]["$gen_idx"]["installed_capacity"] = power_rating 
    grid_data["gen"]["$gen_idx"]["country"] = 4
    grid_data["gen"]["$gen_idx"]["vg"] = 1.0
    grid_data["gen"]["$gen_idx"]["source_id"] = []
    push!(grid_data["gen"]["$gen_idx"]["source_id"],"gen")
    push!(grid_data["gen"]["$gen_idx"]["source_id"],gen_idx)
    grid_data["gen"]["$gen_idx"]["index"] = gen_idx
    grid_data["gen"]["$gen_idx"]["cost"] = []
    push!(grid_data["gen"]["$gen_idx"]["cost"],gen_cost)
    push!(grid_data["gen"]["$gen_idx"]["cost"],0.0)
    grid_data["gen"]["$gen_idx"]["qmax"] = 6.0 
    grid_data["gen"]["$gen_idx"]["gen_status"] = 1
    grid_data["gen"]["$gen_idx"]["qmin"] = - 6.0 
    grid_data["gen"]["$gen_idx"]["type"] = "Offshore Wind"  
    grid_data["gen"]["$gen_idx"]["pmin"] = 0.0 
    grid_data["gen"]["$gen_idx"]["ncost"] = 2 
    
    return gen_idx
end

function add_generator!(grid_data, gen_bus, power_rating, gen_zone, gen_type; gen_id = nothing, status = 1) 
    gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx = gen_values()
    
    if isnothing(gen_id)
        gen_idx = maximum([gen["index"] for (g, gen) in grid_data["gen"]]) + 1
    else
        gen_idx = gen_id
    end
    grid_data["gen"]["$gen_idx"] = Dict{String, Any}()  
    grid_data["gen"]["$gen_idx"]["zone"] = gen_zone  
    grid_data["gen"]["$gen_idx"]["type_tyndp"] = gen_type
    grid_data["gen"]["$gen_idx"]["model"] = 2  
    grid_data["gen"]["$gen_idx"]["gen_bus"] = gen_bus
    grid_data["gen"]["$gen_idx"]["pmax"] = power_rating 
    grid_data["gen"]["$gen_idx"]["inertia_constant"] = inertia_constants[gen_type]
    grid_data["gen"]["$gen_idx"]["C02_emission"] = emission_factor_CO2[gen_type] 
    grid_data["gen"]["$gen_idx"]["N0x_emission"] = emission_factor_NOx[gen_type] 
    grid_data["gen"]["$gen_idx"]["S0x_emission"] = emission_factor_SOx[gen_type] 
    grid_data["gen"]["$gen_idx"]["installed_capacity"] = power_rating 
    grid_data["gen"]["$gen_idx"]["vg"] = 1.0
    grid_data["gen"]["$gen_idx"]["source_id"] = []
    push!(grid_data["gen"]["$gen_idx"]["source_id"],"gen")
    push!(grid_data["gen"]["$gen_idx"]["source_id"],gen_idx)
    grid_data["gen"]["$gen_idx"]["index"] = gen_idx
    grid_data["gen"]["$gen_idx"]["cost"] = []
    push!(grid_data["gen"]["$gen_idx"]["cost"],gen_costs[gen_type])
    push!(grid_data["gen"]["$gen_idx"]["cost"],0.0)
    grid_data["gen"]["$gen_idx"]["qmax"] = 6.0 
    grid_data["gen"]["$gen_idx"]["gen_status"] = 1
    grid_data["gen"]["$gen_idx"]["qmin"] = - 6.0 
    grid_data["gen"]["$gen_idx"]["type"] = gen_type  
    grid_data["gen"]["$gen_idx"]["pmin"] = 0.0 
    grid_data["gen"]["$gen_idx"]["ncost"] = 2 
    
    return gen_idx
end

function add_load!(grid_data, load_bus, peak_power, load_zone, powerportion, country_peak_load; load_id = nothing, status = 1) 
    
    if isnothing(load_id)
        load_idx = maximum([load["index"] for (g, load) in grid_data["load"]]) + 1
    else
        load_idx = load_id
    end
    grid_data["load"]["$load_idx"] = Dict{String, Any}()  
    grid_data["load"]["$load_idx"]["zone"] = load_zone  
    grid_data["load"]["$load_idx"]["load_bus"] = load_bus
    grid_data["load"]["$load_idx"]["pmax"] = peak_power 
    grid_data["load"]["$load_idx"]["pmin"] = 0.0 
    grid_data["load"]["$load_idx"]["pd"] = peak_power #0.1 
    grid_data["load"]["$load_idx"]["qd"] = 0#0.1 
    grid_data["load"]["$load_idx"]["status"] = 1 
    grid_data["load"]["$load_idx"]["source_id"] = []
    push!(grid_data["load"]["$load_idx"]["source_id"],"bus")
    push!(grid_data["load"]["$load_idx"]["source_id"],load_bus)
    grid_data["load"]["$load_idx"]["index"] = load_idx
    grid_data["load"]["$load_idx"]["flex"] = 1
    grid_data["load"]["$load_idx"]["powerportion"] =powerportion
    grid_data["load"]["$load_idx"]["country_peak_load"] =country_peak_load
    grid_data["load"]["$load_idx"]["pred_rel_max"] =0
    grid_data["load"]["$load_idx"]["cost_red"] =14000
    grid_data["load"]["$load_idx"]["cost_curt"] =1000000
    grid_data["load"]["$load_idx"]["country"] =17
    grid_data["load"]["$load_idx"]["cosphi"] = 1
    
    return load_idx
end

# function add_dc_branch!(grid_data, fbus_dc, tbus_dc, power_rating; status = 1, r = 0.006, branch_id = nothing)
#     if isnothing(branch_id)
#         dc_br_idx = maximum([branch["index"] for (br, branch) in grid_data["branchdc"]]) + 1
#     else
#         dc_br_idx = branch_id
#     end
#     grid_data["branchdc"]["$dc_br_idx"] = Dict{String, Any}()
#     grid_data["branchdc"]["$dc_br_idx"]["fbusdc"] = fbus_dc
#     grid_data["branchdc"]["$dc_br_idx"]["tbusdc"] = tbus_dc
#     grid_data["branchdc"]["$dc_br_idx"]["r"] = r
#     grid_data["branchdc"]["$dc_br_idx"]["l"] = 0   # zero in steady state
#     grid_data["branchdc"]["$dc_br_idx"]["c"] = 0 # zero in steady state
#     grid_data["branchdc"]["$dc_br_idx"]["rateA"] = power_rating
#     grid_data["branchdc"]["$dc_br_idx"]["rateB"] = power_rating
#     grid_data["branchdc"]["$dc_br_idx"]["rateC"] = power_rating
#     grid_data["branchdc"]["$dc_br_idx"]["status"] = status
#     grid_data["branchdc"]["$dc_br_idx"]["index"] = dc_br_idx
#     grid_data["branchdc"]["$dc_br_idx"]["source_id"] = []
#     push!(grid_data["branchdc"]["$dc_br_idx"]["source_id"],"branchdc")
#     push!(grid_data["branchdc"]["$dc_br_idx"]["source_id"],dc_br_idx)

#     return dc_br_idx
# end

# function add_ac_branch!(grid_data, fbus, tbus, power_rating; status = 1, r = 0.001, x = 0.01, branch_id = nothing)
#     if isnothing(branch_id)
#         br_idx = maximum([branch["index"] for (br, branch) in grid_data["branch"]]) + 1
#     else
#         br_idx = branch_id
#     end
#     grid_data["branch"]["$br_idx"] = Dict{String, Any}()
#     grid_data["branch"]["$br_idx"]["f_bus"] = fbus
#     grid_data["branch"]["$br_idx"]["t_bus"] = tbus
#     grid_data["branch"]["$br_idx"]["br_r"] = r
#     grid_data["branch"]["$br_idx"]["br_x"] = angmax/power_rating#0.01  
#     grid_data["branch"]["$br_idx"]["rate_a"] = power_rating
#     grid_data["branch"]["$br_idx"]["rate_b"] = power_rating
#     grid_data["branch"]["$br_idx"]["rate_c"] = power_rating
#     grid_data["branch"]["$br_idx"]["status"] = status
#     grid_data["branch"]["$br_idx"]["index"] = br_idx
#     grid_data["branch"]["$br_idx"]["interconnector"] = false
#     grid_data["branch"]["$br_idx"]["transformer"] = false
#     grid_data["branch"]["$br_idx"]["type"] = "AC line"
#     grid_data["branch"]["$br_idx"]["tap"] = 1.0
#     grid_data["branch"]["$br_idx"]["g_to"] = 1.0
#     grid_data["branch"]["$br_idx"]["g_fr"] = 1.0
#     grid_data["branch"]["$br_idx"]["b_fr"] = 10.0
#     grid_data["branch"]["$br_idx"]["b_to"] = 10.0
#     grid_data["branch"]["$br_idx"]["base_kv"] = 220
#     grid_data["branch"]["$br_idx"]["source_id"] = []
#     push!(grid_data["branch"]["$br_idx"]["source_id"],"branch")
#     push!(grid_data["branch"]["$br_idx"]["source_id"],br_idx)
#     grid_data["branch"]["$br_idx"]["br_status"] = 1
#     grid_data["branch"]["$br_idx"]["shift"] = 0.0
#     grid_data["branch"]["$br_idx"]["ratio"] = 1
#     grid_data["branch"]["$br_idx"]["angmin"] = - 1.0472
#     grid_data["branch"]["$br_idx"]["angmax"] = 1.0472
    
#     return br_idx
# end

function add_country!(grid_data, bus, first_gen, scenario, year, climate_year, zone, path)
    generation_file = joinpath(path,"Generation_capacity_per_zone/PEMMDB2/$(scenario)/$(year)/Installed_generation_capacity_$(scenario)$(year)_MW.csv")
    gen = CSV.read(generation_file, DataFrame)
    demand_file = joinpath(path,"Demand_Profiles/$(scenario)/$(year)/Demand_$(scenario)$(year)_$(climate_year).csv")
    load = CSV.read(demand_file, DataFrame)
   
    added_gen = 0
    for i in 1:length(gen[:,"Generation types"])
        if gen[i,zone] != 0.0
            added_gen += 1
            new_gen_type = String(gen[i,"Generation types"])
            new_gen_pmax = gen[i,zone]/grid_data["baseMVA"]
            add_generator!(grid_data, bus, new_gen_pmax, zone, new_gen_type, gen_id = first_gen+added_gen)
        end
    end
    peak_power = maximum(load[:,zone])/grid_data["baseMVA"]
    add_load!(grid_data, bus, peak_power, zone) 
end

# FIX THIS VALUES, UPDATE WITH 2024 VALUES
function gen_values()
    gen_costs = Dict{String, Any}( # €/MWh
    "DSR"                         => 119,
    "Other non-RES"               => 120,
    "Offshore Wind"               => 69,
    "Onshore Wind"                => 30,
    "Solar PV"                    => 41,
    "Solar Thermal"               => 108,
    "Gas CCGT new"                => 89,
    "Gas CCGT old 1"              => 89,
    "Gas CCGT old 2"              => 89,
    "Gas CCGT present 1"          => 89,
    "Gas CCGT present 2"          => 89,
    "Reservoir"                   => 5300,
    "Run-of-River"                => 5300,
    "Gas Conventional old 1"      => 120,
    "Gas Conventional old 2"      => 120,
    "PS Closed"                   => 120,
    "PS Open"                     => 120,
    "Lignite new"                 => 120,
    "Lignite CCS"                 => 120,
    "Lignite old 1"               => 120,
    "Lignite old 2"               => 120,
    "Hard coal new"               => 120,
    "Hard coal CCS"               => 120,
    "Hard coal old 1"             => 120, 
    "Hard coal old 2"             => 120, 
    "Gas CCGT old 2 Bio"          => 120,
    "Gas Conventional old 2 Bio"  => 120,
    "Hard coal new Bio"           => 120,
    "Hard coal old 1 Bio"         => 120,
    "Hard coal old 2 Bio"         => 120,
    "Heavy oil old 1 Bio"         => 120,
    "Lignite old 1 Bio"           => 120,
    "Oil shale new Bio"           => 120,
    "Gas OCGT new"                => 89,
    "Gas OCGT old"                => 120,
    "Heavy oil old 1"             => 150,
    "Heavy oil old 2"             => 120,
    "Nuclear"                     => 88, 
    "Light oil"                   => 140,
    "Oil shale new"               => 150,
    "P2G"                         => 120,
    "Other non-RES DE00 P"        => 120,
    "Other non-RES DKE1 P"        => 120,
    "Other non-RES DKW1 P"        => 120,
    "Other non-RES FI00 P"        => 120,
    "Other non-RES FR00 P"        => 120,
    "Other non-RES MT00 P"        => 120,
    "Other non-RES UK00 P"        => 120,
    "Other RES"                   => 70,
    "Gas CCGT new CCS"            => 89,
    "Gas CCGT present 1 CCS"      => 60,
    "Gas CCGT present 2 CCS"      => 60,
    "Battery"                     => 119,
    "Lignite old 2 Bio"           => 120,
    "Oil shale old"               => 150,
    "Gas CCGT CCS"                => 89,
    "VOLL"                        => 10000,
    "HVDC"                        => 0
    )


    # other non-RES are assumed to have the same emissions as gas
    emission_factor_CO2 = Dict{String, Any}( #kg/netGJ -> ton/MWh
    "DSR" => 0,
    "Other non-RES"  => 0,
    "Offshore Wind"  => 0,
    "Onshore Wind"  => 0,
    "Solar PV"  => 0,
    "Solar Thermal"  => 0,
    "Gas CCGT new"        => (57*3.6)*10^(-3),
    "Gas CCGT old 1"      => (57*3.6)*10^(-3),
    "Gas CCGT old 2"      => (57*3.6)*10^(-3),
    "Gas CCGT present 1"  => (57*3.6)*10^(-3),
    "Gas CCGT present 2"  => (57*3.6)*10^(-3),
    "Reservoir"  => 0,
    "Run-of-River"  => 0,
    "Gas Conventional old 1"  => (57*3.6)*10^(-3),
    "Gas Conventional old 2"  => (57*3.6)*10^(-3),
    "PS Closed"  => (57*3.6)*10^(-3),
    "PS Open"  =>   (57*3.6)*10^(-3),
    "Lignite new"  =>   (101*3.6)*10^(-3),
    "Lignite CCS"  =>   (101*3.6)*10^(-3),
    "Lignite old 1"  => (101*3.6)*10^(-3),
    "Lignite old 2"  => (101*3.6)*10^(-3),
    "Hard coal new"  => (94*3.6)*10^(-3),
    "Hard coal CCS"  => (94*3.6)*10^(-3),
    "Hard coal old 1"  => (94*3.6)*10^(-3),
    "Hard coal old 2"  => (94*3.6)*10^(-3),
    "Gas CCGT old 2 Bio"          => (57*3.6)*10^(-3),
    "Gas Conventional old 2 Bio"  => (57*3.6)*10^(-3),
    "Hard coal new Bio"  =>   (94*3.6)*10^(-3),
    "Hard coal old 1 Bio"  => (94*3.6)*10^(-3),
    "Hard coal old 2 Bio" =>  (94*3.6)*10^(-3),
    "Heavy oil old 1 Bio"  => (94*3.6)*10^(-3),
    "Lignite old 1 Bio"  => (101*3.6)*10^(-3),
    "Oil shale new Bio"  => (100*3.6)*10^(-3),
    "Gas OCGT new"  => (57*3.6)*10^(-3),
    "Gas OCGT old"  => (57*3.6)*10^(-3),
    "Heavy oil old 1"  => (78*3.6)*10^(-3),
    "Heavy oil old 2"  => (78*3.6)*10^(-3),
    "Nuclear" => 0,
    "Light oil" => (78*3.6)*10^(-3),
    "Oil shale new" => (100*3.6)*10^(-3),
    "P2G" => 0,
    "Other non-RES DE00 P" => (57*3.6)*10^(-3),
    "Other non-RES DKE1 P" => (57*3.6)*10^(-3),
    "Other non-RES DKW1 P" => (57*3.6)*10^(-3),
    "Other non-RES FI00 P" => (57*3.6)*10^(-3),
    "Other non-RES FR00 P" => (57*3.6)*10^(-3),
    "Other non-RES MT00 P" => (57*3.6)*10^(-3),
    "Other non-RES UK00 P" => (57*3.6)*10^(-3),
    "Other RES" => 0,
    "Gas CCGT new CCS"        => (5.7*3.6)*10^(-3),
    "Gas CCGT present 1 CCS"  => (5.7*3.6)*10^(-3),
    "Gas CCGT present 2 CCS"  => (5.7*3.6)*10^(-3),
    "Battery"  => 0,
    "Lignite old 2 Bio"  => (101*3.6)*10^(-3),
    "Oil shale old"  => (100*3.6)*10^(-3),
    "Gas CCGT CCS"  => (5.7*3.6)*10^(-3),
    "VOLL" => 0,
    "HVDC" => 0
    )



    inertia_constants = Dict{String, Any}( # s
    "DSR"                       => 0,
    "Other non-RES"             => 0,
    "Offshore Wind"             => 0,
    "Onshore Wind"              => 0,
    "Solar PV"                  => 0,
    "Solar Thermal"             => 0,
    "Gas CCGT new"              => 5,
    "Gas CCGT old 1"            => 5,
    "Gas CCGT old 2"            => 5,
    "Gas CCGT present 1"        => 5,
    "Gas CCGT present 2"        => 5,
    "Reservoir"                 => 3,
    "Run-of-River"              => 3,
    "Gas Conventional old 1"    => 5,
    "Gas Conventional old 2"    => 5,
    "PS Closed"                 => 3,
    "PS Open"                   => 3,
    "Lignite new"               => 4,
    "Lignite CCS"               => 4,
    "Lignite old 1"             => 4,
    "Lignite old 2"             => 4,
    "Hard coal new"             => 4,
    "Hard coal CCS"             => 4,
    "Hard coal old 1"           => 4,
    "Hard coal old 2"           => 4,
    "Gas CCGT old 2 Bio"        => 5,
    "Gas Conventional old 2 Bio"=> 5,
    "Hard coal new Bio"         => 4,
    "Hard coal old 1 Bio"       => 4,
    "Hard coal old 2 Bio"       => 4,
    "Heavy oil old 1 Bio"       => 4,
    "Lignite old 1 Bio"         => 4,
    "Oil shale new Bio"         => 4,
    "Gas OCGT new"              => 5,
    "Gas OCGT old"              => 5,
    "Heavy oil old 1"           => 4,
    "Heavy oil old 2"           => 4,
    "Nuclear"                   => 6,
    "Light oil"                 => 4,
    "Oil shale new"             => 4,
    "P2G"                       => 0,
    "Other non-RES DE00 P"      => 0,
    "Other non-RES DKE1 P"      => 0,
    "Other non-RES DKW1 P"      => 0,
    "Other non-RES FI00 P"      => 0,
    "Other non-RES FR00 P"      => 0,
    "Other non-RES MT00 P"      => 0,
    "Other non-RES UK00 P"      => 0,
    "Other RES"                 => 0,
    "Gas CCGT new CCS"          => 5,
    "Gas CCGT present 1 CCS"    => 5,
    "Gas CCGT present 2 CCS"    => 5,
    "Battery"                   => 0,
    "Lignite old 2 Bio"         => 4,
    "Oil shale old"             => 4,
    "Gas CCGT CCS"              => 5,
    "VOLL"                      => 0,
    "HVDC"                      => 0
    )

    start_up_cost = Dict{String, Any}( #EUR/MW/start
    "DSR" => 0,
    "Other non-RES"  => 90,
    "Offshore Wind"  => 0,
    "Onshore Wind"  => 0,
    "Solar PV"  => 0,
    "Solar Thermal"  => 0,
    "Gas CCGT new"        => 90,
    "Gas CCGT old 1"      => 90,
    "Gas CCGT old 2"      => 90,
    "Gas CCGT present 1"  => 90,
    "Gas CCGT present 2"  => 90,
    "Reservoir"  => 0,
    "Run-of-River"  => 0,
    "Gas Conventional old 1"  => 90,
    "Gas Conventional old 2"  => 90,
    "PS Closed"  => 150,
    "PS Open"  =>   150,
    "Lignite new"  =>   175,
    "Lignite CCS"  =>   175,
    "Lignite old 1"  => 175,
    "Lignite old 2"  => 175,
    "Hard coal new"  => 175,
    "Hard coal CCS"  => 175,
    "Hard coal old 1"  => 175,
    "Hard coal old 2"  => 175,
    "Gas CCGT old 2 Bio"          => 90,
    "Gas Conventional old 2 Bio"  => 90,
    "Hard coal new Bio"  =>   175,
    "Hard coal old 1 Bio"  => 175,
    "Hard coal old 2 Bio" =>  175,
    "Heavy oil old 1 Bio"  => 150,
    "Lignite old 1 Bio"  => 175,
    "Oil shale new Bio"  => 150,
    "Gas OCGT new"  => 90,
    "Gas OCGT old"  => 90,
    "Heavy oil old 1"  => 150,
    "Heavy oil old 2"  => 150,
    "Nuclear" => 1000,
    "Light oil" =>     150,
    "Oil shale new" => 150,
    "P2G" => 0,
    "Other non-RES DE00 P" => 175,
    "Other non-RES DKE1 P" => 175,
    "Other non-RES DKW1 P" => 175,
    "Other non-RES FI00 P" => 175,
    "Other non-RES FR00 P" => 175,
    "Other non-RES MT00 P" => 175,
    "Other non-RES UK00 P" => 175,
    "Other RES" => 0,
    "Gas CCGT new CCS"        => 90,
    "Gas CCGT present 1 CCS"  => 90,
    "Gas CCGT present 2 CCS"  => 90,
    "Battery"  => 0,
    "Lignite old 2 Bio"  => 175,
    "Oil shale old"  => 150,
    "Gas CCGT CCS"  => 90,
    "VOLL" => 0,
    "HVDC" => 0
    )

    emission_factor_NOx = Dict{String, Any}( #g/kWh == kg/MWh
    "DSR"                         => 0,
    "Other non-RES"               => 0.2587,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.2334,
    "Gas CCGT old 1"              => 0.2334,
    "Gas CCGT old 2"              => 0.2334,
    "Gas CCGT present 1"          => 0.2334,
    "Gas CCGT present 2"          => 0.2334,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas Conventional old 1"      => 0.2334,
    "Gas Conventional old 2"      => 0.2334,
    "PS Closed"                   => 0.2334,
    "PS Open"                     => 0.2334,
    "Lignite new"                 => 0.2587,
    "Lignite CCS"                 => 0.2587,
    "Lignite old 1"               => 0.2587,
    "Lignite old 2"               => 0.2587,
    "Hard coal new"               => 0.2587,
    "Hard coal CCS"               => 0.2587,
    "Hard coal old 1"             => 0.2587,
    "Hard coal old 2"             => 0.2587,
    "Gas CCGT old 2 Bio"          => 0.2334,
    "Gas Conventional old 2 Bio"  => 0.2334,
    "Hard coal new Bio"           => 0.2587,
    "Hard coal old 1 Bio"         => 0.2587,
    "Hard coal old 2 Bio"         => 0.2587,
    "Heavy oil old 1 Bio"         => 0.8049,
    "Lignite old 1 Bio"           => 0.2587,
    "Oil shale new Bio"           => 0.8049,
    "Gas OCGT new"                => 0.2334,
    "Gas OCGT old"                => 0.2334,
    "Heavy oil old 1"             => 0.8049,
    "Heavy oil old 2"             => 0.8049,
    "Nuclear"                     => 0,
    "Light oil"                   => 0.8049,
    "Oil shale new"               => 0.8049,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.2334,
    "Other non-RES DKE1 P"        => 0.2334,
    "Other non-RES DKW1 P"        => 0.2334,
    "Other non-RES FI00 P"        => 0.2334,
    "Other non-RES FR00 P"        => 0.2334,
    "Other non-RES MT00 P"        => 0.2334,
    "Other non-RES UK00 P"        => 0.2334,
    "Other RES"                   => 0.2334,
    "Gas CCGT new CCS"            => 0.2334,
    "Gas CCGT present 1 CCS"      => 0.2334,
    "Gas CCGT present 2 CCS"      => 0.2334,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.2587,
    "Oil shale old"               => 0.8049,
    "Gas CCGT CCS"                => 0.2334,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )

    emission_factor_SOx = Dict{String, Any}( #g/kWh == kg/MWh
    "DSR"                         => 0,
    "Other non-RES"               => 0.3322,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.0046,
    "Gas CCGT old 1"              => 0.0046,
    "Gas CCGT old 2"              => 0.0046,
    "Gas CCGT present 1"          => 0.0046,
    "Gas CCGT present 2"          => 0.0046,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas Conventional old 1"      => 0.0046,
    "Gas Conventional old 2"      => 0.0046,
    "PS Closed"                   => 0.0046,
    "PS Open"                     => 0.0046,
    "Lignite new"                 => 0.3322,
    "Lignite CCS"                 => 0.3322,
    "Lignite old 1"               => 0.3322,
    "Lignite old 2"               => 0.3322,
    "Hard coal new"               => 0.3322,
    "Hard coal CCS"               => 0.3322,
    "Hard coal old 1"             => 0.3322,
    "Hard coal old 2"             => 0.3322,
    "Gas CCGT old 2 Bio"          => 0.0046,
    "Gas Conventional old 2 Bio"  => 0.0046,
    "Hard coal new Bio"           => 0.3322,
    "Hard coal old 1 Bio"         => 0.3322,
    "Hard coal old 2 Bio"         => 0.3322,
    "Heavy oil old 1 Bio"         => 1.1573,
    "Lignite old 1 Bio"           => 0.3322,
    "Oil shale new Bio"           => 1.1573,
    "Gas OCGT new"                => 0.0046,
    "Gas OCGT old"                => 0.0046,
    "Heavy oil old 1"             => 1.1573,
    "Heavy oil old 2"             => 1.1573,
    "Nuclear"                     => 0,
    "Light oil"                   => 1.1573,
    "Oil shale new"               => 1.1573,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.0046,
    "Other non-RES DKE1 P"        => 0.0046,
    "Other non-RES DKW1 P"        => 0.0046,
    "Other non-RES FI00 P"        => 0.0046,
    "Other non-RES FR00 P"        => 0.0046,
    "Other non-RES MT00 P"        => 0.0046,
    "Other non-RES UK00 P"        => 0.0046,
    "Other RES"                   => 0.0046,
    "Gas CCGT new CCS"            => 0.0046,
    "Gas CCGT present 1 CCS"      => 0.0046,
    "Gas CCGT present 2 CCS"      => 0.0046,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.3322,
    "Oil shale old"               => 1.1573,
    "Gas CCGT CCS"                => 0.0046,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )

    return gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx
end

