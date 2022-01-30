<#
.SYNOPSIS
    This function will initiate a comptuer shutdown (or reboot) with more advanced options thant Stop-Computer.
.DESCRIPTION
    This function will initiate a comptuer shutdown (or reboot) with more advanced options thant Stop-Computer.

    You can specify the a remote computer to shutdown, reboot, or poweroff (default is shutdown).
    You can specify a delay before the shutdown begins (default is 0 seconds).
    You can specfiy Reasons codes (Major and minor) for the shutdown (default is Other).
    You can specify a comment you would like to present to the user when run the command.
    The force switch will force a shut down the comptuer even when their are users logged in.
    The unplanned switch will mark the shutdown event as unplanned in the eventlogs.
.PARAMETER ComputerName
    This parameter specifies which computer(s) you would like to initiate a shutdown on, default is the local computer.
.PARAMETER Delay
    This parameter allows you to specify a delay (in seconds) before the shutdown begins (default is 0 seconds).
.PARAMETER ShutdownType
    This parameter allows you specify the shutdown type which includes Shutdown, Reboot, and Poweroff. The deault is Shutdown.
.PARAMETER MajorReasonCode
    This parameter allows you to specify a Major Reason Code for the shutdown. This will be stored in the eventlogs and will provide more inforation for the purpose of the shutdown.
    The deault value for this parameter is "Other" but you can find all possible values by running "[ShutDown_MajorReason].GetEnumNames()" in the console.
.PARAMETER MinorReasonCode
    This parameter allows you to specify a Minor Reason Code for the shutdown. This will be stored in the eventlogs and will provide more inforation for the purpose of the shutdown.
    The deault value for this parameter is "Other" but you can find all possible values by running "[ShutDown_MinorReason].GetEnumNames()" in the console.
.PARAMETER Comment
    This parameter will allow you to add a customized message that will appear to any logged in users after you run the command.
    If no comment is specified, then a generic one will be generated using the string below.
    "$ShutdownType command sent from user $ENV:USERNAME on computer $ENV:COMPUTERNAME with a delay of $Delay seconds"
.PARAMETER Force
    This switch parameter will force a shutdown even if there are users currently logged into the target computer. If this switch is no specified then the command will fail IF a user is logged into the target computer.
.PARAMETER Unplanned
    This switch parameter will mark the shutdown event as unplanned in the eventlogs. By default, this function will mark the shutdown event as planned.
.EXAMPLE
    PS C:\> Rename-Computer -ComputerName mrpig-computer -NewName mrpig-desktop -DomainCredential (Get-Credential)
    PS C:\> Start-Shutdown -ComputerName mrpig-computer -ShutdownType Reboot -Delay 60 -Major_ReasonCode OTHER -Minor_ReasonCode MAINTENANCE -Comment "This computer needs to be renamed and will restart in 30 seconds, please save all work" -Force

    ComputerName      : mrpig-computer
    ShutdownType      : Reboot
    ReasonCode        : OTHER: MAINTENANCE
    Delay             : 60
    CommandSuccessful : 
    
    PS C:\>Get-RestartHistory -ComputerName mrpig-desktop | select -First 1 | Format-List -Properties *

    ComputerName     : mrpig-desktop
    InitiatedBy      : MRPIGLAND\adminMRPIG
    ShutdownType     : restart
    ReasonCode       : 0x80000001
    Reason           : No title for this reason could be found
    Comment          : This computer needs to be renamed and will restart in 30 seconds, please save all work
    InitiatedProcess : C:\WINDOWS\system32\wbem\wmiprvse.exe (mrpig-computer)
    Time             : 11/11/2021 1:55:20 PM
    
    
    In this example we first rename the comptuer, but do not restart it. We then use the Start-Shutdown function
    to initiate the restart, but we gave any logged in users 60 seconds to save work and provided a message that will
    display on their screen by using the comment parameter. After the computer reboots we run Get-RestartHistory to grab the log event 
    of the reboot and there we can see that the reason code is stored (although cannot be translated to its friendly name) along with our comment. 
    This will provide key information for a shutdown event when other admins look at computer's restart history. One of main benefite of
    using Start-Shutdown over Stop-Computer or restarting with Restart wich on Reanme-Computer is the ability to provide the user
    with an on-screen message and implement a delay before the restart actually happens.
