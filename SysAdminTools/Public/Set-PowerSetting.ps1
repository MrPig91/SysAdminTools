<#
.SYNOPSIS
    This function sets a power settings for local or remote computer(s) to a new value.
.DESCRIPTION
    This function sets a power settings for local or remote computer(s) to a new value, it always activates the power plan to ensure this setting takes effect.
    All settings values are Index Values that map to human readable values or an integer value that indicate seconds, charge, etc.
    In order to best know what values are availabe for a specific setting I strongly recommend using CTRL+Space to see all possible Index values and their human readable names.
.PARAMETER ComputerName
    This parameter specifies the ComputerName for the computer you want to set power setting for. Default value is $ENV:COMPUTERNAME.
.PARAMETER PlanName
    This parameter specifies the plan name of the plan you want to set a power settings for, use tab completion or pipe a power setting object for ease of use.
.PARAMETER SettingName
    This parameter specifies the name of the power setting you want to set, tab completion is available.
.PARAMETER SettingType
    This parameter specifies the power type for the setting, options include DC (on battery) or AC (wall power) power.
.PARAMETER IndexValue
    This is the value you want to set the power setting to. I highly recommend using CTRL+Space to see all availabe options and to see friendly names for index values.
.EXAMPLE
    PS C:\> Get-PowerSetting -ComputerName TEST-LAPTOP02-L -ActivePlanOnly -SettingType AC -SettingName "Console lock display off timeout"

        Plan Name: Balanced

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    TEST-LAPTOP02-L    True      AC    Console lock display off timeout                   60 Seconds                          {0, 4294967295}


    PS C:\> Get-PowerSetting -ComputerName TEST-LAPTOP02-L -ActivePlanOnly -SettingType AC -SettingName "Console lock display off timeout" | Set-PowerSetting -IndexValue 1800
    PS C:\> Get-PowerSetting -ComputerName TEST-LAPTOP02-L -ActivePlanOnly -SettingType AC -SettingName "Console lock display off timeout"


        Plan Name: Balanced

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    TEST-LAPTOP02-L    True      AC    Console lock display off timeout                   1800 Seconds                        {0, 4294967295}

    The first command gets the "Console lock display off timeout" power setting for TEST-LAPTOP02-L and outputs it to the console. We se it is set to 60 seconds.
    The second command runs the same command but then pipes it to Set-PowerSetting and provides the value 1800 to the parameter IndexValue. This will set that setting to 1800 seconds (30 minutes).
    The last command run the first command again to confirm that the setting was udpated to the new vale, and here we can see that it was.

    This particular setting's default value of 60 seconds is pretty low. It will put the computer asleep after 60 seconds a user locking their computer.
    If the user is just getting up to for a minutes it can frustrating to come back and have to wake the computer.
.EXAMPLE
    PS C:\> Set-PowerSetting -SettingName "Lid close action" -SettingType AC -IndexValue 0 -PlanName "HP Optimized (recommended)"
    PS C:\> Get-PowerSetting -SettingName "Lid close action" -SettingType AC -PlanName "HP Optimized (recommended)"


    Plan Name: HP Optimized (recommended)

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    Test-COMPUTER-L   True      AC    Lid close action                                   Do nothing                          {Do nothing, Sleep, Hibernate, Shut down}

    The first command set the "Lid close action" setting to the IndexValue of 0 (do nothing). We used ctrl+space tab complettion to see all the options for index values.
    The second command confirms the setting was changed to what we want and we can see that it was.
.INPUTS
    Inputs (if any)
.OUTPUTS
    None
