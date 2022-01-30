<#
.SYNOPSIS
    This function will remove a user from the "Remote Desktop Users" group from a remote machine.
.DESCRIPTION
    This function will remove a user from the "Remote Desktop Users" group from a remote machine.
.EXAMPLE
    PS C:\> Remove-RemoteDesktopUser -ComputerName mrpig -SamAccountName mrpig

    ComputerName   SamAccountName   UserRemoved
    ------------   --------------   -----------
    pancake-3      mrpig            True

    In this example the user account mrpig is removed from the "Remote Desktop Users" group on the computer mrpig.
.EXAMPLE
    PS C:\>Get-sysLocalGroup -ComputerName pancake-3 -GroupName "Remote Desktop Users" -Protocol Dcom

    GroupName            Member         ComputerName
    ---------            ------         ------------
    Remote Desktop Users {mrpig, mrpig} pancake-3

    PS C:\> Remove-RemoteDesktopUser -ComputerName pancake-3 -SamAccountName mrpig -Protocol Dcom

    ComputerName SamAccountName UserDomain UserRemoved
    ------------ -------------- ---------- -----------
    pancake-3    mrpig          CLEVELAND         True

    Remove-RemoteDesktopUser -ComputerName pancake-3 -SamAccountName mrpig -Protocol Dcom -Domain pancake-3

    ComputerName SamAccountName UserDomain UserRemoved
    ------------ -------------- ---------- -----------
    pancake-3    mrpig          pancake-3         True

    This example should show you full functionality of the command. The first command grabs the current users of the "Remote Desktop Users" group on pancake-3.
    We can see that there are 2 mrpig accounts in that group, we could expand the Member property to see one is domain mrpig account and the other is local mrpig account.
    The second command removes the domain mrpig account, it does this because the default value of the domain paramter is the current user's domain.
    The third command specifies the pancake-3 as the domain to target the pancake-3\mrpig account to remove.
    
.INPUTS
    [String]
.OUTPUTS
    [PSCustomObject]
.NOTES
    Requires Admin.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Remove%E2%80%90RemoteDesktopUser
#>
function Remove-RemoteDesktopUser{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,
        [Parameter(Mandatory)]
        [string]$SamAccountName,
        [string]$Domain = $ENV:USERDOMAIN,
        [ValidateSet("WsMan","Dcom")]
        [string]$Protocol
    )

    try{
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
            $Options = New-CimSessionOption -Protocol Dcom
            $Sesssion = New-CimSession -ComputerName $ComputerName -OperationTimeoutSec 1 -SessionOption $options -ErrorAction Stop
            $Users = Get-sysLocalGroup -ComputerName $ComputerName -GroupName "Remote Desktop Users" -Protocol $Protocol
            $UserFound = $Users | where {$_.Member.Name -eq $SamAccountName -and $_.Member.Domain -eq $Domain}
            if ($UserFound){
                $ErrorActionPreference = "Stop"
                [ADSI]$Account = "WinNT://$Domain/$SamAccountName,User"
                [ADSI]$Group = "WinNT://$ComputerName/Remote Desktop Users,Group"
                $Group.Remove($Account.Path)
                [PSCustomObject]@{
                    ComputerName = $ComputerName
                    SamAccountName = $SamAccountName
                    UserDomain = $Domain
                    UserRemoved = $true
                }
                $ErrorActionPreference = "Continue"
                
            }
            else{
                Write-Error -Message "$SamAccountName is not a member of the Remote Desktop Users group on $ComputerName. Try using 'Get-sysLocalGroup -ComputerName $ComputerName -GroupName `"Remote Desktop Users`"' to find the current members of that group."`
                 -ErrorAction Stop
            }

            $Sesssion | Remove-CimSession
        }
        else{
            Write-Error -Message "$ComputerName is offline or unreachable. Possibly try grabbing its IP address by using Get-ComputerIP -ComputerName $ComputerName"
        }
    }
    catch{
        if ($Sesssion){
            $Sesssion | Remove-CimSession
        }
        $ErrorActionPreference = "Continue"
        $PSCmdlet.WriteError($_)
    }
}