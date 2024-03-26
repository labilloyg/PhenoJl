module DevTests

using Test: @test, @testset, @test_throws, @test_logs
using DataFrames, CSV
using FreqTables
import PhenoJl as P

conf = (
    nogit_csv = "../fixtures/NO_GIT_R01_LipidsII_SR_stats_new_dataset_extended_raw_data.csv",
)

@testset "Phenotypes R01 LipidsII SR dataset if available (or \"broken\")" begin

    if isfile(conf.nogit_csv) 
    
        dict = Dict(
            :HDL => :hdl,
            :APOA1 => :apoa1,
            :total_SOFA => :total_sofa,
            :total_cholesterol => :total_cholesterol,
            :ICAM1 => :icam1,
            :LDL => :ldl,
            :SOFA_cardio => :cardio,
            :SOFA_liver => :liver_funct,
            :PON => :pon,
            :SOFA_neuro => :cns,
            :temperature => :temp,
            :respiration_score => :respiration_score,
            :SOFA_renal => :renal,
            :sys_bp => :sbp,
            :SOFA_coag => :coag
        )

        ref = CSV.read(conf.nogit_csv, DataFrame)
        ds = P.load(conf.nogit_csv)
        P.phenotype15features!(ds; dict=dict)
        @test "cluster" ∈ names(ds)
        @test "phenotype" ∈ names(ds)

        comp = DataFrame(
            ref_id=ref.record_id, 
            pheno_id=ds.record_id,
            ref_pheno=uppercase.(ref.cluster), 
            pheno=ds.phenotype,
            pheno_clu=ds.cluster)

        @test comp.ref_pheno == comp.pheno

    else
        @test true skip=true
    end

end
end