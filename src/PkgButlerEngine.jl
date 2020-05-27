module PkgButlerEngine

import Mustache
import Pkg

# TODO Remove this horrible hack
function Mustache.escape_html(x)
    return String(x)
end

function configure_pkg(path::AbstractString; channel = :auto, template = :auto)
    channel in (:auto, :stable, :dev) || error("Invalid value for channel.")
    template in (:auto, :default, :bach) || error("Invalid value for template.")

    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")

    path_for_main_butler_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-workflow.yml")
    path_for_main_butler_dev_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-butler-dev-workflow.yml")

    mkpath(path_for_butler_workflows_folder)

    if channel == :auto
        channel = isfile(path_for_main_butler_dev_workflow) ? :dev : :stable
    end

    if channel == :stable
        if isfile(path_for_main_butler_dev_workflow)
            rm(path_for_main_butler_dev_workflow, force = true)
        end

        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-butler-workflow.yml"), path_for_main_butler_workflow, force = true)
    elseif channel == :dev
        if isfile(path_for_main_butler_workflow)
            rm(path_for_main_butler_workflow, force = true)
        end

        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-butler-dev-workflow.yml"), path_for_main_butler_dev_workflow, force = true)
    end

    path_for_config_file = joinpath(path, ".jlpkgbutler.toml")

    if template !== :auto
        if isfile(path_for_config_file)
            config_content = Pkg.TOML.parsefile(path_for_config_file)

            if haskey(config_content, "template")
                if template !== :auto
                    config_content["template"] = string(template)

                    open(path_for_config_file, "w") do f
                        Pkg.TOML.print(f, config_content)
                    end
                end
            elseif template !== :default
                config_content["template"] = string(template)

                open(path_for_config_file, "w") do f
                    Pkg.TOML.print(f, config_content)
                end
            end
        elseif template !== :default
            open(path_for_config_file, "w") do f
                Pkg.TOML.print(f, Dict{String,Any}("template" => string(template)))
            end

        end
    end
end

function cp_with_mustache(src, dest, vals)
    content = read(src, String)

    open(dest, "w") do file
        Mustache.render(file, content, vals, tags = ("\$[[", "]]"))
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

    versions = [v"1.0.5" => "\"1.0\"", v"1.1.1" => "\"1.1\"", v"1.2.0" => "\"1.2\"", v"1.3.1" => "\"1.3\"", v"1.4.2" => "\"1.4\""]

    compat_versions = filter(i->i[1] in version_spec, versions)

    return join(map(i->i[2], compat_versions), ", ")
end

function construct_matrix_exclude_list(path)
    path_for_config_file = joinpath(path, ".jlpkgbutler.toml")

    if isfile(path_for_config_file)
        config_content = Pkg.TOML.parsefile(path_for_config_file)

        if haskey(config_content, "strategy-matrix-exclude")
            option_value = config_content["strategy-matrix-exclude"]

            line_ending = Sys.iswindows() ? "\r\n" : "\n"
            
            exclude_configs = split(option_value, ";", keepempty = false)
            exclude_configs = strip.(exclude_configs)

            ret = ""

            for ec in exclude_configs

                lines = split(ec, ",", keepempty = false)
                lines = strip.(lines)

                ret *= line_ending * " "^10 * "- " * lines[1] * ( length(lines) > 1 ? line_ending * join(string.(" "^12, lines[2:end]), line_ending) : "" )
            end

            return ret
        end
    end

    return ""
end

function add_compathelper(path)
    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")
    path_for_compathelper_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-compathelper-workflow.yml")

    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-compathelper-workflow.yml"), path_for_compathelper_workflow, force = true)
end

function detect_template(path)
    path_for_config_file = joinpath(path, ".jlpkgbutler.toml")

    if isfile(path_for_config_file)
        config_content = Pkg.TOML.parsefile(path_for_config_file)

        if haskey(config_content, "template")
            return lowercase(config_content["template"])
        end
    end

    return "default"
end

function update_pkg_bach(path)
    if isfile(joinpath(path, ".travis.yml"))
        rm(joinpath(path, ".travis.yml"), force = true)
    end

    if isfile(joinpath(path, "appveyor.yml"))
        rm(joinpath(path, "appveyor.yml"), force = true)
    end

    if isfile(joinpath(path, ".appveyor.yml"))
        rm(joinpath(path, ".appveyor.yml"), force = true)
    end
end

function update_pkg(path::AbstractString)
    configure_pkg(path)

    template = detect_template(path)

    path_for_butler_workflows_folder = joinpath(path, ".github", "workflows")

    path_for_ci_master_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-master-workflow.yml")
    path_for_ci_pr_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-ci-pr-workflow.yml")
    path_for_docdeploy_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-docdeploy-workflow.yml")
    path_for_codeformat_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-codeformat-pr-workflow.yml")
    path_for_tagbot_workflow = joinpath(path_for_butler_workflows_folder, "jlpkgbutler-tagbot-workflow.yml")

    path_for_docs_make_file = joinpath(path, "docs", "make.jl")

    mkpath(path_for_butler_workflows_folder)

    ensure_project_has_julia_compat(path)

    view_vals = Dict{String,Any}()
    view_vals["JL_VERSION_MATRIX"] = construct_version_matrix(path)
    # if template == "bach"
    #     view_vals["include_codeformat_lint"] = "true"
    # end
    view_vals["ADDITIONAL_MATRIX_EXCLUDES"] = construct_matrix_exclude_list(path)


    cp_with_mustache(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-master-workflow.yml"), path_for_ci_master_workflow, view_vals)
    cp_with_mustache(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-ci-pr-workflow.yml"), path_for_ci_pr_workflow, view_vals)
    cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-tagbot-workflow.yml"), path_for_tagbot_workflow, force = true)

    if isfile(path_for_docs_make_file)
        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-docdeploy-workflow.yml"), path_for_docdeploy_workflow, force = true)
    else isfile(path_for_docdeploy_workflow)
        rm(path_for_docdeploy_workflow, force = true)
    end

    ensure_project_uses_new_enough_documenter(path)

    add_compathelper(path)

    isfile(path_for_codeformat_workflow) && rm(path_for_codeformat_workflow, force = true)

    if template == "bach"
        update_pkg_bach(path)

        cp(joinpath(@__DIR__, "..", "templates", "jlpkgbutler-codeformat-pr-workflow.yml"), path_for_codeformat_workflow, force = true)
    end
end

end # module
