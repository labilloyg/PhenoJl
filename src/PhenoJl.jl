module PhenoJl

using DataFrames
using MLJ
using ScientificTypes
using CSV
#using Distances
using Clustering
using StatsBase

"Load a CSV file from disk into DataFrame"
function load(filename::String)
    CSV.read(filename, DataFrame)
end

"""
Tests scientific types of Columns
It reports on missing values first to improve readability of the results
"""
function test_types(ds::DataFrame)
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
function validate(ds::DataFrame)
    test_types(ds)
end

"Normalize (mean/sd) the DataFrame"
function normalize(ds::DataFrame)
    Standardizer = MLJ.@load Standardizer pkg=MLJModels verbosity=0
    dict_continuous = Dict([Symbol(n)=>Continuous for n in names(ds)]);
    coerce!(ds, dict_continuous)
    mach = machine(Standardizer(), ds) |> MLJ.fit!
    MLJ.transform(mach, ds)
end

"Cap outliers in normalized dataframe to max_std"
function cap_outliers!(ds::DataFrame, max_std::Integer)
    mapcols(col -> col .= ifelse.(col .> max_std, max_std, col), ds);
    mapcols(col -> col .= ifelse.(col .< -max_std, -max_std, col), ds);
end

struct Clusterization
    dendrogram::Hclust
    clusters::Vector{Int}
end

"Assigns a cluster to each sample"
function cluster(ds::DataFrame)
    X = Matrix(ds)
    dist_samples=corspearman(permutedims(X)) .- 1
    hc_samples=hclust(dist_samples, linkage=:ward, branchorder=:optimal);
    clusters = cutree(hc_samples, k=2);
    Clusterization(hc_samples, clusters)
end

"Assign a phenotype to each cluster"
function assign_phenotype_to_clusters(ds::DataFrame, clusters::Array)
end

"Saves a phenotyped dataframe to file"
function write(ds::DataFrame, clusters::Array)
end

"Main function called from command line"
function phenotype()
end

end # module PhenoJl
