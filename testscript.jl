#=
    testscript.jl

A Julia script used for testing and development.
=#

using FinnishArchetypeBuildingModel
import FinnishArchetypeBuildingModel.ArchetypeBuildingModel.load_definitions_template

## Define required inputs

datapackage_paths = [
    "raw_data/finnish_building_stock_forecasts/",
    "raw_data/finnish_RT_structural_data/",
    "raw_data/Finnish-building-stock-default-structural-data/"
]
definitions_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finland_data\\archetype_definitions.sqlite"
weather_url = definitions_url
results_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finland_data\\backbone_input.sqlite"

num_lids = Inf # Limit number of location ids to save time on test processing.
tcw = 0.5 # Thermal conductivity weight, average.
ind = 0.1 # Assumed interior node depth.
vp = 2225140.0 # Assumed period of variations for calculating effective thermal mass.
realization = :realization
save_layouts = true


## Read raw data and run tests

m = Module()
@time data = data_from_package(datapackage_paths...)
@info "Generating data convenience functions..."
@time using_spinedb(data, m)
@info "Running structural input data tests..."
@time run_structural_tests(; limit=Inf, mod=m)
@info "Running statistical input data tests..."
@time run_statistical_tests(; limit=Inf, mod=m)


## Import and merge definitions

m = Module()
@time defs = data_from_url(definitions_url)
@info "Merge data and definitions..."
@time merge_data!(defs, data)
@info "Generating data and definitions convenience functions..."
@time using_spinedb(defs, m)


## Create, filter, and test processed statistics

@time create_processed_statistics!(m, num_lids, tcw, ind, vp)
archetype_definitions = load_definitions_template()
objclss = Symbol.(first.(archetype_definitions["object_classes"]))
relclss = Symbol.(first.(archetype_definitions["relationship_classes"]))
filter_module!(m; obj_classes=objclss, rel_classes=relclss)
@time run_input_data_tests(m)


## Process ScopeData and WeatherData, and create the ArchetypeBuildings

scope_data_dictionary, weather_data_dictionary, archetype_dictionary =
    archetype_building_processing(
        weather_url,
        save_layouts;
        realization=realization,
        mod=m
    )


## Heating/cooling demand calculations.

archetype_results_dictionary = solve_archetype_building_hvac_demand(
    archetype_dictionary;
    free_dynamics=false,
    realization=realization,
    mod=m
)

## Write the results back into the input datastore

results__building_archetype__building_node,
results__building_archetype__building_process,
results__system_link_node = initialize_result_classes!(m)
add_results!(
    results__building_archetype__building_node,
    results__building_archetype__building_process,
    results__system_link_node,
    archetype_results_dictionary;
    mod=m
)
@info "Importing `ArchetypeBuildingResults` into `$(results_url)`..."
@time import_data(
    results_url,
    [
        results__building_archetype__building_node,
        results__building_archetype__building_process,
        results__system_link_node,
    ],
    "Importing `ArchetypeBuildingResults`.",
)