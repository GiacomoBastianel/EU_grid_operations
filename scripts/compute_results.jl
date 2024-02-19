function compute_VOLL(grid,number_of_hours,results_dict,vector)
    for l in keys(results_dict)
        for i in keys(results_dict[l])
            sum_ = 0
            for (g_id,g) in grid["gen"]
                if g["type_tyndp"] == "VOLL"
                    if haskey(results_dict[l][i]["solution"],"gen")
                        sum_ = sum_ + results_dict[l][i]["solution"]["gen"][g_id]["pg"]*100
                    end
                end
            end
            push!(vector,sum_)
        end
    end 
end

function compute_RES_generation(grid,number_of_hours,results_dict,vector)
    for l in keys(results_dict)
        for i in keys(results_dict[l])
            sum_ = 0
            for (g_id,g) in grid["gen"]
                if g["type_tyndp"] == "Solar PV" || g["type_tyndp"] == "Onshore Wind" || g["type_tyndp"] == "Offshore Wind"  
                    if haskey(results_dict[l][i]["solution"],"gen")
                        sum_ = sum_ + results_dict[l][i]["solution"]["gen"][g_id]["pg"]*100
                    end
                end
            end
            push!(vector,sum_)
        end
    end
end

function compute_RES_generation_per_zone(grid,number_of_hours,results_dict,vector, zone)
    for i in 1:number_of_hours
        sum_ = 0
        for (g_id,g) in grid["gen"]
            if g["gen_bus"] == zone
                if g["type"] != "VOLL" || g["type"] != "Conventional" 
                    sum_ = sum_ + results_dict["$i"]["solution"]["gen"][g_id]["pg"]*100
                end
            end
        end
        push!(vector,sum_)
    end
end

function compute_non_RES_generation_per_zone(grid,number_of_hours,results_dict,vector, zone)
    for i in 1:number_of_hours
        sum_ = 0
        for (g_id,g) in grid["gen"]
            if g["gen_bus"] == zone
                if g["type"] == "VOLL" || g["type"] == "Conventional" 
                    sum_ = sum_ + results_dict["$i"]["solution"]["gen"][g_id]["pg"]*100
                end
            end
        end
        push!(vector,sum_)
    end
end




function compute_CO2_emissions(grid,number_of_hours,results_dict,vector)
    for l in keys(results_dict)
        for i in keys(results_dict[l])
            sum_ = 0
            for (g_id,g) in grid["gen"]
                if g["type_tyndp"] == "Solar PV" || g["type_tyndp"] == "Onshore Wind" || g["type_tyndp"] == "Offshore Wind" || g["type_tyndp"] == "Nuclear" || g["type_tyndp"] == "Gas CCGT new" || g["type_tyndp"] == "Heavy oil old 1 Bio" || g["type_tyndp"] == "Hard coal old 2 Bio" 
                    if haskey(results_dict[l][i]["solution"],"gen")
                        sum_ = sum_ + results_dict[l][i]["solution"]["gen"][g_id]["pg"]*g["C02_emission"]*100
                    end
                end
            end
            push!(vector,sum_)
        end
    end
end

function compute_NOx_emissions(grid,number_of_hours,results_dict,vector)
    for l in keys(results_dict)
        for i in keys(results_dict[l])
            sum_ = 0
            for (g_id,g) in grid["gen"]
                if g["type_tyndp"] == "Solar PV" || g["type_tyndp"] == "Onshore Wind" || g["type_tyndp"] == "Offshore Wind" || g["type_tyndp"] == "Nuclear" || g["type_tyndp"] == "Gas CCGT new" || g["type_tyndp"] == "Heavy oil old 1 Bio" || g["type_tyndp"] == "Hard coal old 2 Bio" 
                    if haskey(results_dict[l][i]["solution"],"gen")
                        sum_ = sum_ + results_dict[l][i]["solution"]["gen"][g_id]["pg"]*g["NOx_emission"]*100
                    end
                end
            end
            push!(vector,sum_)
        end
    end
end

function compute_SOx_emissions(grid,number_of_hours,results_dict,vector)
    for l in keys(results_dict)
        for i in keys(results_dict[l])
            sum_ = 0
            for (g_id,g) in grid["gen"]
                if g["type_tyndp"] == "Solar PV" || g["type_tyndp"] == "Onshore Wind" || g["type_tyndp"] == "Offshore Wind" || g["type_tyndp"] == "Nuclear" || g["type_tyndp"] == "Gas CCGT new" || g["type_tyndp"] == "Heavy oil old 1 Bio" || g["type_tyndp"] == "Hard coal old 2 Bio" 
                    if haskey(results_dict[l][i]["solution"],"gen")
                        sum_ = sum_ + results_dict[l][i]["solution"]["gen"][g_id]["pg"]*g["SOx_emission"]*100
                    end
                end
            end
            push!(vector,sum_)
        end
    end
