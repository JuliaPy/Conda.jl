using Conda
using Base.Test
using Compat

already_installed = "curl" in Conda._installed_packages()

@test Conda.exists("curl")
Conda.add("curl")

if is_unix()
    curl_path = joinpath(Conda.PREFIX, "bin", "curl-config")
end
if is_windows()
    using BinDeps
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

if already_installed
    Conda.add("curl")
end

@test isfile(joinpath(Conda.SCRIPTDIR, "conda" * (is_windows() ? ".exe": "")))

@test isfile(joinpath(Conda.PYTHONDIR, "python" * (is_windows() ? ".exe": "")))

channels = Conda.channels()
@test (isempty(channels) || channels == ["defaults"])

Conda.add_channel("foo")
@test Conda.channels() == ["foo", "defaults"]

Conda.rm_channel("foo")
channels = Conda.channels()
@test (isempty(channels) || channels == ["defaults"])

# install qt
if is_windows()
    Conda.add("qt")
    Conda.rm("qt")
end
