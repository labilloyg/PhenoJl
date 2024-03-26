module PhenoTests

using Test: @test, @testset, @test_throws, @test_logs
using DataFrames
import PhenoJl as P

conf = (
    invalid_csv = "../fixtures/invalid.csv",
    light_csv = "../fixtures/light.csv",
    cluster_csv = "../fixtures/cluster.csv",
    cluser_csv_conf = "../fixtures/cluster.csv.yml"
)

@testset "Test loading and validating dataset" begin
    ds = P.load(conf.invalid_csv)
    @test ds isa DataFrame
    features = Symbol.(names(ds))
    sd = P.Sepsis15Features(ds; features=features)
    @test_throws MissingException P.test_types(sd) # missing value
    sd = P.Sepsis15Features(disallowmissing(ds[1:end-1, :]); features=features)
    @test_throws ErrorException P.test_types(sd) # non-infinite column
    sd = P.Sepsis15Features(disallowmissing(ds[1:end-1, [1,3]]); features=deleteat!(features, 2))
    @test P.test_columns(sd) # okay

    dict = Dict(:LDL=>:ldl, :total_cholesterol=>:tot_chol)
    @test P.mappedcols([:LDL, :HDL, :total_cholesterol]) == [:LDL, :HDL, :total_cholesterol]
    @test P.mappedcols([:LDL, :HDL, :total_cholesterol], dict) == [:ldl, :HDL, :tot_chol]
end

@testset "Test normalizing dataset" begin
    ds = P.load(conf.light_csv)
    @test ds isa DataFrame
    n = P.normalize(ds)
    res = Matrix([-1 -1 -1; 0 0 0; 1 1 1])
    @test Matrix(n) == res

    m = Matrix([-1 -4 -1; 0 0 8; 1 1 1])
    m2 = P.cap_outliers!(DataFrame(m, :auto), 3)
    res2 = Matrix([-1 -3 -1; 0 0 3; 1 1 1])
    @test Matrix(m2) == res2
end

@testset "Test clustering and phenotyping" begin
    ds = P.load(conf.cluster_csv)
    n = P.normalize(ds)
    clusters = P.cluster(ds)
    @test clusters == [1, 1, 2, 2, 2]

    @test "cluster" ∉ names(ds)
    @test "phenotype" ∉ names(ds)
    colmap = Dict(:LDL=>:A, :HDL=>:B, :total_cholesterol=>:C)
    sd = P.Sepsis15Features(ds; features=Symbol.(names(ds)), dict=colmap)
    P.add_phenotype!(sd, clusters)
    @test "cluster" ∈ names(ds)
    @test "phenotype" ∈ names(ds)
    @test ds.phenotype == ["HYPO", "HYPO", "NORMO", "NORMO", "NORMO"]
end

@testset "phenotype15features" begin
    ds = P.load(conf.cluster_csv)
    sigmap = Dict(:LDL=>:A, :HDL=>:B, :total_cholesterol=>:C)
    features = Symbol.(names(ds))
    P.phenotype15features!(ds; dict=sigmap, features=features)
    @test "cluster" ∈ names(ds)
    @test "phenotype" ∈ names(ds)
end

@testset "Test config definition" begin
    c = P.load_config(conf.cluser_csv_conf)

    f2m = :dict
    ft = :features
    @test f2m ∈ keys(c)
    @test ft ∈ keys(c)

    @test c[f2m] isa Dict{Symbol, Symbol}
    @test c[ft] isa Vector{Symbol}
end

@testset "Test command line interface" begin
    ds = P.phenotype(conf.cluster_csv; configfile=conf.cluser_csv_conf, write_output=0)
    @test "cluster" ∈ names(ds)
    @test "phenotype" ∈ names(ds)
    @test ds.phenotype == ["HYPO", "HYPO", "NORMO", "NORMO", "NORMO"]
end


end