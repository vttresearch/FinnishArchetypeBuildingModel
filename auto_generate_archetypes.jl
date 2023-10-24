#=
    auto_generate_archetypes.jl

A script for automatically generating large numbers of archetype buildings.

Pretty hard-coded, but probably a one-shot anyhow. Originally used for

=#

using SpineInterface


## Required definitions

definitions_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finnish_building_stock_validation\\archetype_definitions.sqlite"
simulated_years = 2011:2016 #vcat(collect(2011:2016), collect(2020:2021))
bt_hs_set = [
    (
        :apartment_block,
        [
            #:district_heating,
            :electricity,
            :ground_source_heat,
            #:light_oil,
            #:natural_gas,
            #:other,
            #:peat,
            #:wood
        ]
    ),
    (
        :detached_house,
        [
            #:district_heating,
            :electricity,
            :ground_source_heat,
            #:light_oil,
            #:other,
            #:peat,
            #:wood
        ]
    ),
    (
        :terraced_house,
        [
            #:district_heating,
            :electricity,
            :ground_source_heat,
            #:light_oil,
            #:natural_gas,
            #:other,
            #:peat,
            #:wood
        ]
    )
]
bf = :IAaF_LBF_LF
bl = Symbol("YM_2011_LJ&LKV-LO_UTC+02")
bsys = :ideal_systems
bs = :FI_2020

# Definitions for tweaking the model.

storey_map = Dict(
    :apartment_block => 4.0,
    :detached_house => 1.5,
    :terraced_house => 1.5
)
cooling_setpoint_K = 25.0 + 273.15
heating_setpoint_K = 21.0 + 273.15
sys_link_node = Symbol("@system_link_node_1")
energy_efficiency_override = 0.92


## Open definitions url and fetch the Objects

m = Module()

@info "Opening definitions..."
@time using_spinedb(definitions_url, m)
bt_hs_set = [
    (m.building_type(bt), m.heat_source.(hss))
    for (bt, hss) in bt_hs_set
]
bf = m.building_fabrics(bf)
bl = m.building_loads(bl)
bsys = m.building_systems(bsys)
bs = m.building_stock(bs)
sys_link_node = m.building_node(sys_link_node)


## Loop over the sets to create the necessary building_scope and building_archetype definitions.

@info "Generating definitions..."
@time begin
    for year in simulated_years
        for (bt, hs_set) in bt_hs_set
            # Fetch or create building_archetype with parameters
            arch_name = Symbol("$(bs.name)__$(bt.name)__$(year)")
            archetype = m.building_archetype(arch_name)
            if isnothing(archetype)
                archetype = Object(arch_name, :building_archetype)
            end
            arch_param_dict = Dict(
                archetype => Dict(
                    :number_of_storeys => parameter_value(storey_map[bt.name]),
                    :indoor_air_cooling_set_point_override_K => parameter_value(cooling_setpoint_K),
                    :indoor_air_heating_set_point_override_K => parameter_value(heating_setpoint_K),
                    :weather_end => parameter_value("$(year)-12"),
                    :weather_start => parameter_value("$(year)-01"),
                    :energy_efficiency_override_multiplier => parameter_value(energy_efficiency_override)
                )
            )
            add_object_parameter_values!(m.building_archetype, arch_param_dict)
            # Fetch or create building_scope with parameters
            scope = m.building_scope(arch_name)
            if isnothing(scope)
                scope = Object(arch_name, :building_scope)
            end
            scope_param_dict = Dict(
                scope => Dict(
                    :scope_period_start_year => parameter_value(1800.0),
                    :scope_period_end_year => parameter_value(year)
                )
            )
            add_object_parameter_values!(m.building_scope, scope_param_dict)
            # Define scope via relationships
            add_relationships!(m.building_scope__building_stock, [(scope, bs)])
            add_relationships!(m.building_scope__building_type, [(scope, bt)])
            add_relationships!(m.building_scope__heat_source, [(scope, hs) for hs in hs_set])
            add_relationships!(
                m.building_scope__location_id,
                [(scope, lid) for lid in m.location_id()]
            )
            # Define archetype via relationships.
            add_relationships!(m.building_archetype__building_fabrics, [(archetype, bf)])
            add_relationships!(m.building_archetype__building_loads, [(archetype, bl)])
            add_relationships!(m.building_archetype__building_scope, [(archetype, scope)])
            add_relationships!(m.building_archetype__building_systems, [(archetype, bsys)])
            gn_param_dict = Dict(
                (archetype, sys_link_node) => Dict(
                    :grid_name => parameter_value(bt.name),
                    :node_name => parameter_value(bt.name)
                )
            )
            add_relationship_parameter_values!(
                m.building_archetype__system_link_node,
                gn_param_dict
            )
        end
    end
end


## Import generated definitions to the database at url

@info "Importing generated definitions back to `$(definitions_url)`..."
@time import_data(
    definitions_url,
    [
        m.building_archetype,
        m.building_scope,
        m.building_archetype__building_fabrics,
        m.building_archetype__building_loads,
        m.building_archetype__building_scope,
        m.building_archetype__building_systems,
        m.building_archetype__system_link_node,
        m.building_scope__building_stock,
        m.building_scope__building_type,
        m.building_scope__heat_source,
        m.building_scope__location_id
    ],
    "Autogenerated archetypes"
)