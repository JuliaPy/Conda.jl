using Conda, Compat, VersionParsing
using Compat
using Compat: @info
using Compat.Test

@testset "_set_path" begin
    env_var = Dict("PATH" => "somewhere")
    Conda._set_path(env_var, :dummy)
    @test endswith(env_var["PATH"], "somewhere")
    @test occursin("dummy", env_var["PATH"])

    env_var = Dict{String, String}()
    Conda._set_path(env_var, :dummy)
    @test occursin("dummy", env_var["PATH"])

    if Compat.Sys.iswindows()
        env_var = Dict("PaTh" => "somewhere")
        Conda._set_path(env_var, :dummy)
        @test endswith(env_var["PaTh"], "somewhere")
        @test occursin("dummy", env_var["PaTh"])
    end
end

exe = Compat.Sys.iswindows() ? ".exe" : ""

Conda.update()

env = :test_conda_jl
rm(Conda.prefix(env); force=true, recursive=true)

@test Conda.exists("curl", env)
Conda.add("curl", env)

@testset "Install Python package" begin
    Conda.add("python", env)
    pythonpath = joinpath(Conda.python_dir(env), "python" * exe)
    @test isfile(pythonpath)

    cmd = Conda._set_conda_env(`$pythonpath -c "import zmq"`, env)
    @test_throws Exception run(cmd)
    Conda.add("pyzmq", env)
    run(cmd)

    Conda.add("jupyter", env)
end

curlvers = Conda.version("curl",env)
@test curlvers >= v"5.0"
@test Conda.exists("curl==$curlvers", env)

curl_path = joinpath(Conda.bin_dir(env), "curl" * exe)
@test isfile(curl_path)

@test "curl" in Conda.search("cu*", env)

Conda.rm("curl", env)
@test !isfile(curl_path)

pythonpath = joinpath(Conda.PYTHONDIR, "python" * exe)
@test isfile(pythonpath)
pyversion = read(`$pythonpath -c "import sys; print(sys.version)"`, String)
@test pyversion[1:1] == Conda.MINICONDA_VERSION

Conda.add_channel("foo", env)
@test Conda.channels(env) == ["foo", "defaults"]
# Testing that calling the function twice do not fail
Conda.add_channel("foo", env)

Conda.rm_channel("foo", env)
@test Conda.channels(env) == ["defaults"]
