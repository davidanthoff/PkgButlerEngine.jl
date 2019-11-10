module PkgButler

function update_pkg(path::AbstractString)
    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows", "jlbutler")
    path_for_main_butler_workflow = joinpath(path_for_butler_workflows_folder, "butler-workflow.yml")

    mkpath(path_for_butler_workflows_folder)

    cp(joinpath(@__DIR__, "..", "templates", "butler-workflow.yml"), path_for_main_butler_workflow, force=true)

    cp(joinpath(@__DIR__, "..", "sillytestfile.md"), joinpath(path, "sillytestfile.md"))
end

end # module
