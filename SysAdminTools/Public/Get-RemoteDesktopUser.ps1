<#
.SYNOPSIS
    Get the members of the "Remote Desktop Users" group.
.DESCRIPTION
    Get the members of the "Remote Desktop Users" group.
.PARAMETER ComputerName
    This parameter specifies the name of the computer that want to get the members of the group "Remote Desktop User" for. Default value is the local computer.
.EXAMPLE
    PS C:\> Get-RemoteDesktopUser

    Name  Domain    MemberType
    ----  ------    ----------
    mrpig WIN-TEST2 UserAccount

    This example grabs all remote desktop users for the local computer.
.INPUTS
    string
        ComputerName
.OUTPUTS
    Output (if any)
.NOTES
    General notes
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90RemoteDesktopUser
#>
function Get-RemoteDesktopUser {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    Begin{

    } #Begin

    Process{
        foreach ($computer in $ComputerName){
            (Get-sysLocalGroup -ComputerName $computer -GroupName "Remote Desktop Users").Member
        } #foreach
    } #process
}