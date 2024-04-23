# Script to process inputs from 3E
using XLSX

folder_inputs = "/Users/giacomobastianel/Library/CloudStorage/OneDrive-KULeuven/STERNA 2050/Input_data/"
file_name = "all_Windfarms_Ref1.xlsx"

data_xlsx = XLSX.readxlsx(joinpath("$folder_inputs","$file_name"))
input_xlsx = data_xlsx["all_polygons_4326"]
id_xlsx = input_xlsx["A2:A256"]
country_xlsx = input_xlsx["B2:B256"]
name_xlsx = input_xlsx["C2:C256"]
power_xlsx = input_xlsx["E2:E256"]
scenario_xlsx = input_xlsx["H2:H256"]
lat_xlsx = input_xlsx["I2:I256"]
lon_xlsx = input_xlsx["J2:J256"]
scenario_1_xlsx = input_xlsx["K2:K256"]
scenario_2_xlsx = input_xlsx["L2:L256"]
scenario_3_xlsx = input_xlsx["M2:M256"]

windfarms = Dict{String,Any}()
for i in collect(1:length(id_xlsx))
    windfarms["$(id_xlsx[i])"] = Dict{String,Any}()
    windfarms["$(id_xlsx[i])"]["index"] = id_xlsx[i]
    windfarms["$(id_xlsx[i])"]["name"] = name_xlsx[i]
    windfarms["$(id_xlsx[i])"]["country"] = country_xlsx[i] 
    windfarms["$(id_xlsx[i])"]["Pmax"] = power_xlsx[i]/100
    windfarms["$(id_xlsx[i])"]["year"] = scenario_xlsx[i] 
    windfarms["$(id_xlsx[i])"]["lat"] = lat_xlsx[i]
    windfarms["$(id_xlsx[i])"]["lon"] = lon_xlsx[i]
    windfarms["$(id_xlsx[i])"]["scenario_1"] = scenario_1_xlsx[i]/100
    windfarms["$(id_xlsx[i])"]["scenario_2"] = scenario_2_xlsx[i]/100
    windfarms["$(id_xlsx[i])"]["scenario_3"] = scenario_3_xlsx[i]/100
end

json_string = JSON.json(windfarms)
open(joinpath(folder_inputs,"Windfarms.json"),"w") do f 
    write(f, json_string) 
end
