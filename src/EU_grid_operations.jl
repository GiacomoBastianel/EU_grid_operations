module EU_grid_operations

# import Compat
import JuMP
import Memento
import PowerModelsACDC
const _PMACDC = PowerModelsACDC
import PowerModels
const _PM = PowerModels
import InfrastructureModels
const _IM = InfrastructureModels
import XLSX
import JSON
import Feather
import DataFrames; const _DF = DataFrames
import CSV
import Clustering
import Plots
import PlotlyJS
import PlotlyBase
import ColorSchemes
import StatsBase
# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)

const BASE_DIR = dirname(@__DIR__)


include("create_eu_grid_model/create_european_grid.jl")
include("tyndp_model_matching/get_value.jl")
include("tyndp_model_matching/data.jl")
include("tyndp_model_matching/load_data.jl")
include("tyndp_model_matching/get_grid_data.jl")
include("tyndp_model_matching/tyndp_zonal_to_eu_grid_nodal.jl")
include("tyndp_model_matching/load_results.jl")
include("create_eu_grid_model/isolate_zones.jl")
include("create_eu_grid_model/add_network_elements.jl") #added by Matteo
include("core/add_new_hvdc_links.jl")
include("core/find_critical_contingencies.jl")
include("core/clustering.jl")
include("core/latlon2distance.jl")
include("io/process_results.jl")
include("io/plotting.jl")
include("core/batch_opf.jl")
include("core/tnep_candidates.jl")

end # module EU_grid_operations