.NOTES
    Requires Admin
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Set%E2%80%90PowerSetting
#>
function Set-PowerSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("PlanId")]
        [ArgumentCompleter({
            param ($commandName,$parameterName,$wordToComplete,$commandAst,$fakeBoundParameters)
                $param = @{
                    Query = "select ElementName,IsActive from Win32_PowerPlan WHERE ElementName LIKE '%$wordToComplete%'"
                    ComputerName = $fakeBoundParameters.ComputerName
                    Namespace = "root\cimv2\power"
                }
                Get-CimInstance @param  | Foreach-Object {
                    $Active = "InActive"
                    if ($_.IsActive){
                        $Active = "Active"
                    }
                    [System.Management.Automation.CompletionResult]::new("`"$($_.ElementName)`"","$($_.ElementName) - $Active","ParameterValue","$($_.ElementName)")
                }
        })]
        [string]$PlanName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("SettingId")]
        [ArgumentCompleter({
            param ($commandName,$parameterName,$wordToComplete,$commandAst,$fakeBoundParameters)
                $param = @{
                    Query = "select ElementName from Win32_PowerSetting WHERE ElementName LIKE '%$wordToComplete%'"
                    ComputerName = $fakeBoundParameters.ComputerName
                    Namespace = "root\cimv2\power"
                }
                Get-CimInstance @param  | Foreach-Object {
                    [System.Management.Automation.CompletionResult]::new("`"$($_.ElementName)`"","$($_.ElementName)","ParameterValue","$($_.ElementName)")
                }
        })]
        [string]$SettingName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet("AC","DC")]
        [string]$SettingType,
        
        [Parameter()]
        [ArgumentCompleter({
            param ($commandName,$parameterName,$wordToComplete,$commandAst,$fakeBoundParameters)
                $param = @{
                    PlanName =  $fakeBoundParameters.PlanName
                    SettingName = $fakeBoundParameters.SettingName
                    SettingType = $fakeBoundParameters.SettingType
                }
                Get-PowerSetting @param  | Foreach-Object {
                    if ($_.SettingValueType -eq "Range"){
                        $ToolTip = "The value can be any number between $($_.SettingValueRange -join " - ")"
                        $_.SettingValueRange | foreach {
                            [System.Management.Automation.CompletionResult]::new("`"$($_)`"","$_","ParameterValue",$ToolTip)
                        }
                    }
                    else{
                        $_.SettingValueRangeObjects | foreach {
                            $ToolTip =  "Name: $($_.ElementName)`nIndexValue: $($_.SettingIndex)"
                            [System.Management.Automation.CompletionResult]::new("$($_.SettingIndex)","$($_.ElementName)","ParameterValue",$ToolTip)
                        }
                    }
                }
        })]
        $IndexValue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    Process {
        try{
            $Session = New-CimConnection -ComputerName $ComputerName
                $CimParameters = @{
                    CimSession = $Session
                    Namespace = "root\cimv2\power"
                    ErrorAction = "Stop"
                }
                $PlanQuery = "select InstanceID,ElementName from Win32_Powerplan WHERE ElementName='$PlanName' OR InstanceID LIKE '%$PlanName'"
                # Get the Active Power Plan
                Write-Information "Querying win32_PowerPlan - $PlanQuery"
                $CimParameters["Query"] = $PlanQuery
                $PowerPlan = Get-CimInstance @CimParameters
                $PowerPlanId = $PowerPlan | Select-Object -ExpandProperty InstanceId | Split-Path -Leaf
                if ($null -eq $PowerPlanId){
                    throw "Power Plan [$PlanName] was not found on computer [$ComputerName]!"
                }
                Write-Information "Found power plan [$PlanName] on computer [$ComputerName]"

                #Get Setting Name / ID
                $CimParameters["Query"] = "select ElementName,InstanceID from Win32_PowerSetting WHERE ElementName = '$SettingName' OR InstanceId LIKE '%$SettingName'"
                $SettingId = Get-CimInstance @CimParameters | Select-Object -ExpandProperty InstanceId | Split-Path -Leaf
                if ([string]::IsNullOrEmpty($SettingId)){
                    throw "Setting [$SettingName] was not found on computer [$ComputerName]!"
                }
                Write-Information "Matched setting name [$SettingName] with setting ID [$SettingId]"

                $CimParameters["Query"] = "select * from Win32_PowerSettingDataIndex WHERE InstanceID LIKE '%$PowerPlanId\\$SettingType\\$SettingId'"
                $Setting = Get-CimInstance @CimParameters
                if ($null -eq $Setting){
                    throw "Unable to find setting with supplied parameters on computer [$ComputerName]!"
                }

                #$Setting
                Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    Set-CimInstance -Namespace "root\cimv2\power" -Query $args[0] -Property @{SettingIndexValue = $args[1]}
                    powercfg /setactive $args[2].Replace('{',"").Replace('}',"")
                } -ArgumentList $CimParameters["Query"],$IndexValue,$PowerPlanId

                $Session | Remove-CimSession -ErrorAction SilentlyContinue
        }
        catch{
            $Session | Remove-CimSession -ErrorAction SilentlyContinue
            $PSCmdlet.WriteError($_)
        } #try / catch
    } #Process
}