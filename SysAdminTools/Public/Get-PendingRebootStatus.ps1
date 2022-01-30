<#
.SYNOPSIS
    This function searches for any operations that awaiting a system reboot.
.DESCRIPTION
    This function searches the Windows registry for any operations that require a system reboot, most importantly a Windows update.
.EXAMPLE
    PS C:\> Get-PendingRebootStatus

    ComputerName    PendingReboot PendingRebootReasons
    ------------    ------------- --------------------
    DESKTOP-RFR3S01          True {FileRename}

    This example grabs the local computers pending reboot status. Currently it is only waiting on a file rename which is urgent. 
.INPUTS
    [string[]] ComputerName
.OUTPUTS
    PSCustomObject
.NOTES
    Uses CimClass StdRegProv to grab registry information.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90PendingRebootStatus
#>
function Get-PendingRebootStatus {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [Alias("CN","Name","MachineName")]
        [string[]]$Computername = $env:COMPUTERNAME
    )

    Begin{
        #Keys to use to reference each regsitry hive
        $HKEY_LOCAL_MACHINE = 2147483650

        #return codes
        <#
            RC = 0 for success
            RC = 1 for key read with no default value
            RC = 2 for key not found
            RC = 6 for invalid hive
        #>

        #Registry Paths to check
        $Updates = "SOFTWARE\Microsoft\Updates" #value UpdateExeVolatile is anything other than 0
        $FileRename = "SYSTEM\CurrentControlSet\Control\Session Manager" #value PendingFileRenameOperations, PendingFileRenameOperations2 exists
        $RebootRequired = "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" #key RebootRequired or PostRebootReporting exists
        $Pending = "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending" #GUID subkeys exists
        $RunOnce = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" #value DVDRebootSignal exist
        $ComponentBS = "Software\Microsoft\Windows\CurrentVersion\Component Based Servicing" #keys RebootPending,RebootInProgress,PackagesPending exits
        $CBSValues = @("RebootPending","RebootInProgress","PackagesPending")
        $CurrentRebootAttempts = "SOFTWARE\Microsoft\ServerManager" #key CurrentRebootAttempts exists
        $NetLogin = "SYSTEM\CurrentControlSet\Services\Netlogon" #values JoinDomain, AvoidSpnSet exits
        $NetLoginValues = @("JoinDomain","AvoidSpnSet")
        $ActiveComputerName = "SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" #value ComputerName is different than `
        #Value ComputerName in HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName is different
        $FutureName = "SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"

    } #Begin

    Process{
        foreach ($computer in $Computername){
            if (Test-Connection -ComputerName $computer -Quiet -Count 1){
                $PendingReboot = $false
                $PendingRebootReasons = [System.Collections.Generic.List[string]]::New()
                Write-Information "[$Computer] is reachable" -Tags "Process"
                try{
                    $CimSession = New-CimConnection -ComputerName $computer -ErrorAction Stop
                    $RemoteRegistry = Get-CimClass -Namespace "root\default" -ClassName StdRegProv -CimSession $CimSession -ErrorAction Stop
                    Write-Information "[$computer]: started a new cim session and connected to remote registry"
                    
                    $UpdatesResults = $RemoteRegistry | Invoke-CimMethod -Name "GetDWORDValue" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$Updates;sValueName="UpdateExeVolatile"} -CimSession $CimSession
                    if ($UpdatesResults.ReturnValue -eq 0 -and $UpdatesResults.uValue -ne 0){
                        Write-Information "UpdateExeVolatile value does not equal 0" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("MSUpdates")
                    }

                    $FileRenameResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumValues" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$FileRename} -CimSession $CimSession
                    $ContainsFileNameValues = ($FileRenameResults.sNames -Contains "PendingFileRenameOperations" -or $FileRenameResults.sNames -Contains "PendingFileRenameOperations2")
                    if ($FileRenameResults.ReturnValue -eq 0 -and $ContainsFileNameValues){
                        Write-Information "FileNameOpertions values exists" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("FileRename")
                    }

                    $RebootRequiredResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumKey" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$RebootRequired} -CimSession $CimSession
                    $ContainsRebootValues = ($RebootRequiredResults.sNames -Contains "RebootRequired" -or $RebootRequiredResults.sNames -Contains "PostRebootReporting")
                    if ($RebootRequiredResults.ReturnValue -eq 0 -and $ContainsRebootValues){
                        Write-Information "RebootRequired value exists" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("WindowsUpdates")
                    }

                    $PendingResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumKey" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$Pending} -CimSession $CimSession
                    if ($PendingResults.ReturnValue -eq 0 -and $null -ne $PendingResults.sNames){
                        Write-Information "GUID keys exists under Pending key exits" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("ServicesPending")
                    }

                    $RunOnceResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumValues" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$RunOnce} -CimSession $CimSession
                    if ($RunOnceResults.ReturnValue -eq 0 -and $RunOnceResults.sNames -contains "DVDRebootSignal"){
                        Write-Information "DVDRebootSignal value exits" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("RunOnce")
                    }

                    $ComponentBSResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumKey" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyname=$ComponentBS} -CimSession $CimSession
                    if ($ComponentBSResults.ReturnValue -eq 0){
                        $ComponentBSResults.sNames | where {$_ -in $CBSValues} | ForEach-Object -Process {
                            $PendingReboot = $true
                            Write-Information "$_ key exits" -Tags "Process"
                            $PendingRebootReasons.Add($_)
                        }
                    }

                    $CurrentRebootAttemptsResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumKey" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyname=$CurrentRebootAttempts} -CimSession $CimSession
                    if ($CurrentRebootAttemptsResults.ReturnValue -eq 0 -and $CurrentRebootAttemptsResults.sNames -contains "CurrentRebootAttempts"){
                        Write-Information "CurrentRebootAttempt key exits" -Tags "Process"
                        $PendingReboot = $true
                        $PendingRebootReasons.Add("CurrentRebootAttempts")
                    }

                    $NetLoginResults = $RemoteRegistry | Invoke-CimMethod -Name "EnumValues" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$NetLogin} -CimSession $CimSession
                    if ($NetLoginResults.ReturnValue -eq 0){
                        $NetLoginResults.sNames | where {$_ -in $NetLoginValues} | ForEach-Object -Process {
                            $PendingReboot = $true
                            Write-Information "$_ value exits" -Tags "Process"
                            $PendingRebootReasons.Add($_)
                        }
                    }

                    $ActiveComputerNameResults = $RemoteRegistry | Invoke-CimMethod -Name "GetStringValue" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$ActiveComputerName;sValueName="ComputerName"} -CimSession $CimSession
                    $FutureNameResults =  $RemoteRegistry | Invoke-CimMethod -Name "GetStringValue" -Arguments @{hDefKey=$HKEY_LOCAL_MACHINE;sSubKeyName=$FutureName;sValueName="ComputerName"} -CimSession $CimSession
                    if ($ActiveComputerName.ReturnValue -eq 0 -and $FutureNameResults.ReturnValue -eq 0){
                        if ($ActiveComputerNameResults.sValue -eq $FutureNameResults.sValue){
                            Write-Information "Pending computer name change" -Tags "Process"
                            $PendingReboot = $true
                            $PendingRebootReasons.Add("PendingNameChange")
                        }
                    }

                    [PSCustomObject]@{
                        ComputerName = $computer
                        PendingReboot = $PendingReboot
                        PendingRebootReasons = $PendingRebootReasons
                    }
                    $CimSession | Remove-CimSession
                }
                catch{
                    $PSCmdlet.WriteError($_)
                }
            }
            else{
                Write-Error "[$computer] is unreachable"
            }
        } #foreach computer
    } #process
}