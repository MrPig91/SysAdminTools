<#
.SYNOPSIS
    This function gets the current user sesions on a remote or local computer.
.DESCRIPTION
    This function uses quser.exe to get the current user sessions from a remote or local computer.
.PARAMETER ComputerName
    Use this paramter to specify the computer you want to run the command aganist using its name or IPAddress.

.EXAMPLE
    PS C:\> Get-LoggedInUser

    ComputerName    UserName ID SessionType State  ScreenLocked IdleTime
    ------------    -------- -- ----------- -----  ------------ --------
    DESKTOP-D7FU4K5 pwsh.cc  1  DirectLogon Active False        0

    This examples gets the logged in users of the local computer.
.EXAMPLE
    Get-LoggedInUser -ComputerName $env:COMPUTERNAME,dc01v

    ComputerName    UserName      ID SessionType State  ScreenLocked IdleTime
    ------------    --------      -- ----------- -----  ------------ --------
    DESKTOP-D7FU4K5 pwsh.cc       1  DirectLogon Active False        0
    dc01v           administrator 1  DirectLogon Active False        0

    This example gets the currently logged on users for the local computer and a remote computer called dc01v.
.INPUTS
    System.String
        You can pipe a string that contains the computer name.
.OUTPUTS
    AdminTools.LoggedInuser
        Outputs a custom powershell object
.NOTES
    Requires Admin
#>
Function Get-LoggedInUser () {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias("CN","Name","MachineName")]
        [string[]]$ComputerName = $ENV:ComputerName
    )

    PROCESS {
        foreach ($computer in $ComputerName){
            try{
                Write-Information "Testing connection to $computer" -Tags 'Process'
                if (Test-Connection -ComputerName $computer -Count 1 -Quiet){
                    $Users = quser.exe /server:$computer 2>$null | select -Skip 1

                    if (!$?){
                        Write-Information "Error with quser.exe" -Tags 'Process'
                        if ($Error[0].Exception.Message -eq ""){
                            throw $Error[1]
                        }
                        else{
                            throw $Error[0]
                        }
                    }
    
                    $LoggedOnUsers = foreach ($user in $users){
                        [PSCustomObject]@{
                            PSTypeName = "AdminTools.LoggedInUser"
                            ComputerName = $computer
                            UserName = (-join $user[1 .. 20]).Trim()
                            SessionName = (-join $user[23 .. 37]).Trim()
                            SessionId = [int](-join $user[38 .. 44])
                            State = (-join $user[46 .. 53]).Trim()
                            IdleTime = (-join $user[54 .. 63]).Trim()
                            LogonTime = [datetime](-join $user[65 .. ($user.Length - 1)])
                            LockScreenPresent = $false
                            LockScreenTimer = (New-TimeSpan)
                            SessionType = "TBD"
                        }
                    }
                    try {
                        Write-Information "Using WinRM and CIM to grab LogonUI process" -Tags 'Process'
                        $LogonUI = Get-CimInstance -ClassName win32_process -Filter "Name = 'LogonUI.exe'" -ComputerName $Computer -Property SessionId,Name,CreationDate -OperationTimeoutSec 1 -ErrorAction Stop
                    }
                    catch{
                        Write-Information "WinRM is not configured for $computer, using Dcom and WMI to grab LogonUI process" -Tags 'Process'
                        $LogonUI = Get-WmiObject -Class win32_process -ComputerName $computer -Filter "Name = 'LogonUI.exe'" -Property SessionId,Name,CreationDate -ErrorAction Stop |
                        select name,SessionId,@{n="Time";e={[DateTime]::Now - $_.ConvertToDateTime($_.CreationDate)}}
                    }
    
                    foreach ($user in $LoggedOnUsers){
                        if ($LogonUI.SessionId -contains $user.SessionId){
                            $user.LockScreenPresent = $True
                            $user.LockScreenTimer = ($LogonUI | where SessionId -eq $user.SessionId).Time
                        }
                        if ($user.State -eq "Disc"){
                            $user.State = "Disconnected"
                        }
                        $user.SessionType = switch -wildcard ($user.SessionName){
                            "Console" {"DirectLogon"; Break}
                            "" {"Unkown"; Break}
                            "rdp*" {"RDP"; Break}
                            default {""}
                        }
                        if ($user.IdleTime -ne "None" -and $user.IdleTime -ne "."){
                            if ($user.IdleTime -Like "*+*"){
                                $user.IdleTime = New-TimeSpan -Days $user.IdleTime.Split('+')[0] -Hours $user.IdleTime.Split('+')[1].split(":")[0] -Minutes $user.IdleTime.Split('+')[1].split(":")[1]
                            }
                            elseif($user.IdleTime -like "*:*"){
                                $user.idleTime = New-TimeSpan -Hours $user.IdleTime.Split(":")[0] -Minutes $user.IdleTime.Split(":")[1]
                            }
                            else{
                                $user.idleTime = New-TimeSpan -Minutes $user.IdleTime
                            }
                        }
                        else{
                            $user.idleTime = New-TimeSpan
                        }
    
                        $user | Add-Member -Name LogOffUser -Value {logoff $this.SessionId /server:$($this.ComputerName)} -MemberType ScriptMethod
                        $user | Add-Member -MemberType AliasProperty -Name ScreenLocked -Value LockScreenPresent

                        Write-Information "Outputting user object $($user.UserName)" -Tags 'Process'
                        $user
                    } #foreach
                } #if ping
                else{
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Net.NetworkInformation.PingException]::new("$computer is unreachable"),
                        'TestConnectionException',
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $computer
                    )
                    $PSCmdlet.WriteError($ErrorRecord)
                }
            } #try
            catch [System.Management.Automation.RemoteException]{
                if ($_.Exception.Message -like "No User exists for *"){
                    Write-Warning "No users logged into $computer"
                }
                elseif ($_.Exception.Message -like "*The RPC server is unavailable*"){
                    Write-Warning "quser.exe failed on $comptuer, Ensure 'Netlogon Service (NP-In)' firewall rule is enabled"
                    $PSCmdlet.WriteError($_)
                }
            }
            catch [System.Runtime.InteropServices.COMException]{
                Write-Warning "WMI query failed on $computer. Ensure 'Windows Management Instrumentation (WMI-In)' firewall rule is enabled."
                $PSCmdlet.WriteError($_)
            }
            catch{
                Write-Information "Unexpected error occurred with $computer"
                $PSCmdlet.WriteError($_)
            }
        } #foreach
    } #process
}