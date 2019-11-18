module PkgButlerEngine

import Mustache
import Pkg

function configure_pkg(path::AbstractString; channel=:auto)
    channel in (:auto, :stable, :dev) || error("Invalid value for channel.")

    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")

    path_for_main_butler_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-workflow.yml")
    path_for_main_butler_dev_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-dev-workflow.yml")

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
end

function cp_with_mustache(src, dest, vals)
    content = read(src, String)

    open(dest, "w") do file
        Mustache.render(file, content, vals, tags= ("\$[[", "]]"))
    end
end

function ensure_project_has_julia_compat(path)
    proj_file = isfile(joinpath(path, "JuliaProject.toml")) ? joinpath(path, "JuliaProject.toml") : joinpath(path, "Project.toml")

    pkg_toml_content = Pkg.TOML.parsefile(proj_file)

    if !haskey(pkg_toml_content, "compat")
        pkg_toml_content["compat"] = Dict{String,String}()
    end

    if !haskey(pkg_toml_content["compat"], "julia")
        pkg_toml_content["compat"]["julia"] = "1"

        open(proj_file, "w") do f
            Pkg.TOML.print(f, pkg_toml_content)
        end
    end
end

function ensure_project_uses_new_enough_documenter(path)
    doc_proj_file = isfile(joinpath(path, "docs", "JuliaProject.toml")) ? joinpath(path, "docs", "JuliaProject.toml") : joinpath(path, "docs", "Project.toml")

    if isfile(doc_proj_file)
        pkg_toml_content = Pkg.TOML.parsefile(doc_proj_file)

        if haskey(pkg_toml_content, "compat") && haskey(pkg_toml_content["compat"], "Documenter")
            documenter_compat_bound = pkg_toml_content["compat"]["Documenter"]
            version_bound = Pkg.Types.semver_spec(documenter_compat_bound)

            # This is the list of versions that don't work
            invalid_versions = Pkg.Types.semver_spec("0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,0.10,0.11,0.12,0.13,0.14,0.15,0.16,0.17,0.18,0.19,0.20,0.21,0.22,0.23")

            if !isempty(intersect(invalid_versions, version_bound))
                # TODO This is a bit crude. Ideally we would try to see whether a version >= 0.24 is listed in the compat section, and if so,
                # only remove the offending versions.
                pkg_toml_content["compat"]["Documenter"] = "~0.24"

                open(doc_proj_file, "w") do f
                    Pkg.TOML.print(f, pkg_toml_content)
                end
        
            end
        end

    end
end

function construct_version_matrix(path)
    proj_file = isfile(joinpath(path, "JuliaProject.toml")) ? joinpath(path, "JuliaProject.toml") : joinpath(path, "Project.toml")

    pkg_toml_content = Pkg.TOML.parsefile(proj_file)

    julia_compat_bound = pkg_toml_content["compat"]["julia"]

    version_spec = Pkg.Types.semver_spec(julia_compat_bound)

    versions = [v"1.0.5", v"1.1.1", v"1.2.0"]

    compat_versions = filter(i->i in version_spec, versions)

    return join(string.(compat_versions), ", ")
end

function update_pkg(path::AbstractString)
    configure_pkg(path)

    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")

    path_for_ci_master_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-master-workflow.yml")
    path_for_ci_pr_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-pr-workflow.yml")
    path_for_docdeploy_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-docdeploy-workflow.yml")

    path_for_docs_make_file = joinpath(path, "docs", "make.jl")

    mkpath(path_for_butler_workflows_folder)

    ensure_project_has_julia_compat(path)

    view_vals = Dict{String, Any}()
    view_vals["JL_VERSION_MATRIX"] = construct_version_matrix(path)

    cp_with_mustache(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-master-workflow.yml"), path_for_ci_master_workflow, view_vals)
    cp_with_mustache(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-pr-workflow.yml"), path_for_ci_pr_workflow, view_vals)

    if isfile(path_for_docs_make_file)
        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-docdeploy-workflow.yml"), path_for_docdeploy_workflow, force=true)
    else isfile(path_for_docdeploy_workflow)
        rm(path_for_docdeploy_workflow, force=true)
    end

    ensure_project_uses_new_enough_documenter(path)
end

end # module
