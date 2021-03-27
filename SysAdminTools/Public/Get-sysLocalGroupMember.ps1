function Get-sysLocalGroupMember{
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
        [Parameter(ValueFromPipeline)]
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
                        if ($GroupComponent -eq $null){
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