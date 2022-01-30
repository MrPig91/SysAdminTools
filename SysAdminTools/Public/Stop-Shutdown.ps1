<#
.SYNOPSIS
    This function will abort a scheduled shutdown.
.DESCRIPTION
    This function uses the shutdown.exe utility to abort a scheduled shutdown. If no error was given then the abort action was successful.
.PARAMETER ComputerName
    Specifies the computers the scheduled shutdown (if any) will be stopped on. Type computer names or IP addresses.
.PARAMETER Passthru
    Returns the results of the command. Otherwise, this cmdlet does not generate any output.
.EXAMPLE
    PS C:\> Stop-Shutdown -ComputerName Client01v -Passthru

    ComputerName    ShutdownAborted
    ------------    ---------------
    Client01v       True

    This example aborts a scheduled shutdown on computer Client01v and uses the passthru parameter to output an object that tells you if the abort was successful or not.
.INPUTS
    System.String
        ComputerName - The name of the computer to abort the action
.OUTPUTS
    None
.NOTES
    Requires Admin for remote computer abort actions and shutdown.exe
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Stop%E2%80%90Shutdown
#>
function Stop-Shutdown{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("CN","Name","MachineName")]
        [string[]]$ComputerName = $ENV:COMPUTERNAME,
        [switch]$Passthru
    )


    Process{
        foreach ($computer in $ComputerName){
            Write-Information "Sending abort command to $computer" -Tags "Process"
            shutdown /a /m "\\$computer" 2> $null
            if (!$?){
                if ($Passthru){
                Write-Information "Passthru paramter was used, creating object for unsuccessful abort action for $computer" -Tags "Process"
                    [PSCustomObject]@{
                        ComputerName = $Computer
                        ShutdownAborted = $false
                    }
                }
                else{
                    $PSCmdlet.WriteError($Error[0])
                }
            }
            elseif ($Passthru){
                Write-Information "Passthru paramter was used, creating object for successful abort action for $computer" -Tags "Process"
                [PSCustomObject]@{
                    ComputerName = $Computer
                    ShutdownAborted = $true
                }
            }
        } #foreach
    } #process
}