<#
.SYNOPSIS
    This function gets the current user sesions on a remote or local computer.
.DESCRIPTION
    This function uses quser.exe to get the current user sessions from a remote or local computer.
.EXAMPLE
    PS C:\> Get-LoggedInUser

    This examples gets the logged in users of the local computer.
.INPUTS
    System.String
        You can pipe a string that contains the computer name.
.OUTPUTS
    AdminTools.LoggedInuser
        Outputs a custom powershell object
.NOTES
    General notes
#>
Function Get-LoggedInUser () {
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias("CN","Name","MachineName")]
        [string[]]$ComputerName = $ENV:ComputerName
    )

    PROCESS{
        foreach ($computer in $ComputerName){
            if (Test-Connection -ComputerName $computer -Count 1 -Quiet){
                $Users = (cmd /c quser.exe /server:$computer "2>NUL" | select -Skip 1)
                if (!$users){
                    Continue
                }

                $LoggedOnUsers = foreach ($u in $Users){
                    [PSCustomObject]@{
                        PSTypeName = "AdminTools.LoggedInUser"
                        ComputerName = $computer
                        UserName = (-join $u[1 .. 20]).Trim()
                        SessionName = (-join $u[23 .. 37]).Trim()
                        SessionId = [int](-join $u[38 .. 44])
                        State = (-join $u[46 .. 53]).Trim()
                        IdleTime = (-join $u[54 .. 63]).Trim()
                        LogonTime = [datetime](-join $u[65 .. ($u.Length - 1)])
                        LockScreenPresent = $false
                        LockScreenTimer = (New-TimeSpan)
                        SessionType = "TBD"
                    }
                }
                
                $LogonUI = Get-WmiObject -Class win32_process -ComputerName $computer -Filter "Name = 'LogonUI.exe'" -Property SessionId,Name,CreationDate |
                    select name,SessionId,@{n="Time";e={[DateTime]::Now - $_.ConvertToDateTime($_.CreationDate)}}

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
                    $user
                }
            } #if online
        } #foreach
    } #process
}