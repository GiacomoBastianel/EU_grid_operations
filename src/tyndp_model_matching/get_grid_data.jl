#####################################
# get_grid_data.jl
# Author: Hakan Ergun 24.03.2022
# Funtions to extract grid data from the scenario data files
#######################################

# Function to extract ntcs, nodes, generation capacity,
# demand time series and list of generator types
# scenario{String}, e.g. "NT2025"
function get_grid_data(scenario)    
# data source: https://www.entsoe.eu/Documents/TYNDP%20documents/TYNDP2020/Reference%20Grid%202025%20-%20TYNDP%202020.xlsx    
file_lines = "./data_sources/Reference Grid 2025 - TYNDP 2020.xlsx"
# data source: https://2020.entsos-tyndp-scenarios.eu/wp-content/uploads/2020/06/TYNDP-2020-Scenario-Datafile.xlsx.zip
file_data = "./data_sources/TYNDP-2020-Scenario-Datafile.xlsx"
# data source for all demand time series: https://tyndp.entsoe.eu/maps-data 
file_demand = "./data_sources/"*scenario*"_Demand_CY1984.csv"

# Create dataframes from CSV/XLS files
lines = XLSX.readtable(file_lines, "2025")
ntcs = _DF.DataFrame(Connection = lines[1][1], NTC = lines[1][2])

nodes_ = XLSX.readtable(file_data, "Nodes - Dict")
nodes = _DF.DataFrame(node_id = nodes_[1][1][1:64], country_text = nodes_[1][2][1:64], country = nodes_[1][3][1:64], previous_node = nodes_[1][4][1:64], latitude = nodes_[1][5][1:64], longitude = nodes_[1][6][1:64], region = nodes_[1][7][1:64], EU28 = nodes_[1][8][1:64])

arcs_ = XLSX.readtable(file_data,"Line - Dict")
arcs = _DF.DataFrame(line_id = arcs_[1][1], node_a = arcs_[1][2], node_b = arcs_[1][3])

capacity_ = XLSX.readtable(file_data, "Capacity")
capacity = _DF.DataFrame(Node_Line = capacity_[1][1], Generator_ID = capacity_[1][2], Parameter = capacity_[1][3], Case = capacity_[1][4], Scenario = capacity_[1][5], 
Year = capacity_[1][6], ClimateYear = capacity_[1][7], Value = capacity_[1][7], Simulation_ID = capacity_[1][8], Node1 = capacity_[1][9], 
Path = capacity_[1][10], Simulation_type = capacity_[1][11] , Sector = capacity_[1][12], Note = capacity_[1][13])

node_positions = nodes[:, [:latitude, :longitude]]

demand = _DF.DataFrame(CSV.File(file_demand))

gen_types = unique(capacity[!,"Generator_ID"])

# Assign generation costs based on data provided in "Charts-and-Figure-Underlying-Data-for-TYNDP-2020, Figure 36
# Choosing very good condition:
# "Very good conditions
# LCOE (Euro /MWh)"
# CCGT CCS          €89 
# CCGT New          €89 
# Nuclear           €110 
# Solar PV (com.)   €18 
# Solar PV (res.)   €18 
# Wind offshore     €59 
# Wind onshre       €25
# Assuming: 
# Other RES = €60
# hydro = battery = solar = €18
# Solar thermal = CCGT CCS = 89
# Gas. Coal, old CCGT = nuclear + 10€ = 120€
# Oil = nuclear + 20€ = 150€
# DSR > nuclear + 9  = 119€
# VOLL = 10000€

# Create dictionary with generation costs per generation type
gen_costs = Dict{String, Any}(
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
emission_factor = Dict{String, Any}( #kg/netGJ -> ton/MWh
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



inertia_constants = Dict{String, Any}(
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


return ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions
end


function add_NOx_and_SOx_emissions(input_data)

    emission_factor_NOx = Dict{String, Any}( #g/kWh == kg/Mwh
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

    emission_factor_SOx = Dict{String, Any}( #g/kWh == kg/Mwh
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
 
 for (i_id,i) in input_data["gen"]
    for l in keys(emission_factor_NOx)
        if i["type"] == l
            i["NOx_emissions"] = emission_factor_NOx["$l"]
            i["SOx_emissions"] = emission_factor_SOx["$l"]
        end
    end
 end
 
return input_data, emission_factor_NOx, emission_factor_SOx
end