.INPUTS
    [string]
        ComputerName
.OUTPUTS
    [pscustomeobject]
        Properties: ComputerName, ShutdownType, ReasonCode, Delay, CommandSuccessful
.NOTES
    Requires admin if the target computer is remote.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Start%E2%80%90Shutdown
#>
function Start-Shutdown {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("CN","Name","MachineName")]
        [string[]]$ComputerName = $ENV:COMPUTERNAME,

        [Parameter()]
        [ValidateSet("Shutdown","Reboot","PowerOff")]
        [string]$ShutdownType = "Reboot",

        [Parameter()]
        [int]$Delay = 0,

        [Parameter()]
        [ShutDown_MajorReason]$Major_ReasonCode = [ShutDown_MajorReason]::Other,

        [Parameter()]
        [ShutDown_MinorReason]$Minor_ReasonCode = [ShutDown_MinorReason]::Other,

        [Parameter()]
        [string]$Comment,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Unplanned
    )

    begin {
        if ($Force){
            $Flags = ([ShutDownType]$ShutdownType).value__ + 4
        }
        else{
            $Flags = ([ShutDownType]$ShutdownType).value__
        }
        $Planned_ReasonCode = (0x80000000) * -1
        if ($Unplanned){
            $ReasonCode = $Major_ReasonCode.value__ + $Minor_ReasonCode.value__
        }
        else{
            $ReasonCode = $Major_ReasonCode.value__ + $Minor_ReasonCode.value__ + $Planned_ReasonCode
        }

        
        if (!($PSBoundParameters.ContainsKey("Comment"))){
            $Comment = "$Type command sent from user $ENV:USERNAME on computer $ENV:COMPUTERNAME with a delay of $Delay seconds"
        }

        $ShutdownParamters = @{
            Flags = $Flags
            Comment = $Comment
            ReasonCode = $ReasonCode
            Timeout = $Delay
        }
    } #begin
    
    process {
        foreach ($computer in $ComputerName){
            if (Test-Connection -ComputerName $computer -Quiet -Count 1){
                Try{
                   $session = New-CimSession -ComputerName $computer -OperationTimeoutSec 1 -ErrorAction Stop
                }
                catch{
                    try{
                        Write-Information "Unable to connect to $computer with Wsman, using DCOM protocl instead" -Tags Process
                        $session = New-CimSession -ComputerName $computer -SessionOption (New-CimSessionOption -Protocol Dcom) -ErrorAction Stop
                    }
                    catch{
                        Write-Error "Unable to connect to $computer with Wsman or Dcom protocols"
                        continue
                    }   
                }
                $Win32_OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $session
                $ReturnCode = (Invoke-CimMethod -CimInstance $Win32_OperatingSystem -MethodName Win32ShutdownTracker -Arguments $ShutdownParamters -CimSession $Session).ReturnValue
                $session | Remove-CimSession
                if ($ReturnCode -eq 0){
                    [PSCustomObject]@{
                        ComputerName = $computer
                        ShutdownType = $ShutdownType
                        ReasonCode = "$($Major_ReasonCode): $Minor_ReasonCode"
                        Delay = $Delay
                        CommandSuccessful = $true
                    }
                }
                elseif ($ReturnCode -eq 1191){
                    Write-Error "$ShutdownType action Failed for $($computer): The system shutdown cannot be initiated because there are other users logged on to the computer, use the -Force parameter to force a shutdown operation($Returncode)"
                }
                elseif ($ReturnCode -eq 1190){
                    Write-Error "$ShutdownType action failed for $($computer): A system shutdown has already been scheduled.($ReturnCode)"
                }
                else{
                    Write-Error "$ShutdownType action failed for $($computer): Reason code $ReturnValue"
                }
            } #if
            else{
                Write-Warning "$computer is unreachable"
            }
        } #foreach
    } #process
}