default_dir = get(ENV, "CONDA_JL_HOME", abspath(joinpath(dirname(@__FILE__), "usr")))
open("deps.jl", "w") do f
    println(f, "default_dir=\"$(escape_string(default_dir))\"")
end
