using Conda
using Base.Test

already_installed = "curl" in Conda._installed_packages()

@test Conda.exists("curl")

Conda.add("curl")
@test isexecutable(joinpath(Conda.PREFIX, "bin", "curl-config"))

Conda.rm("curl")
@test !isexecutable(joinpath(Conda.PREFIX, "bin", "curl-config"))

if already_installed
    Conda.add("curl")
end
