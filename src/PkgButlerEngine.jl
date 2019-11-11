module PkgButlerEngine

function update_pkg(path::AbstractString)
    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")
    path_for_main_butler_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-workflow.yml")
    path_for_ci_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-workflow.yml")

    mkpath(path_for_butler_workflows_folder)

    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-butler-workflow.yml"), path_for_main_butler_workflow, force=true)
    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-workflow.yml"), path_for_ci_workflow, force=true)
end

end # module
