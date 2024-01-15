################################################################################
# Read Results
ResultsFile = Dict()

Results_file = joinpath(@__DIR__,"result_zonal_tyndp_DE2040_2007.json")
open(Results_file,"r") do f
    global ResultsFile
    dicttxt = read(f,String)  # file information to string
    ResultsFile = JSON.parse(dicttxt)  # parse and transform data
end

dict2 = Dict()
open("C:/Users/gbastian/.julia/AC-DC-CBA/results/result_zonal_tyndp_DE2040_2007.json", "r") do f
    global dict2
    dicttxt = read(f,String)  # file information to string
    dict2=JSON.parse(dicttxt)  # parse and transform data
end

pg_ = []
for i in 4304:4304
    for l in keys(result["$i"]["solution"]["gen"])
      push!(pg_,result["$i"]["solution"]["gen"]["$l"]["pg"])
    end
end

buses = []
for i in keys(input_data["bus"])
      push!(buses,[input_data["bus"]["$i"]["index"],input_data["bus"]["$i"]["string"]])
end

DK_branches_from = []
DK_branches_to = []
for i in keys(input_data["branch"])
    if input_data["branch"]["$i"]["name"][1:2] == "DK"
       push!(DK_branches_from,[i,input_data["branch"]["$i"]["name"]])   
    end
    if input_data["branch"]["$i"]["name"][6:7] == "DK"
        push!(DK_branches_to,[i,input_data["branch"]["$i"]["name"]])   
     end
end

# In the results there are 8760 results, the first keys are hours
# For each hour, in the solution, there is a power generation for each zone (64) and a power flow for each branch
a = []
for i in keys(input_data["gen"])
    if i == "3465"
        print(input_data["gen"]["$i"])
    end
end

length(result["1"]["solution"]["gen"])

