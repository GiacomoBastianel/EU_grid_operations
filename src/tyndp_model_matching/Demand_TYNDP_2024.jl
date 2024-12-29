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
scenarios = ["DE", "NT", "GA"]
years = ["2030", "2040","2050"]
nt_years = ["2030", "2040"]
climate_years = ["1995", "2008", "2009"]

for i in years
    print(i)
end

# Building files
number_of_hours = 8760

# Suggestion for improvement if needed: add a first column titled "Hour" with values from 1:8760
scenarios = ["NT"]
for i in scenarios
    if i == "DE" || i == "GA"
        println("Building demand for scenario $(i)")
        for y in years
            println("Building demand for year $(y)")
            # This needs to be modified if one wants to generate the dictionaries
            file_test = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Demand_Profiles/$(i)/$(y)/ELECTRICITY_MARKET $(i) $(y).xlsx"
            df = DataFrame()
            file_xf = XLSX.readxlsx(file_test)
            areas = XLSX.sheetnames(file_xf)
            for yc in climate_years
                for area in areas
                    if yc == "1995"
                        demand_area = file_xf["$(area)"]["P13:P$(13+8759)"]
                    elseif yc == "2008"
                        demand_area = file_xf["$(area)"]["AC13:AC$(13+8759)"]
                    elseif yc == "2009"
                        demand_area = file_xf["$(area)"]["AD13:AD$(13+8759)"]
                    end
                    column_area = []
                    for i in 1:length(demand_area)
                        push!(column_area,demand_area[i])
                    end
                    column_name = Symbol("$(area)")
                    df[!, column_name] = column_area
                end
                folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Demand_Profiles/$(i)/$(y)"
                CSV.write(joinpath(folder_data,"Demand_$(i)$(y)_$(yc).csv"), df)    
            end
        end
    elseif i == "NT" 
        println("Building demand for scenario $(i)") 
        for y in nt_years
            println("Building demand for year $(y)")
            file_test = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Demand_Profiles/$(i)/$(y)/ELECTRICITY_MARKET $(i) $(y).xlsx"
            df = DataFrame()
            file_xf = XLSX.readxlsx(file_test)
            areas = XLSX.sheetnames(file_xf)
            for yc in climate_years
                for area in areas
                    if yc == "1995"
                        demand_area = file_xf["$(area)"]["R9:R$(9+8759)"]
                    elseif yc == "2008"
                        demand_area = file_xf["$(area)"]["AE9:AE$(9+8759)"]
                    elseif yc == "2009"
                        demand_area = file_xf["$(area)"]["AF9:AF$(9+8759)"]
                    end
                    column_area = []
                    for i in 1:length(demand_area)
                        push!(column_area,demand_area[i])
                    end
                    column_name = Symbol("$(area)")
                    df[!, column_name] = column_area
                end
                folder_data = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/TYNDP_2024/Demand_Profiles/$(i)/$(y)"
                CSV.write(joinpath(folder_data,"Demand_$(i)$(y)_$(yc).csv"), df)
            end
        end      
    end
end
