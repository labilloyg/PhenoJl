module LibraryTests

using Test: @testset

@testset "Test module PhenoJl" begin

    include("Pheno_tests.jl")

    include("R01_LipidsII_SR_tests.jl")

end

end