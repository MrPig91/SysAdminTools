<#
.SYNOPSIS
    This function will match a SID to a user account (either local or domain).
.DESCRIPTION
    This function will match a SID to a user account that could be either a local account or domain.
    If the account is local to the computer then you may need to specify the ComputerName for which the account would exist on.
    This function is mostly used as helper function when working with objects that only return SIDs and not usernames.
.PARAMETER SID
    This is the SID string you want to resolve. Sometimes SID properties contain objects rather than strings(e.g. the output from Get-ADUser), so be careful when piping the SID property.
.PARAMETER ComputerName
    If the SID is a domain account then any domain joined computers should be able to resolve the SID. However, if the SID comes from a local account on a computer, then you will need specify that computer's name.
.EXAMPLE
    PS C:\> Get-CimInstance -ClassName Win32_UserProfile -ComputerName mrpig-computer  | select @{n="UserName";e={($_ | Resolve-SID).AccountName}},localPath,LastUseTime

    UserName         localPath                                 LastUseTime
    --------         ---------                                 -----------
    Administrator    C:\Users\Administrator                    10/19/2021 8:08:50 AM
    tempadmin        C:\Users\tempadmin                        10/19/2021 8:08:50 AM                10/28/2021 11:19:49 AM
    mrpig            C:\Users\mrpig                        10/28/2021 11:19:49 AM
    ...

    This example grabs the UserProfiles from the win32_UserProfile WMI Class, however this class does not provide the acutal username for these profiles and only the SID. So we create a custom property called UserName and use the Resolve-SID to populate it.

    Notice that we pipe the pipeline object into Resolve-SID so that it receives both the SID and PSComputerName property in order for it resolve the local SID on mrpig-computer.
.INPUTS
    [string]
        SID - the SID string
.OUTPUTS
    [Win32_SID]
.NOTES
    Requires admin when
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Resolve%E2%80%90SID
#>
function Resolve-SID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SID,
        
        [Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    Process {
        $params=@{
            ErrorAction="Stop"
            ResourceURI="wmicimv2/win32_SID"
            SelectorSet=@{SID="$SID"}
            Computername=$Computername
        }
        try {
            Get-WSManInstance @params
        }
        catch{
            try{
                Write-Information "Failed to resolve SID using WSMan, switching to WMI"
                [wmi]"\\$ComputerName\root\cimv2:win32_sid.sid='$SID'"
            }
            catch{
                Write-Information "Failed to resolve SID using WSMan and WMI, throwing an error"
                throw $_
            }
        }
    }
}