end

function compute_congestions(grid,number_of_hours,results_dict,vector,branches)
    for i in 1:number_of_hours
        branches["$i"] = []
        for (g_id,g) in grid["branch"]
            push!(branches["$i"], [g_id,abs(results_dict["$i"]["solution"]["branch"][g_id]["pt"])/g["rate_a"]])
        end
        push!(vector,findmax(branches["$i"]))
    end
end

function compute_congestions_HVDC(grid,number_of_hours,results_dict,vector,branches)
    for i in 1:number_of_hours
        branches["$i"] = []
        for (g_id,g) in grid["branchdc"]
            if g_id == "9" || g_id == "10" || g_id == "11" 
            else
                push!(branches["$i"], [g_id,abs(results_dict["$i"]["solution"]["branchdc"][g_id]["pt"])/g["rateA"]])
            end
        end
        push!(vector,findmax(branches["$i"]))
    end
end

function compute_congestions_line_AC(grid,number_of_hours,results_dict,branches,n_branch)
    for i in 1:number_of_hours
        branches["$i"] = Dict{String,Any}()
        for (g_id,g) in grid["branch"]
            if g_id == "$n_branch"
               branches["$i"] = deepcopy(results_dict["$i"]["solution"]["branch"][g_id]["pt"]/g["rate_a"])
            end
        end
    end
end

function compute_congestions_line_HVDC(grid,number_of_hours,results_dict,branches,n_branchdc)
    for i in 1:number_of_hours
        branches["$i"] = Dict{String,Any}()
        for (g_id,g) in grid["branchdc"]
            if g_id == "$n_branchdc"
               branches["$i"] = deepcopy(results_dict["$i"]["solution"]["branchdc"][g_id]["pt"]/g["rateA"])
            end
        end
    end
end


