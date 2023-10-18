#=
    test_process_results.jl

A quick script for comparing results against Finnish statistics.
=#

using SpineInterface
using DataFrames

results_db_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finnish_building_stock_validation\\results.sqlite"
@info "Reading results from `$(results_db_url)`"
@time using_spinedb(results_db_url)

years = Symbol.(2011:2016)

## Calculate total HVAC consumption for each building type, heat source, process, and year

df = DataFrame(
    building_type=Symbol[],
    heat_source=Symbol[],
    process=Symbol[],
    year=Symbol[],
    total_consumption_GWh=Float64[]
)
for ((arch, process), valdict) in results__building_archetype__building_process.parameter_values
    total_cons_GWh = sum(values(valdict[:hvac_consumption_MW])) / 1000
    bs, bt, hs, y = Symbol.(split(String(arch.name), "__"))
    p = process.name
    push!(df, (bt, hs, p, y, total_cons_GWh))
end
df = unstack(df, :year, :total_consumption_GWh)
df = df[!, [:building_type, :heat_source, :process, years...]]

# If the Finnish statistics documentation is to be trusted,
# the sum of electric consumption and heat pump energy should correspond to
# the final heat demand of electrically heated buildings.
# However, this includes DHW and cooling consumption as well...

df_totals = combine(groupby(df, :building_type), years .=> sum)