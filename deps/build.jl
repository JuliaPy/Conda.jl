default_dir = get(ENV, "CONDA_JL_HOME", abspath(dirname(@__FILE__), "usr"))
open("deps.jl", "w") do f
    println(f, "default_dir=\"$default_dir\"")
end
