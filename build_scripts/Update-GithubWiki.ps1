Write-Host "Importing ConvertTo-MarkdownHelp function"
Import-Module ".\base-code\build_scripts\ConvertTo-MarkdownHelp.ps1"
$modulePublicDirecory = ".\base-code\$env:ModuleName\Public"

Write-Host "Getting files from the public folder [$modulePublicDirecory]"
$publicFunctions = Get-ChildItem $modulePublicDirecory -File -Filter "*.ps1"

foreach ($command in $publicFunctions){
    Import-Module $command.FullName
    $commandName = $command.BaseName.Replace.Replace("-",'-')
    Write-Host "Converting [$CommandName] comment help to markdown"
    $markdown = ConvertTo-MarkdownHelp -Name $command.BaseName -ErrorAction SilentContinue
    $markdown | Out-File ".\markdown\$CommandName.md" -Force
}

$markDownFiles = Get-ChildItem ".\markdown" | Select-Object -ExpandProperty Name | Out-String
Write-Host $markDownFiles
