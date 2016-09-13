using Compat

if haskey(ENV, "CONDA_JL_HOME")
    rootenv = ENV["CONDA_JL_HOME"]
elseif isfile("deps.jl")
    include("deps.jl")
else
    rootenv = abspath(dirname(@__FILE__), "usr")
end

deps = "rootenv=\"$(escape_string(rootenv))\""

if !isfile("deps.jl") || Compat.readstring("deps.jl") != deps
    write("deps.jl", deps)
end
