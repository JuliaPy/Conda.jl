using Compat

if haskey(ENV, "CONDA_JL_HOME")
    ROOTENV = ENV["CONDA_JL_HOME"]
elseif isfile("deps.jl")
    include("deps.jl")
else
    ROOTENV = abspath(dirname(@__FILE__), "usr")
end

deps = "const ROOTENV=\"$(escape_string(ROOTENV))\"\n"

if !isfile("deps.jl") || readstring("deps.jl") != deps
    write("deps.jl", deps)
end

if !isdir(ROOTENV)
    # Ensure ROOTENV exists, otherwise prefix(ROOTENV) will throw
    mkpath(ROOTENV)
end
