<#
.SYNOPSIS
    Adds a user that is currently in AD to a computer's "Remote Desktop Users" group.
.DESCRIPTION
    Adds a user that is currently in AD to a computer's "Remote Desktop Users" group.
.EXAMPLE
    PS C:\WINDOWS\system32> Add-RemoteDesktopUser -ComputerName oz-jsyzdek-l -SamAccountName syrius.cleveland

    ComputerName SamAccountName   UserAdded
    ------------ --------------   ---------
    oz-jsyzdek-l syrius.cleveland      True

    This examples adds the user "syrius.cleveland" to the computer OZ-JSYZDEK-L.
.INPUTS
    [String] ComputerName
    [String] SamAccountName
.OUTPUTS
    [PSCUSTOMOBJECT]
.NOTES
    Requires admin.
#>
function Add-RemoteDesktopUser{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        [Parameter(Mandatory,Position=1, ValueFromPipelineByPropertyName)]
        [string]$SamAccountName,
        [string]$Domain = $ENV:USERDOMAIN
    )
    try{
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
            #need to change error action perference to make any errors terminating since we are not using native powershell functions
            $ErrorActionPreference = "Stop"
            [ADSI]$Account = "WinNT://$Domain/$SamAccountName,User"
            $Account
            [ADSI]$Group = "WinNT://$ComputerName/Remote Desktop Users,Group"
            $Group.Add($Account.Path)
            [PSCustomObject]@{
                ComputerName = $ComputerName
                SamAccountName = $SamAccountName
                UserAdded = $true
            }
            $ErrorActionPreference = "Continue"
        }
        else{
            Write-Error -Message "$ComputerName is offline or unreachable."
        }
    }
    catch{
        $ErrorActionPreference = "Continue"
        $PSCmdlet.WriteError($_)
    }
}