using PkgButlerEngine
using Test

@testset "PkgButlerEngine" begin

mktempdir() do temp_path
    temp_path_of_project = joinpath(temp_path, "TestPackage")
    cp(joinpath(@__DIR__, "with_problems"), temp_path_of_project)

    PkgButlerEngine.update_pkg(temp_path_of_project)

    @test isfile(joinpath(temp_path_of_project, ".github", "workflows", "jlpkgbutler-butler-workflow.yml"))
    @test isfile(joinpath(temp_path_of_project, ".github", "workflows", "jlpkgbutler-ci-master-workflow.yml"))
    @test isfile(joinpath(temp_path_of_project, ".github", "workflows", "jlpkgbutler-ci-pr-workflow.yml"))
end

end
