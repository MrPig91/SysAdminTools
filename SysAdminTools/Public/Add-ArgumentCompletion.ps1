function Add-ArgumentCompletion {
    [CmdletBinding()]
    param(
        #The Module you want to add argument completion to
        [ValidateSet("Microsoft.PowerShell.Management")]
        [string[]]$Module,
        [ValidateSet("ComputerName")]
        [string[]]$ParameterName
    )

    if ($Module -contains "Microsoft.PowerShell.Management"){
        Register-ArgumentCompleter -CommandName Get-ControlPanelItem,Show-ControlPanelItem -ParameterName Name -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $parameters = @{}
            $fakeBoundParameters.Keys | foreach {$parameters.Add($_,$fakeBoundParameters[$_])}
            [void]$parameters.Remove($parameterName)
    
            Get-ControlPanelItem -Name "*$wordToComplete*" @parameters | where name -notin $fakeBoundParameters.Name | foreach {
                [System.Management.Automation.CompletionResult]::new("`"$($_.Name)`"",$_.Name,"ParameterValue",($_ | fl | Out-String))
            }
        }
    
        Register-ArgumentCompleter -CommandName Get-ControlPanelItem,Show-ControlPanelItem -ParameterName CanonicalName -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $parameters = @{}
            $fakeBoundParameters.Keys | foreach {$parameters.Add($_,$fakeBoundParameters[$_])}
            [void]$parameters.Remove($parameterName)
    
            Get-ControlPanelItem -CanonicalName "*$wordToComplete*" @parameters | where CanonicalName -notin $fakeBoundParameters.CanonicalName | foreach {
                [System.Management.Automation.CompletionResult]::new("$($_.CanonicalName)",$_.Name,"ParameterValue",($_ | fl | Out-String))
            }
        }
    
        Register-ArgumentCompleter -CommandName Get-ControlPanelItem -ParameterName Category -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $parameters = @{}
            $fakeBoundParameters.Keys | foreach {$parameters.Add($_,$fakeBoundParameters[$_])}
            [void]$parameters.Remove($parameterName)
            $Host.UI.RawUI.ForegroundColor = "Red"
            Get-ControlPanelItem -Category "*$wordToComplete*" @parameters | group {$_.Category} | where Name -notin $fakeBoundParameters.Category | foreach {
                [System.Management.Automation.CompletionResult]::new("`"$($_.Name)`"",$_.Name,"ParameterValue",("Control Panel Items: $($_.group.name -join ", ")"))
            }
        }
    }
}