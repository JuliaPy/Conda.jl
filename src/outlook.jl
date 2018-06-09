# Code to test whether Outlook is running on Windows.   This is used
# to work around a bug in the Miniconda installer, which crashes Outlook
# if it is running.  See Luthaf/Conda.jl#15

struct PROCESSENTRY32
    dwSize::Int32
    cntUsage::Int32
    th32ProcessID::Int32
    th32DefaultHeapID::UInt
    th32ModuleID::Int32
    cntThreads::Int32
    th32ParentProcessID::Int32
    pcPriClassBase::Int32
    dwFlags::UInt32
    szExeFile::NTuple{260,UInt8}
    PROCESSENTRY32() = new(sizeof(PROCESSENTRY32),0,0,0,0,0,0,0,0)
end
szExeFile(p::PROCESSENTRY32) = unsafe_string(pointer(collect(p.szExeFile)))
const TH32CS_SNAPPROCESS = 0x00000002
function isrunning(exefile::AbstractString)
    snapshot = ccall(:CreateToolhelp32Snapshot, stdcall, Ptr{Void}, (UInt32,Int32), TH32CS_SNAPPROCESS, 0)
    try
        entry = Ref(PROCESSENTRY32())
        if ccall(:Process32First, stdcall, Cint, (Ptr{Void}, Ref{PROCESSENTRY32}), snapshot, entry) == 1
            szExeFile(entry[]) == exefile && return true
            while ccall(:Process32Next, stdcall, Cint, (Ptr{Void}, Ref{PROCESSENTRY32}), snapshot, entry) == 1
                szExeFile(entry[]) == exefile && return true
            end
        end
    finally
        ccall(:CloseHandle, stdcall, Cint, (Ptr{Void},), snapshot)
    end
    return false
end
is_outlook_running() = isrunning("outlook.exe")
