if haskey(ENV, "CONDA_JL_HOME")
    default_dir = ENV["CONDA_JL_HOME"]
elseif isfile("deps.jl")
    include("deps.jl")
else
    default_dir = abspath(dirname(@__FILE__), "usr")
end

deps = "default_dir=\"$(escape_string(default_dir))\""

if !isfile("deps.jl") || readchomp("deps.jl") != deps
    open("deps.jl", "w") do f
        println(f, deps)
    end
end
