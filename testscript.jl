#=
    testscript.jl

A Julia script used for testing and development.
=#

using FinnishArchetypeBuildingModel
import FinnishArchetypeBuildingModel.ArchetypeBuildingModel.load_definitions_template

## Define required inputs

datapackage_paths = [
    "raw_data\\finnish_building_stock_forecasts\\datapackage.json",
    "raw_data\\finnish_RT_structural_data\\datapackage.json",
    "raw_data\\Finnish-building-stock-default-structural-data\\datapackage.json"
]
definitions_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finland_data\\archetype_definitions.sqlite"
objects_url = definitions_url
weather_url = definitions_url
results_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finland_data\\backbone_input.sqlite"

num_lids = 3.0 # Limit number of location ids to save time on test processing.
tcw = 0.5 # Thermal conductivity weight, average.
ind = 0.1 # Assumed interior node depth.
vp = 1209600.0 # Assumed period of variations for calculating effective thermal mass.
realization = :realization
save_layouts = true


## Read raw data and run tests

m_data = Module()
@time data = data_from_package(datapackage_paths...)
@info "Generating data convenience functions..."
@time using_spinedb(data, m_data)
@info "Running structural input data tests..."
@time run_structural_tests(; limit=Inf, mod=m_data)
@info "Running statistical input data tests..."
@time run_statistical_tests(; limit=Inf, mod=m_data)


## Import object classes relevant for `building_scope` definitions into <objects> url if defined.

if !isnothing(objects_url)
    @info "Importing definition-relevant object classes into `$(objects_url)`..."
    objclss = [:building_stock, :building_type, :heat_source, :location_id]
    @time import_data(
        objects_url,
        [m_data._spine_object_classes[oc] for oc in objclss],
        "Auto-import object classes relevant for archetype definitions."
    )
end


## Create and filter processed statistics

@time create_processed_statistics!(m_data, num_lids, tcw, ind, vp)
archetype_template = load_definitions_template()
objclss = Symbol.(first.(archetype_template["object_classes"]))
relclss = Symbol.(first.(archetype_template["relationship_classes"]))
filter_module!(m_data; obj_classes=objclss, rel_classes=relclss)


## Import and merge definitions, run input data tests.

m_defs = Module()
@info "Generating definitions convenience functions..."
@time using_spinedb(definitions_url, m_defs)
@info "Merge definitions..."
@time merge_spine_modules!(m_defs, m_data)
@time run_input_data_tests(m_defs)


## Process ScopeData and WeatherData, and create the ArchetypeBuildings

scope_data_dictionary, weather_data_dictionary, archetype_dictionary =
    archetype_building_processing(
        weather_url,
        save_layouts;
        realization=realization,
        mod=m_defs
    )


## Heating/cooling demand calculations.

archetype_results_dictionary = solve_archetype_building_hvac_demand(
    archetype_dictionary;
    free_dynamics=false,
    realization=realization,
    mod=m_defs
)

## Write the results back into the input datastore

results__building_archetype__building_node,
results__building_archetype__building_process,
results__system_link_node = initialize_result_classes!(m_defs)
add_results!(
    results__building_archetype__building_node,
    results__building_archetype__building_process,
    results__system_link_node,
    archetype_results_dictionary;
    mod=m_defs
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