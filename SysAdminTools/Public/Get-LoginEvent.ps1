<#
.SYNOPSIS
    This will grab logon events (both failed and/or successful) on a local or remote computers.
.DESCRIPTION
    This will grab logon events (both failed and/or successful) on a local or remote computers.
    This will display information around this local attepmt as well, inclduing LogonType, UserName, Failure Reason, etc.
.EXAMPLE
    PS C:\> Get-LoginEvent -UserName mrpig -Status Failed

    ComputerName    UserName         DomainName LogonType   IPAddress RemoteComputer  Success TimeCreated           FailureReason
    ------------    --------         ---------- ---------   --------- --------------  ------- -----------           -------------
    test-desktop    mrpig            PIGLAND    Interactive 127.0.0.1 test-desktop    False   8/27/2021 11:08:26 AM Unknown user name or bad password.
    test-desktop    mrpig            PIGLAND    Interactive 127.0.0.1 test-desktop    False   8/27/2021 11:08:20 AM Unknown user name or bad password.
    
    This grabs all failed login attempts from the user mrpig on the local computer.

.EXAMPLE
    Get-LoginEvent -LogonType Interactive -ComputerName test-desktop | group username | where {$_.name -notlike "UMFD*" -and $_.name -notlike "DWM*"} | select count,Name

    Count Name
    ----- ----
        9 mrpig
        8 mrspig

    This example grabs all users who log into the computer test-desktop interactively, then filters out the windows logins UMFD and DWM. Finally it groups the users to show how many times each one logged in.

.EXAMPLE
    PS C:\> Get-LoginEvent -ComputerName server02v -LogonType RemoteInteractive -StartTime (get-date).AddDays(-2) -OutVariable Logins

    ComputerName UserName DomainName LogonType         IPAddress    RemoteComputer Success TimeCreated          FailureReason
    ------------ -------- ---------- ---------         ---------    -------------- ------- -----------          -------------
    server02v    admincs  PIGLAND    RemoteInteractive 10.99.120.85 server02v       True    8/31/2021 4:39:30 PM
    server02v    admincs  PIGLAND    RemoteInteractive 10.99.120.85 server02v       True    8/31/2021 4:39:30 PM

    This grabs all logon events on the server server02v that are of type RemoteInteractive (RDP) in the last 2 days. It also store the output in the variable Logins since the query can take some time.
.INPUTS
    string
        ComputerName
.OUTPUTS
    SysAdminTools.LoginEvent
.NOTES
    This query can take some time on remote computers. Requires admin for remote computers. Requires Powershell version 6 or higher when using the UserName parameter.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90LoginEvent
#>
function Get-LoginEvent {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("SamAccountName")]
        [string]$UserName,

        [datetime]$StartTime,
        [datetime]$EndTime,

        [ValidateSet("Interactive","Network","Batch","Service","Unlock","NetworkClearText","NewCredentials","RemoteInteractive","CachedInteractive")]
        [string]$LogonType,

        [ValidateSet("Failed","Successful")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Status = @("Failed","Successful"),

        [int]$MaxEvents
    )

    Begin {
        $Ids = [System.Collections.Generic.List[int]]::new()
        if ($Status.Contains("Failed")){
            [void]$Ids.Add(4625)
        }
        if ($Status.Contains("Successful")){
            [void]$Ids.Add(4624)
        }

        $filterHashTable = @{
            LogName = "Security"
            ID = $Ids.ToArray()
        }

        enum LogonType {
            Unknown = 0
            Interactive = 2
            Network = 3
            Batch = 4
            Service = 5
            Unlock = 7
            NetworkClearText = 8
            NewCredentials = 9
            RemoteInteractive = 10
            CachedInteractive = 11
        }

        if ($PSBoundParameters.ContainsKey("LogonType")){
            $filterHashTable["LogonType"] = [LogonType]$LogonType -as [int]
        }
        if ($PSBoundParameters.ContainsKey("StartTime")){
            $filterHashTable["StartTime"] = $StartTime
        }
        if ($PSBoundParameters.ContainsKey("EndTime")){
            $filterHashTable["EndTime"] = $EndTime
        }

        $Parameters = @{
            FilterHashtable = $filterHashTable
        }
        if ($PSBoundParameters.ContainsKey("MaxEvents")){
            $Parameters["MaxEvents"] = $MaxEvents
        }
    }

    Process {
        if ($PSBoundParameters.ContainsKey("UserName")){
            if (-not($PSVersionTable.PSVersion -ge [Version]::new(6,0))){
                throw "Requires Powershell Version 6 or higher in order to use the UserName parameter"
            }
            $filterHashTable["TargetUserName"] = $UserName
        }

        foreach ($computer in $ComputerName){
            $Parameters["ComputerName"] = $computer
            if (Test-Connection -ComputerName $computer -Quiet -Count 1){
                try{
                    Get-WinEvent @Parameters -ErrorAction Stop | ForEach-Object {
                        $Success = switch ($_.Id){
                            4624 {$true}
                            4625 {$false}
                        }
                        $LoginEvent = [PSCustomObject]@{
                            PSTypeName = "SysAdminTools.LoginEvent"
                            TimeCreated = $_.TimeCreated
                            ComputerName = $computer
                            Id = $_.Id
                            Success = $Success
                        }
                        $XML = [xml]$_.ToXml()
                        $XML.event.eventdata.data | ForEach-Object {
                            $LoginEvent | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.'#text'
                        }
                        $FailureReason = Get-LogonFailureReason -EventRecord $LoginEvent
                        $LoginEvent | Add-Member -MemberType AliasProperty -Name Username -Value TargetUserName
                        $LoginEvent | Add-Member -MemberType AliasProperty -Name DomainName -Value TargetDomainName
                        $LoginEvent | Add-Member -MemberType AliasProperty -Name SID -Value TargetUserSid
                        $LoginEvent | Add-Member -MemberType AliasProperty -Name RemoteComputer -Value WorkStationName
                        $LoginEvent | Add-Member -NotePropertyMembers @{
                            StatusString = $FailureReason.Status
                            SubStatusString = $FailureReason.SubStatus
                            FailureReasonString = $FailureReason.Reason
                        }
                        $LoginEvent.LogonType = [LogonType]($LoginEvent.LogonType)
                        $LoginEvent
                    }
                }
                catch{
                    $PSCmdlet.WriteError($_)
                }
            }
            else{
                Write-Error "Computer [$computer] is unreachable"
            }
        } #FOREACH
    } #PROCESS
}