__precompile__() 
module PhenoJl

using CSV
using DataFrames
using MLJ
using ScientificTypes
using StatsBase
using Comonicon
using YAML
using PyCall
using PrecompileTools: @setup_workload, @compile_workload 

export phenotype

const HC = PyNULL()
const SP = PyNULL()

function __init__()
    copy!(HC, pyimport_conda("scipy.cluster.hierarchy", "scipy"))
    copy!(SP, pyimport_conda("scipy.spatial", "scipy"))
end

abstract type SepsisDataset end;

const SIGNATURE15 = [:HDL, :APOA1, :total_SOFA, :total_cholesterol, :ICAM1, :LDL, 
                    :SOFA_cardio, :SOFA_liver, :PON, :SOFA_neuro, :temperature, 
                    :respiration_score, :SOFA_renal, :sys_bp, :SOFA_coag]

struct Sepsis15Features <: SepsisDataset
    data::DataFrame
    features::Vector{Symbol}
    dict::Dict{Symbol,Symbol}

    Sepsis15Features(
        data::DataFrame; 
        features::Vector{Symbol}=SIGNATURE15, 
        dict::Dict{Symbol,Symbol}=Dict{Symbol,Symbol}()
    ) = new(data, features, dict)
end

"""
Loads a CSV file from disk into DataFrame.
Drops columns :cluster and :phenotype, as those will be redefined.
"""
function load(filename::String)
    ds = CSV.read(filename, DataFrame)
    colnames = Symbol.(names(ds))
    nots = [c for c in [:phenotype, :cluster] if c in colnames]
    select(ds, Not(nots))
end

"Builds the file name for the phenotyped dataset"
function output_filename(filename::String, outdir::String="")
    joinpath(outdir, splitext(basename(filename))[1]*"_phenotyped.csv")
end

"Tests that all the predictive features should be in the datset"
function test_columns(sd::SepsisDataset)
    colnames = Symbol.(names(sd.data))
    mappedfeatures = mappedcols(sd.features, sd.dict)
    missingcols = [f for f in mappedfeatures if f ∉ colnames]
    errormsg = "The following columns were not found in the dataset: $missingcols"
    length(missingcols) == 0 || error(errormsg)
end

"""
Tests scientific types of Columns
It reports on missing values first to improve readability of the results
"""
function test_types(sd::SepsisDataset)
    ds = coredata(sd)
    colnames = names(ds)
    scitypes = elscitype.(eachcol(ds))
    types = eltype.(eachcol(ds))

    missings = [ t >: Missing for t in scitypes]
    misscols = colnames[missings]
    length(misscols)>0 && throw(MissingException("TypeError: Columns $misscols have missing values."))
    
    infinite = [ t <: Infinite for t in scitypes]
    errcols = colnames[.!infinite]
    length(errcols)>0 && error("TypeError: Columns $errcols (types: $(types[.!infinite])) cannot implicitely be converted to numerical.")
    true
end

"Checks if a dataframe is ready for clustering"
function validate(sd::SepsisDataset)
    test_columns(sd)
    test_types(sd)
end

"Maps a column name to a value if present in provided dictionary"
function mappedcols(cols::Vector{Symbol}, dict::Dict{Symbol,Symbol}=Dict{Symbol,Symbol}())
    [k ∈ keys(dict) ? dict[k] : k for k in cols]
end

"Subset of the dataset formed by predicitve features"
function coredata(sd::SepsisDataset)
    select(sd.data, mappedcols(sd.features, sd.dict))
end

"Normalize (mean/sd) the DataFrame"
function normalize(ds::DataFrame)
    Standardizer = MLJ.@load Standardizer pkg=MLJModels verbosity=0
    dict_continuous = Dict([Symbol(n)=>Continuous for n in names(ds)]);
    coerce!(ds, dict_continuous)
    mach = machine(Standardizer(), ds) |> x -> MLJ.fit!(x, verbosity=0)
    MLJ.transform(mach, ds)
end

