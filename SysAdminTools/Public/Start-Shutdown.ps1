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