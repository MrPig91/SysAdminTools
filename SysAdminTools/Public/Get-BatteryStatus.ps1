<#
.SYNOPSIS
    This functions get the current state of both internal and external (UPS) batteries.
.DESCRIPTION
        This functions get the current state of both internal and external (UPS) batteries. Including their charging state, charge remaining, estimated run time, etc.
.EXAMPLE
    PS C:\> Get-BatteryStatus

    ComputerName    Name    Charge (%)                  Run Time Battery Status  Status
    ------------    ----    ----------                  -------- --------------  ------
    DESKTOP-RFR3S01 GX1500U [XXXXXXXXXXXXXXXXXXXX] 100% 55       Connected_To_AC OK

    This example gets the local computer's battery status. The view built for this function shows the charge as bar graph (colored in the console).
.INPUTS
    System.String
        -ComputerName
.OUTPUTS
    SysAdminTools.BatteryStatus
.NOTES
    This function uses WsMan by default and Dcom protocol if that fails.
#>
function Get-BatteryStatus{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("CN","Name","IPAddress")]
        [string[]]$ComputerName = $ENV:COMPUTERNAME
    )
    Begin{
        enum Availability {
            Other = 1
            Unknown = 2
            Running_FullPower = 3
            Warning = 4
            In_Test = 5
            Not_Applicable = 6
            Power_Off = 7
            Offline = 8
            Off_Duty = 9
            Degraded = 10
            Not_Installed = 11
            Install_Error = 12
            Power_Save_Unknown = 13
            Power_Save_Low_Power_Mode = 14
            Power_Save_StandBy = 15
            Power_Cycle = 16
            Power_Save_Warning = 17
            Paused = 18
            Not_Ready = 19
            Not_Configured = 20
            Quiesced = 21
        }

        enum BatteryStatus {
            Other_Discharging = 1
            Connected_To_AC = 2
            Fully_Charged = 3
            Low = 4
            Critical = 5
            Charging = 6
            Charing_High = 7
            Charging_Low = 8
            Charging_Critical = 9
            Partially_Charged = 11
        }

        enum Chemistry {
            Other = 1
            Unknown = 2
            Lead_Acid = 3
            Nickel_Cadmium = 4
            Nickel_Metal_Hydride = 5
            Lithium_ion = 6
            Zinc_air = 7
            Lithium_Polymer = 8
        }

        enum PowerManagementCapabilities {
            Unknown = 0
            Not_Supported = 1
            Disabled = 2
            Enabled = 3
            Power_Saving_Modes_Entered_Automatically = 4
            Power_State_Settable = 5
            Power_Cycling_Supported = 6
            Timed_Power_On_Supported = 7

        }
    } #begin

    Process{
        foreach ($computer in $ComputerName){
            if (Test-Connection -ComputerName $computer -Count 1 -Quiet){
                Try{
                    $CimSession = New-CimSession -ComputerName $computer -OperationTimeoutSec 1 -ErrorAction Stop
                }
                catch{
                    try{
                        Write-Information "Unable to connect to $computer with Wsman, using DCOM protocl instead" -Tags 'Process'
                        $CimSession = New-CimSession -ComputerName $computer -SessionOption (New-CimSessionOption -Protocol Dcom) -OperationTimeoutSec 1 -ErrorAction Stop
                    }
                    catch{
                        Write-Error "Unable to connect to $computer with Wsman or Dcom protocols"
                        continue
                    }   
                }
                try{
                    $Batteries = Get-CimInstance -CimSession $CimSession -ClassName Win32_Battery 
                    foreach ($battery in $Batteries){
                        [PSCustomObject]@{
                            PSTypeName = "SysAdminTools.BatteryStatus"
                            ComputerName = $computer
                            Name = $battery.Name
                            DesignVoltage = $battery.DesignVoltage
                            EstimatedChargeRemaining = $battery.EstimatedChargeRemaining
                            EstimatedRunTime = $battery.EstimatedRunTime
                            Availability = [Availability]($battery.Availability)
                            BatteryStatus = [BatteryStatus]($battery.BatteryStatus)
                            Chemistry = [Chemistry]($battery.Chemistry)
                            Status = $battery.Status
                            DeviceID = $battery.DeviceID
                        }
                    }
                    $CimSession | Remove-CimSession
                }
                catch{
                    if ($CimSession){
                        $CimSession | Remove-CimSession
                    }
                    $PSCmdlet.WriteError($_)
                } #catch
            } #try
        } #foreach
    } #process
}