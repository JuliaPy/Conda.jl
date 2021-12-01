using Conda, Pkg, Test, VersionParsing

exe = Sys.iswindows() ? ".exe" : ""

Conda.update()

if Conda.USE_MINIFORGE
    default_channel = "conda-forge"
    alt_channel = "defaults"
else
    default_channel = "defaults"
    alt_channel = "conda-forge"
end

env = :test_conda_jl
rm(Conda.prefix(env); force=true, recursive=true)

@testset "Install Python package" begin
    Conda.add("python", env)
    pythonpath = joinpath(Conda.python_dir(env), "python" * exe)
    @test isfile(pythonpath)

    cmd = Conda._set_conda_env(`$pythonpath -c "import six"`, env)
    @test_throws Exception run(cmd)
    Conda.add("six", env)
    run(cmd)
end

@testset "Install executable package" begin
    @test Conda.exists("curl", env)
    Conda.add("curl", env)

    curlvers = Conda.version("curl",env)
    @test curlvers >= v"1.0"
    @test Conda.exists("curl==$curlvers", env)

    curl_path = joinpath(Conda.bin_dir(env), "curl" * exe)
    @test isfile(curl_path)

    @test "curl" in Conda.search("cu*", env)

    Conda.rm("curl", env)
    @test !isfile(curl_path)
end

pythonpath = joinpath(Conda.PYTHONDIR, "python" * exe)
@test isfile(pythonpath)
pyversion = read(`$pythonpath -c "import sys; print(sys.version)"`, String)
@test pyversion[1:1] == Conda.MINICONDA_VERSION

condarc_path = joinpath(homedir(), ".condarc")
last_modified = mtime(condarc_path)

Conda.add_channel("foo", env)
@test Conda.channels(env) == ["foo", default_channel]

# Testing that calling the function twice do not fail
Conda.add_channel("foo", env)

# Validate that only the Conda.jl RC file was modified
@test occursin("foo", read(Conda.conda_rc(env), String))
@test !isfile(condarc_path) || !occursin("foo", read(condarc_path, String))

Conda.rm_channel("foo", env)
@test mtime(condarc_path) == last_modified

@test Conda.channels(env) == [default_channel]

# Add a package from a specific channel
Conda.add("zlib", env; channel=alt_channel)

@testset "Batch install and uninstall" begin
    Conda.add(["affine", "ansi2html"], env)
    installed = Conda._installed_packages(env)
    @test "affine" ∈ installed
    @test "ansi2html" ∈ installed

    Conda.rm(["affine", "ansi2html"], env)
    installed = Conda._installed_packages(env)
    @test "affine" ∉ installed
    @test "ansi2html" ∉ installed
end

# Run conda clean
Conda.clean(; debug=true)

@testset "Exporting and creating environments" begin
    new_env = :test_conda_jl_2
    Conda.add("curl", env)
    Conda.export_list("conda-pkg.txt", env)

    # Create a new environment
    rm(Conda.prefix(new_env); force=true, recursive=true)
    Conda.import_list(
        IOBuffer(read("conda-pkg.txt")), new_env; channels=["foo", alt_channel, default_channel]
    )

    # Ensure that our new environment has our channels and package installed.
    @test Conda.channels(new_env) == ["foo", alt_channel, default_channel]
    installed = Conda._installed_packages(new_env)
    @test "curl" ∈ installed
    rm("conda-pkg.txt")
end

@testset "Conda.pip_interop" begin
    Conda.pip_interop(false, env)
    @test_throws Exception Conda.check_pip_interop(env)
    @test !Conda.pip_interop(env)

    Conda.pip_interop(true, env)
    @test Conda.pip_interop(env)
    @test Conda.check_pip_interop(env)
end

@testset "Conda.pip" begin
    Conda.pip("install", "affine", env)
    @test "affine" ∈ Conda._installed_packages(env)
    Conda.pip("uninstall -y", "affine", env)
    @test "affine" ∉ Conda._installed_packages(env)

    Conda.pip("install", ["affine", "ansi2html"], env)
    installed = Conda._installed_packages(env)
    @test "affine" ∈ installed
    @test "ansi2html" ∈ installed

    Conda.pip("uninstall -y", ["affine", "ansi2html"], env)
    installed = Conda._installed_packages(env)
    @test "affine" ∉ installed
    @test "ansi2html" ∉ installed
end

