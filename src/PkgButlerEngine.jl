module PkgButlerEngine

function update_pkg(path::AbstractString; channel=:auto)
    channel in (:auto, :stable, :dev) || error("Invalid value for channel.")

    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")

    path_for_main_butler_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-workflow.yml")
    path_for_main_butler_dev_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-dev-workflow.yml")
    path_for_ci_master_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-master-workflow.yml")
    path_for_ci_pr_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-pr-workflow.yml")

    mkpath(path_for_butler_workflows_folder)

    if channel==:auto
        channel = isfile(path_for_main_butler_dev_workflow) ? :dev : :stable
    end

    if channel==:stable
        if isfile(path_for_main_butler_dev_workflow)
            rm(path_for_main_butler_dev_workflow, force=true)
        end

        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-butler-workflow.yml"), path_for_main_butler_workflow, force=true)
    elseif channel==:dev
        if isfile(path_for_main_butler_workflow)
            rm(path_for_main_butler_workflow, force=true)
        end

        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-butler-dev-workflow.yml"), path_for_main_butler_dev_workflow, force=true)
    end

    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-master-workflow.yml"), path_for_ci_master_workflow, force=true)
    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-pr-workflow.yml"), path_for_ci_pr_workflow, force=true)
end

end # module