"Cap outliers in normalized dataframe to max_std"
function cap_outliers!(ds::DataFrame, max_std::Integer)
    mapcols(col -> col .= ifelse.(col .> max_std, max_std, col), ds);
    mapcols(col -> col .= ifelse.(col .< -max_std, -max_std, col), ds);
end

"Assigns a cluster to each sample"
function cluster(ds::DataFrame)
    X = Matrix(ds)
    dist_samples = 1 .- corspearman(permutedims(X))
    dist_sq = SP.distance.squareform(dist_samples)
    samples_linkage = HC.linkage(dist_sq, method=:ward)
    clusters = HC.cut_tree(samples_linkage, n_clusters=2)
    clusters[:,1] .+ 1 # matches Julia's 1-base index
end

"Add phenotype information given provided clusterization"
function add_phenotype!(sd::Sepsis15Features, clusters::Vector{Int})
    ldl, hdl, total_cholesterol = mappedcols([:LDL, :HDL, :total_cholesterol], sd.dict)
    ds = sd.data
    ds[!, :cluster] = clusters
    gbc = groupby(ds, :cluster)
    levels = combine(gbc, ldl=>mean, hdl=>mean, total_cholesterol=>mean, renamecols=false)
    sort!(levels, [total_cholesterol, ldl, hdl]) # this is equivalent to looking just at total chol
    hypo = levels[1, :cluster] # cluster with lower cholesterol levels
    for f in [total_cholesterol, ldl, hdl]
        levels[1, f] < levels[2, f] || @warn "Level of $f is higher in HYPO than NORMO"
    end
    ds[!, :phenotype] .= "NORMO"
    ds[ ds.cluster .== hypo, :phenotype] .= "HYPO"
    ds
end

"Main function used to phenothype a dataset using the 15 features"
function phenotype15features!(ds::DataFrame; kwargs...)
    sd = Sepsis15Features(ds; kwargs...)
    validate(sd)
    data = coredata(sd)
    n = normalize(data)
    cap_outliers!(n, 3)
    clusters = cluster(n)
    add_phenotype!(sd, clusters)
end

"Loads a YAML file and casts provided parameters"
function load_config(filename::String)
    c = YAML.load_file(filename)

    f2m = "signature_to_column_mapping"
    errormsg = "Parameter $f2m should be present in the configuration file."
    dict::Dict{Symbol, Symbol} = begin f2m in keys(c) ? c[f2m] : error(errormsg) end |>
        d -> Dict([(Symbol(k), Symbol(v)) for (k,v) in d])

    f = "features"
    features::Vector{Symbol} = begin f in keys(c) ? c[f] : [] end |>
        v -> [Symbol(w) for w in v]

    res::Dict{Symbol, Any} = Dict(:dict=>dict)
    if length(features)>0 res[:features] = features end
    
    res
end

"Command line function"
@main function phenotype(datafile::String; configfile::String="", outdir::String="", write_output::Int=1, method=:features15)
    method == :features15 || error("Phenotying algorithm not implemented. (options are: :features15)")
    data = load(datafile)
    filename = output_filename(datafile, outdir)
    config = length(configfile)==0 ? Dict{Symbol,Symbol}() : load_config(configfile)
    phenotyped = phenotype15features!(data; config...)
    write_output==1 && CSV.write(filename, phenotyped)
    phenotyped
end

@setup_workload begin
    cluster_csv = "./fixtures/cluster.csv"
    cluser_csv_conf = "./fixtures/cluster.csv.yml" 

    @compile_workload begin
        copy!(HC, pyimport_conda("scipy.cluster.hierarchy", "scipy"))
        copy!(SP, pyimport_conda("scipy.spatial", "scipy"))
        ds = phenotype(cluster_csv; configfile=cluser_csv_conf, write_output=1)
        # ds = load(cluster_csv)
        # n = normalize(ds)
        # clusters = [1, 1, 2, 2, 2] # P.cluster(ds)
        # c = load_config(cluser_csv_conf)
    end
end

end # module PhenoJl
