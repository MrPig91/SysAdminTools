function Get-RemoteDesktopUser{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$UserName
    )

    Begin{

    } #Begin

    Process{
        foreach ($computer in $ComputerName){
            Get-sysLocalGroupMember -ComputerName $computer -GroupName "Remote Desktop Users"
        } #foreach
    } #process
}