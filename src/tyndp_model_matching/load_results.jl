function load_results(tyndp_version, scenario, year, climate_year; file_name = "result_zonal_tyndp")
    result_file_name =   joinpath(BASE_DIR, "results", "TYNDP"*tyndp_version, file_name*"_"*scenario*year*"_"*climate_year*".json")
    input_file_name =    joinpath(BASE_DIR, "results", "TYNDP"*tyndp_version, "input_zonal_tyndp_"*scenario*year*"_"*climate_year*".json")
    scenario_file_name = joinpath(BASE_DIR, "results", "TYNDP"*tyndp_version, "scenario_zonal_tyndp_"*scenario*year*"_"*climate_year*".json")

    result = Dict()
    input_data = Dict()
    scenario_data = Dict()
    d = JSON.parsefile(result_file_name)
    result = JSON.parse(d)
    d = JSON.parsefile(input_file_name)
    input_data = JSON.parse(d)
    d = JSON.parsefile(scenario_file_name)
    scenario_data = JSON.parse(d)

    return result, input_data, scenario_data
end


function load_opf_results(scenario, climate_year, case, grid, hour_start, hour_end, path)

    result_file_name =   joinpath(path, join(["opfresult_hour_",hour_start, "_to_", hour_end, "_", grid, "_", scenario,"_", climate_year, ".json"]))
    input_file_name =    joinpath(path, join(["griddata_", grid, "_",scenario,"_", climate_year, ".json"]))

    result = Dict()
    input_data = Dict()
    result = JSON.parsefile(result_file_name)
    #result = JSON.parse(d)
    input_data = JSON.parsefile(input_file_name)
    #input_data = JSON.parse(d)

    return result, input_data
end