$VersionNumber = "0.1.$env:GITHUB_RUN_NUMBER"
$moduleName = 'SysAdminTools'
$homedirectory = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "SysAdminTools"

$ModuleNamewithext = $moduleName + ".psm1"
$ManifesetName = $moduleName + ".psd1"
$modulePath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "$moduleName\$ModuleNamewithext"
New-Item -Path $homedirectory -ItemType File -Name $ModuleNamewithext
Write-Host "ModulePath $modulePath"
Write-Host "Module Path Exists: $(Test-Path -Path $modulePath)"

$publicFuncFolderPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "$moduleName\Public"
Write-Host "Public folder path $publicFuncFolderPath"
Write-Host "Path exists: $(Test-Path -Path $publicFuncFolderPath)"
$PublicFunctions = Get-ChildItem -Path $publicFuncFolderPath | Get-Content
$FunctionsToExport = (Get-ChildItem -Path $publicFuncFolderPath | select -ExpandProperty BaseName) -join ", "
Add-Content -Path $modulePath -Value $PublicFunctions
Add-Content -Path $modulePath -Value "Export-ModuleMember -function $FunctionsToExport"

$FunctionsToExport =  $FunctionsToExport.split(", ",[System.StringSplitOptions]::RemoveEmptyEntries)

$formatsFolderPath = Join-Path -Path $env:GITHUB_WORKSPACE -ChildPath "$moduleName\Formats"
$formatfiles = (Get-ChildItem -Path $formatsFolderPath).Name | foreach {".\Formats\$_"}

New-ModuleManifest -Path "$homedirectory\$ManifesetName" -RootModule $ModuleName -ModuleVersion $VersionNumber -Tags "Acitve Directory","Network" -FormatsToProcess $formatfiles `
     -CompanyName "Powershell Crash Course" -FunctionsToExport $FunctionsToExport -Author "Syrius Cleveland" -Description "A toolbox for System Administrators"
Write-Host "Manifest Path Exists: $(Test-Path -Path $homedirectory\$ManifesetName)"

Publish-Module -Path $homedirectory -NuGetApiKey $env:PWSHGALLERY -Tags "Active Directory","Network"
