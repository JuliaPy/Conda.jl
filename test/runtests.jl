using Conda
using Base.Test

already_installed = "curl" in Conda._installed_packages()

@test Conda.exists("curl")
Conda.add("curl")

@unix_only curl_path = joinpath(Conda.PREFIX, "bin", "curl-config")
@windows_only begin
    using BinDeps
    manager = Conda.Manager(["curl"])
    curl_libpath = BinDeps.libdir(manager, "")
    curl_path = joinpath(curl_libpath, "curl.exe")
end

@test isfile(curl_path)

Conda.rm("curl")
@unix_only @test !isfile(curl_path)

if already_installed
    Conda.add("curl")
end
