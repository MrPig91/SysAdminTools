<#
.SYNOPSIS
    This function grabs local groups along with their members (if any) from local or remote computers.
.DESCRIPTION
    This function uses Win32_Group and Win32_GroupUser to grab local groups and their members form local and remote computers.
.EXAMPLE
    PS C:\> Get-sysLocalGroup -GroupName "Remote Desktop Users","RDS Remote Access Servers"

    GroupName                 Member            ComputerName
    ---------                 ------            ------------
    Remote Desktop Users      {Everyone, mrpig} DC01
    RDS Remote Access Servers                   DC01

    This examples grabs the group and members of 2 groups specified with the GroupName parameter from the local computer.

.EXAMPLE
    PS C:\>Get-sysLocalGroup -IncludeGroupsWithMembersOnly

    GroupName                              Member
    ---------                              ------
    Pre-Windows 2000 Compatible Access     {Authenticated Users}
    Windows Authorization Access Group     {ENTERPRISE DOMAIN CONTROLLERS}
    Administrators                         {Administrator, Enterprise Admins, Domain Admins}
    Users                                  {INTERACTIVE, Authenticated Users, Domain Users}
    Guests                                 {Guest, Domain Guests}
    Remote Desktop Users                   {Everyone, mrpig}
    IIS_IUSRS                              {IUSR}
    Denied RODC Password Replication Group {krbtgt, Domain Controllers, Schema Admins, Enterprise Admins, Cert Publisher...

    This example grabs all groups from the local computer if they have any members and ignores the one's with no members.
.EXAMPLE
    PS C:\>Get-sysLocalGroup -ComputerName $ENV:COMPUTERNAME,pancake-3 -Protocol Dcom -GroupName "Remote Desktop Users" -OutVariable groups

    GroupName            Member            ComputerName
    ---------            ------            ------------
    Remote Desktop Users {Everyone, mrpig} DC01
    Remote Desktop Users {mrpig, mrpig}    pancake-3

    PS C:\>$groups[1].Member

    Name  Domain    MemberType
    ----  ------    ----------
    mrpig CLEVELAND UserAccount
    mrpig PANCAKE-3 UserAccount

    This example grabs members of the "Remote Desktop Users" group from both dc01 and pancake-3 and uses the Dcom protocol since pancake-3 does not have WsMan enabled.
    It then stores the results into the groups variable. The second command expands the Member property of pancake-3 LocalGroup object to get more info about each group member.
.INPUTS
    Inputs (if any)
.OUTPUTS
    [SysAdminTools.LocalGroupMember]
.NOTES
    GroupName has tab completetion, but it only grabs the local groups from the local computer and not remote ones, but generally they should be the same.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90sysLocalGroup
#>
function Get-sysLocalGroup {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [string[]]$ComputerName = $ENV:COMPUTERNAME,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            Get-CimInstance -ClassName Win32_Group -Filter "LocalAccount=True AND Name LIKE `"%$WordToComplete%`"" |
            where Name -notin $fakeBoundParameter.GroupName |
            foreach {
                $ToolTip = $_ | Format-List Name,Description,Caption | Out-String
                [System.Management.Automation.CompletionResult]::new("`"$($_.Name)`"","$($_.Name)","ParameterValue",$ToolTip)
            }
        })]
        [Parameter()]
        [string[]]$GroupName,
        [switch]$IncludeGroupsWithMembersOnly,
        [Parameter()]
        [ValidateSet("WsMan", "Dcom")]
        [string]$Protocol = "WsMan"
    )

    Begin{
        if ($PSBoundParameters.ContainsKey("GroupName")){
            $GroupNameFilter = "AND (Name=`"$($GroupName[0])`""
            foreach ($name in ($GroupName | select -Skip 1)){
                $GroupNameFilter += " OR Name=`"$name`""
            }
            $GroupNameFilter += ")"
        }
    } #Begin

    Process{
        foreach ($computer in $ComputerName){
            try{
                $Session = New-CimConnection -ComputerName $computer -Protocol $Protocol -ErrorAction Stop
                $Groups = Get-CimInstance -CimSession $Session -ClassName Win32_Group -Filter "LocalAccount=True $GroupNameFilter"
                
                foreach ($group in $Groups){
                    $GroupComponent = Get-CimInstance -CimSession $Session -ClassName Win32_GroupUser -Filter "GroupComponent=""Win32_Group.Domain='$computer',Name='$($group.Name)'"""
                    if ($IncludeGroupsWithMembersOnly){
                        if ($null -eq $GroupComponent){
                            continue
                        }
                    }
                    $Members = foreach ($member in $GroupComponent){
                        [PSCustomObject]@{
                            PSTypeName = "SysAdminTools.LocalGroupMember"
                            Name = $member.PartComponent.Name
                            Domain = $member.PartComponent.Domain
                            MemberType = $member.PartComponent.cimclass.cimclassname.split('_')[1]
                        }
                    }
                    [PSCustomObject]@{
                        PSTypeName = "SysAdminTools.LocalGroup"
                        ComputerName = $computer
                        GroupName = $group.Name
                        Member = $Members
                        Description = $group.Description
                        Domain = $group.Domain
                        Caption = $group.Caption
                        SID = $group.SID
                        SIDType = $group.SIDType
                        LocalAccount = $group.LocalAccount
                        Status = $group.Status
                    }
                }
                $Session | Remove-CimSession
            }
            catch{
                if ($Session){
                    $Session | Remove-CimSession
                }
                $PSCmdlet.WriteError($_)
            }
        } #foreach computer
    } #Process
}