[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string]$disableMetrics = "0",
    [Parameter(Mandatory=$False)][string]$withVSPath = ""
)
Set-StrictMode -Version Latest
$scriptsDir = split-path -parent $script:MyInvocation.MyCommand.Definition

$vcpkgRootDir = $scriptsDir

while (!($vcpkgRootDir -eq "") -and !(Test-Path "$vcpkgRootDir\.vcpkg-root"))
{
    Write-Verbose "Examining $vcpkgRootDir for .vcpkg-root"
    $vcpkgRootDir = Split-path $vcpkgRootDir -Parent
}
Write-Verbose "Examining $vcpkgRootDir for .vcpkg-root - Found"

$gitHash = "none"
$vcpkgSourcesPath = "$vcpkgRootDir\toolsrc"

if (!(Test-Path $vcpkgSourcesPath))
{
    Write-Error "Unable to determine vcpkg sources directory. '$vcpkgSourcesPath' does not exist."
    return
}

$msbuildExeWithPlatformToolset = & $scriptsDir\findAnyMSBuildWithCppPlatformToolset.ps1 $withVSPath
$msbuildExe = $msbuildExeWithPlatformToolset[0]
$platformToolset = $msbuildExeWithPlatformToolset[1]
$windowsSDK = & $scriptsDir\getWindowsSDK.ps1

$arguments = (
"`"/p:VCPKG_VERSION=-$gitHash`"",
"`"/p:DISABLE_METRICS=$disableMetrics`"",
"/p:Configuration=Release",
"/p:Platform=x86",
"/p:PlatformToolset=$platformToolset",
"/p:TargetPlatformVersion=$windowsSDK",
"/verbosity:minimal",
"/m",
"/nologo",
"`"$vcpkgSourcesPath\dirs.proj`"") -join " "

function vcpkgInvokeCommandClean()
{
    param ( [Parameter(Mandatory=$true)][string]$executable,
                                        [string]$arguments = "")

    Write-Verbose "Clean-Executing: ${executable} ${arguments}"
    $scriptsDir = split-path -parent $script:MyInvocation.MyCommand.Definition
    $cleanEnvScript = "$scriptsDir\VcpkgPowershellUtils-ClearEnvironment.ps1"
    $tripleQuotes = "`"`"`""
    $argumentsWithEscapedQuotes = $arguments -replace "`"", $tripleQuotes
    $command = ". $tripleQuotes$cleanEnvScript$tripleQuotes; & $tripleQuotes$executable$tripleQuotes $argumentsWithEscapedQuotes"
    $arg = "-NoProfile", "-ExecutionPolicy Bypass", "-command $command"

    $process = Start-Process -FilePath powershell.exe -ArgumentList $arg -PassThru -NoNewWindow
    Wait-Process -InputObject $process
    $ec = $process.ExitCode
    Write-Verbose "Execution terminated with exit code $ec."
    return $ec
}

# vcpkgInvokeCommandClean cmd "/c echo %PATH%"
Write-Host "Building vcpkg.exe ..."
$ec = vcpkgInvokeCommandClean $msbuildExe $arguments

if ($ec -ne 0)
{
    Write-Error "Building vcpkg.exe failed. Please ensure you have installed Visual Studio with the Desktop C++ workload and the Windows SDK for Desktop C++."
    return
}
Write-Host "Building vcpkg.exe... done."

Write-Verbose("Placing vcpkg.exe in the correct location")

Copy-Item $vcpkgSourcesPath\Release\vcpkg.exe $vcpkgRootDir\vcpkg.exe | Out-Null
Copy-Item $vcpkgSourcesPath\Release\vcpkgmetricsuploader.exe $vcpkgRootDir\scripts\vcpkgmetricsuploader.exe | Out-Null
