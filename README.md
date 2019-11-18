# PkgButlerEngine.jl

## Overview

The backend engine for the Julia Package Butler. This is a low level package that most users will not directly use.

## Functionality

The Julia Package Butler currently makes the following changes to a package repository:

- The GitHub Action workflow for the Package Butler itself is updated to the latest version.
- If the `Project.toml` doesn't have a version bound for `julia` in the `compat` section, it will add a version bound declaring the package compatible with Julia 1.0.
- It will add GitHub Action workflows for continuous integration. These workflows are automatically configured to only run on Julia versions that are compatible with the `compat` entry for Julia in the `Project.toml` file of the package.
- If a `docs/make.jl` file exists, a GitHub Action workflow that builds and deploys documentation is added to the package.
- If a `docs/Project.toml` file exists, the butler will ensure that the version bound on Documenter.jl is no lower than 0.24 (the first version to support building documentation with GitHub Actions).
