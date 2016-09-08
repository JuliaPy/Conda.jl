using Conda
using BinDeps
using Base.Test
using Compat

function main()
    env = Conda.Environment(:test_conda_jl)
    @test Conda.exists("curl", env)
    Conda.add("curl", env)

    if is_unix()
        curl_path = joinpath(Conda.prefix(env), "bin", "curl-config")
    end
    if is_windows()
        curl_path = joinpath(Conda.lib_dir(env), "curl.exe")
    end

    @test isfile(curl_path)

    @test isfile(joinpath(Conda.bin_dir(env), basename(curl_path)))

    Conda.rm("curl", env)
    if is_unix()
        @test !isfile(curl_path)
    end

    @test isfile(Conda.conda_bin(env))
    Conda.add("python", env)
    @test isfile(joinpath(Conda.python_dir(env), "python" * (is_windows() ? ".exe": "")))

    channels = Conda.channels()
    @test channels == ["defaults"]

    Conda.add_channel("foo", env)
    @test Conda.channels(env) == ["foo", "defaults"]
    # Testing that calling the function twice do not fail
    Conda.add_channel("foo", env)

    Conda.rm_channel("foo", env)
    channels = Conda.channels(env)
    @test channels == ["defaults"]
end

main()