function gen_values()
    gen_costs = Dict{String, Any}( # €/MWh
    "DSR" => 119,
    "Other non-RES"  => 120,
    "Offshore Wind"  => 59,
    "Onshore Wind"  => 25,
    "Solar PV"  => 18,
    "Solar Thermal"  => 89,
    "Gas CCGT new" => 89,
    "Gas CCGT old 1"  => 89,
    "Gas CCGT old 2"  => 89,
    "Gas CCGT present 1"  => 89,
    "Gas CCGT present 2"  => 89,
    "Reservoir"  => 18,
    "Run-of-River"  => 18,
    "Gas conventional old 1"  => 120,
    "Gas conventional old 2"  => 120,
    "PS Closed"  => 120,
    "PS Open"  => 120,
    "Lignite new"  => 120,
    "Lignite old 1"  => 120,
    "Lignite old 2"  => 120,
    "Hard coal new"  => 120,
    "Hard coal old 1"  => 120,
    "Hard coal old 2"  => 120,
    "Gas CCGT old 2 Bio"  => 120,
    "Gas conventional old 2 Bio"  => 120,
    "Hard coal new Bio"  => 120,
    "Hard coal old 1 Bio"  => 120,
    "Hard coal old 2 Bio" => 120,
    "Heavy oil old 1 Bio"  => 120,
    "Lignite old 1 Bio"  => 120,
    "Oil shale new Bio"  => 120,
    "Gas OCGT new"  => 89,
    "Gas OCGT old"  => 120,
    "Heavy oil old 1"  => 150,
    "Heavy oil old 2"  => 120,
    "Nuclear" => 110,
    "Light oil" => 140,
    "Oil shale new" => 150,
    "P2G" => 120,
    "Other non-RES DE00 P" => 120,
    "Other non-RES DKE1 P" => 120,
    "Other non-RES DKW1 P" => 120,
    "Other non-RES FI00 P" => 120,
    "Other non-RES FR00 P" => 120,
    "Other non-RES MT00 P" => 120,
    "Other non-RES UK00 P" => 120,
    "Other RES" => 60,
    "Gas CCGT new CCS"  => 89,
    "Gas CCGT present 1 CCS"  => 60,
    "Gas CCGT present 2 CCS" => 60,
    "Battery"  => 119,
    "Lignite old 2 Bio"  => 120,
    "Oil shale old"  => 150,
    "Gas CCGT CCS"  => 89,
    "VOLL" => 10000,
    "HVDC" => 0
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
    "Gas conventional old 1"  => (57*3.6)*10^(-3),
    "Gas conventional old 2"  => (57*3.6)*10^(-3),
    "PS Closed"  => (57*3.6)*10^(-3),
    "PS Open"  =>   (57*3.6)*10^(-3),
    "Lignite new"  =>   (101*3.6)*10^(-3),
    "Lignite old 1"  => (101*3.6)*10^(-3),
    "Lignite old 2"  => (101*3.6)*10^(-3),
    "Hard coal new"  => (94*3.6)*10^(-3),
    "Hard coal old 1"  => (94*3.6)*10^(-3),
    "Hard coal old 2"  => (94*3.6)*10^(-3),
    "Gas CCGT old 2 Bio"          => (57*3.6)*10^(-3),
    "Gas conventional old 2 Bio"  => (57*3.6)*10^(-3),
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
    "Gas conventional old 1"    => 5,
    "Gas conventional old 2"    => 5,
    "PS Closed"                 => 3,
    "PS Open"                   => 3,
    "Lignite new"               => 4,
    "Lignite old 1"             => 4,
    "Lignite old 2"             => 4,
    "Hard coal new"             => 4,
    "Hard coal old 1"           => 4,
    "Hard coal old 2"           => 4,
    "Gas CCGT old 2 Bio"        => 5,
    "Gas conventional old 2 Bio"=> 5,
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
    "Gas conventional old 1"  => 90,
    "Gas conventional old 2"  => 90,
    "PS Closed"  => 150,
    "PS Open"  =>   150,
    "Lignite new"  =>   175,
    "Lignite old 1"  => 175,
    "Lignite old 2"  => 175,
    "Hard coal new"  => 175,
    "Hard coal old 1"  => 175,
    "Hard coal old 2"  => 175,
    "Gas CCGT old 2 Bio"          => 90,
    "Gas conventional old 2 Bio"  => 90,
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
    "Gas conventional old 1"      => 0.2334,
    "Gas conventional old 2"      => 0.2334,
    "PS Closed"                   => 0.2334,
    "PS Open"                     => 0.2334,
    "Lignite new"                 => 0.2587,
    "Lignite old 1"               => 0.2587,
    "Lignite old 2"               => 0.2587,
    "Hard coal new"               => 0.2587,
    "Hard coal old 1"             => 0.2587,
    "Hard coal old 2"             => 0.2587,
    "Gas CCGT old 2 Bio"          => 0.2334,
    "Gas conventional old 2 Bio"  => 0.2334,
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
    "Gas conventional old 1"      => 0.0046,
    "Gas conventional old 2"      => 0.0046,
    "PS Closed"                   => 0.0046,
    "PS Open"                     => 0.0046,
    "Lignite new"                 => 0.3322,
    "Lignite old 1"               => 0.3322,
    "Lignite old 2"               => 0.3322,
    "Hard coal new"               => 0.3322,
    "Hard coal old 1"             => 0.3322,
    "Hard coal old 2"             => 0.3322,
    "Gas CCGT old 2 Bio"          => 0.0046,
    "Gas conventional old 2 Bio"  => 0.0046,
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

function assigning_gen_values(grid_m)
    for (g_id,g) in grid_m["gen"]
        for i in eachindex(gen_costs)
            if g["type_tyndp"] == i
                g["C02_emission"] = emission_factor_CO2[i]
                g["NOx_emission"] = emission_factor_NOx[i]
                g["SOx_emission"] = emission_factor_SOx[i]
                g["start_up_cost"] = start_up_cost[i]
                g["inertia_constant"] = inertia_constants[i]
            #elseif g["name"][1:end-1] == "Conventional_gen_"
            #    g["C02_emission"] = emission_factor_CO2["Gas CCGT new"]
            #    g["NOx_emission"] = emission_factor_NOx["Gas CCGT new"]
            #    g["SOx_emission"] = emission_factor_SOx["Gas CCGT new"]
            #    g["start_up_cost"] = start_up_cost["Gas CCGT new"]
            #    g["inertia_constant"] = inertia_constants["Gas CCGT new"]
            end
        end
    end
    return grid_m
end

function compute_energy_through_a_line(number_of_hours,results_dict,n_branch,sum_)
    for i in 1:number_of_hours
        for (g_id,g) in results_dict["$i"]["solution"]["branch"]
            if g_id == "$n_branch"
               sum_ = sum_ + abs(results_dict["$i"]["solution"]["branch"][g_id]["pt"])
            end
        end
    end
    return sum_
end

function compute_energy_through_a_dc_line(number_of_hours,results_dict,n_branch,sum_)
    for i in 1:number_of_hours
        for (g_id,g) in results_dict["$i"]["solution"]["branchdc"]
            if g_id == "$n_branch"
               sum_ = sum_ + abs(results_dict["$i"]["solution"]["branchdc"][g_id]["pt"])
            end
        end
    end
    return sum_
end