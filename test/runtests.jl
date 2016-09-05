using Conda
using BinDeps
using Base.Test
using Compat

CURL_ALREADY_INSTALLED = false
PREVIOUS_CHANNELS = []

function setup()
    CURL_ALREADY_INSTALLED = "curl" in Conda._installed_packages()
    PREVIOUS_CHANNELS = Conda.channels()
    for channel in PREVIOUS_CHANNELS
        Conda.rm_channel(channel)
    end
    Conda.add_channel("defaults")
end

function teardown()
    if CURL_ALREADY_INSTALLED
        Conda.add("curl")
    end

    for channel in PREVIOUS_CHANNELS
        Conda.add_channel(channel)
    end
end

function main()
    setup()

    @test Conda.exists("curl")
    Conda.add("curl")

    if is_unix()
        curl_path = joinpath(Conda.PREFIX, "bin", "curl-config")
    end
    if is_windows()
        manager = Conda.Manager(["curl"])
        curl_libpath = BinDeps.libdir(manager, "")
        curl_path = joinpath(curl_libpath, "curl.exe")
    end

    @test isfile(curl_path)

    @test isfile(joinpath(Conda.BINDIR, basename(curl_path)))

    Conda.rm("curl")
    if is_unix()
        @test !isfile(curl_path)
    end

    @test isfile(joinpath(Conda.SCRIPTDIR, "conda" * (is_windows() ? ".exe": "")))

    @test isfile(joinpath(Conda.PYTHONDIR, "python" * (is_windows() ? ".exe": "")))

    channels = Conda.channels()
    @test channels == ["defaults"]

    Conda.add_channel("foo")
    @test Conda.channels() == ["foo", "defaults"]
    # Testing that calling the function twice do not fail
    Conda.add_channel("foo")

    Conda.rm_channel("foo")
    channels = Conda.channels()
    @test channels == ["defaults"]

    teardown()
end

main()
