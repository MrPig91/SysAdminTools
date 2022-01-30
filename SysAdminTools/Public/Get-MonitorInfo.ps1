<#
.SYNOPSIS
    This will grab the serial number, monitor name, and year of manufacture of all monitors connected to a computer.
.PARAMETER ComputerName
    Use this paramter to specify the computer(s) you want to run the command aganist using its name or IPAddress.
.DESCRIPTION
    This functions grabs the serial number, monitor name, and year of manufacture of all monitors
    connected to a computer.
.EXAMPLE
    PS C:\> Get-MonitorInfo

    ComputerName    MonitorName  SerialNumber YearOfManufacture
    ------------    -----------  ------------ -----------------
    DESKTOP-RFR3S01 Acer K272HUL T0SAA0014200              2014
    DESKTOP-RFR3S01 VX2457       UG01842A1649              2018

    This example grabs the monitors connected to the local computer.
.EXAMPLE
    PS C:\> Get-ComputerMonitor Client01v,Client02v

    ComputerName    MonitorName SerialNumber YearOfManufacture
    ------------    ----------- ------------ -----------------
    Client01v       HP HC240    XXXXXXXXXX                2017
    Client01v       HP HC240    XXXXXXXXXX                2017
    Client02v       HP E243i    XXXXXXXXXX                2018
    Client02v       HP E243i    XXXXXXXXXX                2018

    This example uses the ComputerName parameter, but it does so positionally which is why it
    is not written out. It grabs the info for all monitors connected to Client01v and Client02v. 
.INPUTS
    None
.OUTPUTS
    PsCustomObject
.NOTES
    Does not grab built-in monitor info.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90MonitorInfo
#>
function Get-MonitorInfo{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias("CN","Name","IPAddress")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = $Env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet("Wsman","Dcom")]
        $Protocol = "Wsman"
    )

    Begin{
        $options = New-CimSessionOption -Protocol $Protocol
    }

    Process{
        foreach ($computer in $ComputerName){
            try{
                Write-Information -MessageData "Creating new cim session for $computer with a $protocol connection" -Tags "Process"
                $Session = New-CimSession -ComputerName $computer -OperationTimeoutSec 1 -SessionOption $options -ErrorAction Stop
            
                Write-Information -MessageData "Calling WMIMonitorID Class to grab monitor info for computer $computer" -Tags "Process"
                $monitors = Get-CimInstance -ClassName WmiMonitorID -Namespace root\wmi -CimSession $Session | Where-Object UserFriendlyNameLength -NE 0
            
                foreach ($monitor in $monitors){
                    $SerialNumber = ($monitor.SerialNumberID -ne 0 | ForEach-Object{[char]$_}) -join ""
                    $MonitorName = ($monitor.UserFriendlyName -ne 0 | ForEach-Object{[char]$_}) -join ""

                    $Object = [PSCustomObject]@{
                        PSTypeName = "SysAdminTools.Monitor"
                        ComputerName = $computer.ToUpper()
                        MonitorName = $MonitorName
                        SerialNumber = $SerialNumber
                        YearOfManufacture = $monitor.YearOfManufacture
                    }
                    
                    $Object
                    Write-Information -MessageData "Created object for monitor $($object.MonitorName)" -Tags "Process"
                } #foreach

                Write-Information -MessageData "Removing $computer cim session" -Tags "Process"
                Get-CimSession | where computername -eq $computer | Remove-CimSession
            } 
            catch{
                Write-Warning "Unable to grab monitor info for $computer"
            }
        } #foreach computer
    } #Process
}