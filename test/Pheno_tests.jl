module PhenoTests

using Test: @test, @testset, @test_throws, @test_logs
using DataFrames
import PhenoJl as P

conf = (
    invalid_csv = "../fixtures/invalid.csv",
    light_csv = "../fixtures/light.csv",
    cluster_csv = "../fixtures/cluster.csv"
)

@testset "Test loading and validating dataset" begin
    ds = P.load(conf.invalid_csv)
    @test ds isa DataFrame
    @test_throws MissingException P.validate(ds) # missing value
    @test_throws ErrorException P.validate(disallowmissing(ds[1:end-1, :])) # non-infinite column
    @test P.validate(disallowmissing(ds[1:end-1, [1,3]])) # good
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

@testset "Test clustering dataset" begin
    ds = P.load(conf.cluster_csv)
    n = P.normalize(ds)
    clust = P.cluster(ds)
    @test clust.clusters == [1, 1, 2, 2, 2]
end

@testset "Test phenotyping dataset" begin
    
end

@testset "Test phenotyping report" begin
    
end

@testset "Test command line function" begin
    
end


end