@testset "build" begin
    condadir = abspath(first(DEPOT_PATH), "conda")
    depsfile = joinpath(@__DIR__, "..", "deps", "deps.jl")

    function preserve_build(body)
        condadir_bak = condadir * "-backup"
        depsfile_bak = depsfile * "-backup"

        # Backup contents that may be changed by a build.
        ispath(condadir) && mv(condadir, condadir_bak)
        ispath(depsfile) && mv(depsfile, depsfile_bak)

        try
            body()
        finally
            # Restore content
            ispath(condadir_bak) && mv(condadir_bak, condadir; force=true)
            ispath(depsfile_bak) && mv(depsfile_bak, depsfile; force=true)
        end
    end

    if Sys.ARCH in [:x86, :i686]
        CONDA_JL_USE_MINIFORGE_DEFAULT = "false"
    else
        CONDA_JL_USE_MINIFORGE_DEFAULT = "true"
    end

    @testset "defaults" begin
        preserve_build() do
            # In order to test the defaults no depsfiles must be present
            @test !isfile(depsfile)
            @test !isfile(joinpath(condadir, "deps.jl"))

            withenv("CONDA_JL_VERSION" => nothing, "CONDA_JL_HOME" => nothing, "CONDA_JL_USE_MINIFORGE" => nothing) do
                Pkg.build("Conda")
                @test read(depsfile, String) == """
                    const ROOTENV = "$(escape_string(joinpath(condadir, "3")))"
                    const MINICONDA_VERSION = "3"
                    const USE_MINIFORGE = $(CONDA_JL_USE_MINIFORGE_DEFAULT)
                    """
            end
        end
    end

    @testset "miniforge" begin
        preserve_build() do
            # In order to test the defaults no depsfiles must be present
            @test !isfile(depsfile)
            @test !isfile(joinpath(condadir, "deps.jl"))

            withenv("CONDA_JL_VERSION" => nothing, "CONDA_JL_HOME" => nothing, "CONDA_JL_USE_MINIFORGE" => "1") do
                Pkg.build("Conda")
                @test read(depsfile, String) == """
                    const ROOTENV = "$(escape_string(joinpath(condadir, "3")))"
                    const MINICONDA_VERSION = "3"
                    const USE_MINIFORGE = true
                    """
            end
        end
        preserve_build() do
            # In order to test the defaults no depsfiles must be present
            @test !isfile(depsfile)
            @test !isfile(joinpath(condadir, "deps.jl"))

            withenv("CONDA_JL_VERSION" => nothing, "CONDA_JL_HOME" => nothing, "CONDA_JL_USE_MINIFORGE" => "0") do
                Pkg.build("Conda")
                @test read(depsfile, String) == """
                    const ROOTENV = "$(escape_string(joinpath(condadir, "3")))"
                    const MINICONDA_VERSION = "3"
                    const USE_MINIFORGE = false
                    """
            end
        end
    end

    @testset "custom home" begin
        preserve_build() do
            mktempdir() do dir
                withenv("CONDA_JL_VERSION" => "3", "CONDA_JL_HOME" => dir, "CONDA_JL_USE_MINIFORGE" => nothing) do
                    Pkg.build("Conda")
                    @test read(depsfile, String) == """
                        const ROOTENV = "$(escape_string(dir))"
                        const MINICONDA_VERSION = "3"
                        const USE_MINIFORGE = $(CONDA_JL_USE_MINIFORGE_DEFAULT)
                        """
                end
            end
        end
    end

    @testset "version mismatch" begin
        preserve_build() do
            # Mismatch in written file
            write(depsfile, """
                const ROOTENV = "$(escape_string(joinpath(condadir, "3")))"
                const MINICONDA_VERSION = "2"
                const USE_MINIFORGE = $(CONDA_JL_USE_MINIFORGE_DEFAULT)
                """)

            withenv("CONDA_JL_VERSION" => nothing, "CONDA_JL_HOME" => nothing, "CONDA_JL_USE_MINIFORGE" => nothing) do
                Pkg.build("Conda")
                @test read(depsfile, String) == """
                    const ROOTENV = "$(escape_string(joinpath(condadir, "2")))"
                    const MINICONDA_VERSION = "2"
                    const USE_MINIFORGE = $(CONDA_JL_USE_MINIFORGE_DEFAULT)
                    """
            end

            # ROOTENV should be replaced since CONDA_JL_HOME wasn't explicitly set
            withenv("CONDA_JL_VERSION" => "3", "CONDA_JL_HOME" => nothing, "CONDA_JL_USE_MINIFORGE" => nothing) do
                Pkg.build("Conda")
                @test read(depsfile, String) == """
                    const ROOTENV = "$(escape_string(joinpath(condadir, "3")))"
                    const MINICONDA_VERSION = "3"
                    const USE_MINIFORGE = $(CONDA_JL_USE_MINIFORGE_DEFAULT)
                    """
            end
        end
    end
end
