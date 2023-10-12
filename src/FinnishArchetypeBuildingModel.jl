module FinnishArchetypeBuildingModel

using FinnishBuildingStockData
using ArchetypeBuildingModel

# Exports for testscript
export add_results!,
    archetype_building_processing,
    create_processed_statistics!,
    data_from_package,
    data_from_url,
    filter_module!,
    import_data,
    initialize_result_classes!,
    run_input_data_tests,
    run_statistical_tests,
    run_structural_tests,
    solve_archetype_building_hvac_demand,
    using_spinedb,
    merge_data!

end # module FinnishArchetypeBuildingModel
