using Compat

module DefaultDeps
    if isfile("deps.jl")
        include("deps.jl")
    else
        const ROOTENV = abspath(dirname(@__FILE__), "usr")
        const MINICONDA_VERSION = "2"
    end
end

ROOTENV = get(ENV, "CONDA_JL_HOME", DefaultDeps.ROOTENV)
MINICONDA_VERSION = get(ENV, "CONDA_JL_VERSION", DefaultDeps.MINICONDA_VERSION)

deps = """# Generated from $(@__FILE__) on $(now())
const ROOTENV="$(escape_string(ROOTENV))"
const MINICONDA_VERSION="$(escape_string(MINICONDA_VERSION))"
"""

if !isfile("deps.jl") || readstring("deps.jl") != deps
    write("deps.jl", deps)
end

if !isdir(ROOTENV)
    # Ensure ROOTENV exists, otherwise prefix(ROOTENV) will throw
    mkpath(ROOTENV)
end
