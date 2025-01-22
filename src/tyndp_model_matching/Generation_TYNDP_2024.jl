#####################################
# Demand_TYNDP_2024.jl
# Author: Giacomo Bastianel 23.12.2024
# Funtions to build demand data from the scenario data files TYNDP 2024
#######################################
import XLSX
import CSV
import JSON
using DataFrames

# Add auxiliary functions to construct input and scenario data dictionary
folder_path = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/2030"
gen_capacities = XLSX.readxlsx(joinpath(folder_path,"PEMMDB_AL00_NationalTrends_2030.xlsx"))
# Generating the list of generation types
gen_types = []
#push!(gen_types,"Generation type")

function add_generation_type(capacities)
    ## Nuclear
    push!(capacities,"$(gen_capacities["Thermal"]["A12"])")

    ## Hard coal
    coal_types = []
    coal = collect(14:2:20)
    for i in coal
        push!(coal_types,"$(gen_capacities["Thermal"]["A14"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A14"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Lignite
    lignite_types = []
    lignite = collect(22:2:28)
    for i in lignite
        push!(lignite_types,"$(gen_capacities["Thermal"]["A22"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A22"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Gas
    gas_types = []
    gas = collect(30:2:44)
    for i in gas
        push!(gas_types,"$(gen_capacities["Thermal"]["A30"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A30"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Light oil
    push!(capacities,"$(gen_capacities["Thermal"]["A46"])")

    ## Heavy oil
    heavy_oil_types = []
    heavy_oil = collect(48:2:50)
    for i in heavy_oil
        push!(heavy_oil_types,"$(gen_capacities["Thermal"]["A48"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A48"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Oil shale
    shale_oil_types = []
    shale_oil = collect(52:2:54)
    for i in shale_oil
        push!(shale_oil_types,"$(gen_capacities["Thermal"]["A52"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A52"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Gas
    gas_types = []
    gas = collect(56:2:58)
    for i in gas
        push!(gas_types,"$(gen_capacities["Thermal"]["A56"]) $(gen_capacities["Thermal"]["B$(i)"])")
        push!(capacities,"$(gen_capacities["Thermal"]["A56"]) $(gen_capacities["Thermal"]["B$(i)"])")
    end

    ## Other Non-RES
    push!(capacities,"Other non-RES")

    ## Battery
    push!(capacities,"Battery")

    ## Wind
    push!(capacities,"Onshore Wind")
    push!(capacities,"Offshore Wind")

    ## Solar
    push!(capacities,"Solar PV")

    ## Hydro
    push!(capacities,"Reservoir")   
    push!(capacities,"Run-of-River")

    ## Other RES
    push!(capacities,"Other RES")
end
add_generation_type(gen_types)

years = ["2030", "2040","2050"]
# This needs to be modified if one wants to generate the dictionaries
folder_path = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/2030"
file_names = readdir(folder_path)
zones_from_files = [file[8:11] for file in file_names if endswith(file, ".xlsx")]


# Add here now generation capacity for each zone
function add_gen_capacity_per_zone(zones,years,gen_types)
    for y in years
            folder_path = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/$(y)"
            df = DataFrame()
            column_name = Symbol("Generation types")
            df[!, column_name] = gen_types
        for z in zones
            gen_capacities = XLSX.readxlsx(joinpath(folder_path,"PEMMDB_$(z)_NationalTrends_$(y).xlsx"))
            capacities = []
            ## Nuclear
            push!(capacities,gen_capacities["Thermal"]["C12"])

            ## Hard coal
            coal = collect(14:2:20)
            for i in coal
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Lignite
            lignite = collect(22:2:28)
            for i in lignite
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Gas
            gas = collect(30:2:44)
            for i in gas
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Light oil
            push!(capacities,gen_capacities["Thermal"]["C46"])

            ## Heavy oil
            heavy_oil = collect(48:2:50)
            for i in heavy_oil
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Oil shale
            shale_oil = collect(52:2:54)
            for i in shale_oil
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Gas
            gas = collect(56:2:58)
            for i in gas
                push!(capacities,gen_capacities["Thermal"]["C$(i)"])
            end

            ## Other Non-RES
            non_res = []
            for i in 19:(8759+19)
                push!(non_res,gen_capacities["Other Non-RES"]["C$(i)"])
            end
            push!(capacities,sum(non_res)/length(non_res))

            ## Battery
            push!(capacities,gen_capacities["Battery"]["C12"])

            ## Wind
            push!(capacities,gen_capacities["Wind"]["B8"])
            push!(capacities,gen_capacities["Wind"]["B9"])

            ## Solar
            push!(capacities,gen_capacities["Solar"]["B9"])

            ## Hydro
            push!(capacities,gen_capacities["Hydro"]["B15"])   
            push!(capacities,gen_capacities["Hydro"]["B9"])

            ## Other RES
            push!(capacities,gen_capacities["Other RES"]["B8"])
            print(capacities)
            println(length(capacities))
            column_name = Symbol("$(z)")
            df[!, column_name] = capacities
        end
        folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/$(y)"
        CSV.write(joinpath(folder_data,"Installed_generation_capacity_NationalTrends_$(y).csv"), df)    
    end
end
add_gen_capacity_per_zone(zones_from_files,years,gen_types)
# in the .csv files, the units for RES are correct [GW] even if values supposedly in MW are shown

# Building files
number_of_hours = 8760

folder_PEMMDB2 = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2"

function correct_files(years)
    for y in years
        file = CSV.read(joinpath(folder_PEMMDB2,"$(y)/Installed_generation_capacity_NationalTrends_$(y).csv"),DataFrame)
        new_file = deepcopy(file)
        for r in 1:nrow(new_file)
            if r != 27 && r != 28 && r != 29
                for i in 2:78
                    if ismissing(new_file[r, i])
                        new_file[r, i] = 0
                    else
                        if typeof(file[r, i]) == Int64
                            if (r == 14 && i == 53) || (r == 24 && i == 53)
                                new_file[r, i] = 0.0
                            else
                                v = Float64.(file[r, i])
                                new_file[r, i] = v / 10^3
                            end
                        else
                            new_file[r, i] = file[r, i] / 10^3
                        end
                    end
                end
            end
        end
        folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/$(y)"
        CSV.write(joinpath(folder_data,"Installed_generation_capacity_NationalTrends_$(y)_GW.csv"),new_file)   
        CSV.write(joinpath(folder_data,"Installed_generation_capacity_NT$(y)_GW.csv"),new_file)   
    end     
    # In MW
    for y in years
        file = CSV.read(joinpath(folder_PEMMDB2,"$(y)/Installed_generation_capacity_NationalTrends_$(y)_GW.csv"),DataFrame)
        new_file = deepcopy(file)
        for r in 1:nrow(new_file)
            for i in 2:78
                new_file[r, i] = file[r, i] * 10^3
            end
        end
        folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/$(y)"
        CSV.write(joinpath(folder_data,"Installed_generation_capacity_NationalTrends_$(y)_MW.csv"),new_file)   
        CSV.write(joinpath(folder_data,"Installed_generation_capacity_NT$(y)_MW.csv"),new_file)   
    end 
end
correct_files(years)

folder_path = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024"
RES_capacities = XLSX.readxlsx(joinpath(folder_path,"20231103 - Final Supply Inputs for TYNDP 2024 Scenarios 2.xlsx"))


folder_PEMMDB2 = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2"

scenarios = ["DE", "GA"]
years = ["2030", "2040", "2050"]
function add_RES_scenarios(years,scenarios)
    for s in scenarios
        println("Scenario is $(s)")
        for y in years
            println("Year is $(y)")
            file = CSV.read(joinpath(folder_PEMMDB2,"NT/$(y)/Installed_generation_capacity_NT$(y)_MW.csv"),DataFrame)
            new_file = deepcopy(file)

            for z in 1:length(RES_capacities["1.1."]["B5:B58"])
                for n in names(new_file)[2:78]
                    if n == RES_capacities["1.1."]["B5:B58"][z] && z != 38
                        println("n is $(n)")
                        println("z is $(z), z zone is $(RES_capacities["1.1."]["B5:B58"][z])")
                        if s == "DE"
                            if y == "2030"
                                # Onshore Wind
                                    new_file[27, n] = Float64(RES_capacities["1.2."]["C$(4+z)"])
                                # Offshore Wind
                                    new_file[28, n] = Float64(RES_capacities["1.3."]["C$(4+z)"])
                                # Solar PV
                                    new_file[29, n] = Float64(RES_capacities["1.1."]["C$(4+z)"])
                            elseif y == "2040" 
                                # Onshore Wind
                                    new_file[27, n] = Float64(RES_capacities["1.2."]["D$(4+z)"])
                                # Offshore Wind
                                    new_file[28, n] = Float64(RES_capacities["1.3."]["E$(4+z)"])
                                # Solar PV
                                    new_file[29, n] = Float64(RES_capacities["1.1."]["D$(4+z)"])
                            elseif y == "2050" 
                                # Onshore Wind
                                new_file[27, n] = Float64(RES_capacities["1.2."]["E$(4+z)"])
                                # Offshore Wind
                                new_file[28, n] = Float64(RES_capacities["1.3."]["G$(4+z)"])
                                # Solar PV
                                new_file[29, n] = Float64(RES_capacities["1.1."]["E$(4+z)"])
                            end
                        elseif s == "GA"
                            if y == "2030"
                                # Onshore Wind
                                    new_file[27, n] = Float64(RES_capacities["1.2."]["H$(4+z)"])
                                # Offshore Wind
                                    new_file[28, n] = Float64(RES_capacities["1.3."]["M$(4+z)"])
                                # Solar PV
                                    new_file[29, n] = Float64(RES_capacities["1.1."]["H$(4+z)"])
                            elseif y == "2040" 
                                # Onshore Wind
                                    new_file[27, n] = Float64(RES_capacities["1.2."]["I$(4+z)"])
                                # Offshore Wind
                                    new_file[28, n] = Float64(RES_capacities["1.3."]["N$(4+z)"])
                                # Solar PV
                                    new_file[29, n] = Float64(RES_capacities["1.1."]["I$(4+z)"])
                            elseif y == "2050" 
                                # Onshore Wind
                                    new_file[27, n] = Float64(RES_capacities["1.2."]["J$(4+z)"])
                                # Offshore Wind
                                    new_file[28, n] = Float64(RES_capacities["1.3."]["O$(4+z)"])
                                # Solar PV
                                    new_file[29, n] = Float64(RES_capacities["1.1."]["J$(4+z)"])
                            end 
                        end  
                    end
                end
            end                             
            folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Generation_capacity_per_zone/PEMMDB2/$(s)/$(y)"
            CSV.write(joinpath(folder_data,"Installed_generation_capacity_$(s)$(y)_MW.csv"),new_file)   
        end 
    end
end
add_RES_scenarios(years,scenarios)