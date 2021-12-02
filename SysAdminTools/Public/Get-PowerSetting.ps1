<#
.SYNOPSIS
    This function gets power settings for local or remote computer(s).
.DESCRIPTION
    This function gets power setting for local or remote computer(s).
    You can filter the results using the parameters SettingName, PlanName, ActivePlanOnly, and SettingType.
.PARAMETER ComputerName
    This parameter specifies the ComputerName for the computer you want to get power setting from. Default value is $ENV:COMPUTERNAME.
.PARAMETER PlanName
    This parameter specifies the plan name of the plan you want to get power settings for. Common plan names include "HP Optmized" and "Balanced".
    The function will grab all settings for all plans if no plan name is give. User inputted wildcards are not permitted, but the value provided will have wildcards on both sides added to it.
.PARAMETER ActivePlanName
    This switch parameter will filter the power settings so that only the setting for currently active power plan are returned.
.PARAMETER SettingName
    This parameter specifies the name of the power setting you want to grab. Wildcards are accepted. By default, all settings are returned.
.PARAMETER SettingType
    This parameter specifies the power type for the setting, options include DC (on battery) or AC (wall power) power.
.EXAMPLE
    PS C:\>  Get-PowerSetting -ActivePlanOnly -SettingName *timeout* -SettingType AC

    Plan Name: HP Optimized (recommended)

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    TEST-MACHINE1-D   True      AC    Secondary NVMe Idle Timeout                        2000 milliseconds                   {0, 60000}
    TEST-MACHINE1-D   True      AC    Primary NVMe Idle Timeout                          200 milliseconds                    {0, 60000}
    TEST-MACHINE1-D   True      AC    System unattended sleep timeout                    3600 Seconds                        {0, 4294967295}
    TEST-MACHINE1-D   True      AC    Hub Selective Suspend Timeout                      50 Millisecond                      {0, 100000}
    TEST-MACHINE1-D   True      AC    Execution Required power request timeout           4294967295 Seconds                  {0, 4294967295}
    TEST-MACHINE1-D   True      AC    IO coalescing timeout                              0 Milliseconds                      {0, 4294967295}
    TEST-MACHINE1-D   True      AC    Console lock display off timeout                   1800 Seconds                        {0, 4294967295}
    TEST-MACHINE1-D   True      AC    Non-sensor Input Presence Timeout                  240 Seconds                         {0, 4294967295}

    In this example we get all power settings that are on the Active power plan that have "timeout" in their name and associated with AC power type.
.EXAMPLE
    PS C:\> Get-PowerSetting -ComputerName TEST-LAPTOP02-L,TEST-MACHINE1-D -ActivePlanOnly -SettingType AC -SettingName "Console lock display off timeout"

   Plan Name: Balanced

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    TEST-LAPTOP02-L    True      AC    Console lock display off timeout                   60 Seconds                          {0, 4294967295}


    Plan Name: HP Optimized (recommended)

    ComputerName      Active    Type  SettingName                                        SettingValue                        Range
    ------------      ------    ----  -----------                                        ------------                        -----
    TEST-MACHINE1-D   True      AC    Console lock display off timeout                   1800 Seconds                        {0, 4294967295}

    In this example we get the power setting "Console lock display off timeout" from two computers for the active power plan on AC power.
    Here we can see TEST-MACHINE1-D has a 1800 seconds (30 minutes) time out for this second where TEST-LAPTOP02-L has 60 second timeout.
    This setting controls how fast the ocmputer goest to sleep after a user locks there computer. The default of 60 seconds is usually too low.
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
.INPUTS
    [string]
        ComputerName
.OUTPUTS
    [spz.Utility.PowerSetting]
.NOTES
    The default grouping of the output is by plan name. All parameters have built-in tab completion, besides ComputerName.
    The following website was a big help in creating this function.
    https://www.dhb-scripting.com/Forums/posts/t44-Line-Up-Your-Windows-Power-and-Sleep-Settings-with-PowerShell-and-WMI
#>
function Get-PowerSetting {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName = $env:COMPUTERNAME,
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
        [string]$PlanName = "",
        [switch]$ActivePlanOnly,
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
        [ValidateSet("AC","DC")]
        [string]$SettingType
    )

    Process{
        foreach ($computer in $ComputerName){
            try{
                $Session = New-CimConnection -ComputerName $computer -ErrorAction Stop
                $CimParameters = @{
                    CimSession = $Session
                    Namespace = "root\cimv2\power"
                    ErrorAction = "Stop"
                }
                $PlanQuery = "select ElementName,InstanceID,IsActive from Win32_Powerplan WHERE (ElementName LIKE '%$PlanName%' OR InstanceId LIKE '%$PlanName%')"
                if ($ActivePlanOnly){
                    $PlanQuery += " AND IsActive=True"
                }
           
                # Get the Active Power Plan
                Write-Information "Querying win32_PowerPlan - $PlanQuery"
                $CimParameters["Query"] = $PlanQuery
                $PowerPlans = Get-CimInstance @CimParameters

                foreach ($plan in $PowerPlans){
                    # Get Setting Names
                    $SettingNames_Hash = @{}
                    $CimParameters["Query"] = "select ElementName,InstanceID from Win32_PowerSetting"
                    Get-CimInstance @CimParameters | ForEach-Object {
                        $SettingId = $_.InstanceId.Split('\')[-1]
                        $SettingNames_Hash.Add($SettingId,$_)
                    }
                
                    # Change Microsoft:PowerPlan\{381b4222-f694-41f0-9685-ff5bb260df2e} 
                    # to 381b4222-f694-41f0-9685-ff5bb260df2e for the query
                    $PlanId = $plan.InstanceId.Split("\")[-1]
                    $SettingQuery = "select InstanceId,SettingIndexValue from Win32_PowerSettingDataIndex"
                    if ($PSBoundParameters.ContainsKey("SettingType")){
                        $SettingQuery += " WHERE InstanceId LIKE '%$PlanId\\$SettingType\\%'"
                    }
                    else{
                        $SettingQuery += " WHERE InstanceId LIKE '%$PlanId%'"
                    }
                    $CimParameters["Query"] = $SettingQuery
                    $Settings = Get-CimInstance @CimParameters

                    $PossibleValues_Hash = @{}
                    $CimParameters["Query"] = "select * from Win32_PowerSettingDefinitionPossibleValue"
                    Get-CimInstance @CimParameters | Group-Object {$_.InstanceId.split('\')[-2]} | Foreach-Object {
                        $PossibleValues_Hash.Add($_.Name,$_.Group)
                    }

                    $RangeValues_Hash = @{}
                    $CimParameters["Query"] = "select * from Win32_PowerSettingDefinitionRangeData"
                    Get-CimInstance @CimParameters | Group-Object {$_.InstanceId.split('\')[-1]} | Foreach-Object {
                        $RangeValues_Hash.Add($_.Name,$_.Group)
                    }
                
                    foreach ($setting in $Settings) {
                        $settingGUID = Split-Path $setting.InstanceId -Leaf
                        $currentsettingName = $SettingNames_Hash["$SettingGUID"].ElementName
                        if ($PSBoundParameters.ContainsKey("SettingName") -and ($currentsettingName -notlike "$SettingName")){
                            continue
                        }
                        $SettingObj = [PSCustomObject]@{
                            PSTypeName = "SysAdminTools.PowerSetting"
                            ComputerName = $computer.ToUpper()
                            PlanName = $plan.ElementName
                            PlanId = $PlanId
                            Active = $plan.IsActive
                            SettingId = $setting.InstanceId.Split("\")[-1]
                            SettingType = $setting.InstanceId.Split('\')[-2]
                            SettingName = $currentsettingName
                            SettingIndex = $setting.SettingIndexValue
                            SettingBinaryValue = $null
                            SettingValue = $null
                            SettingValueFriendlyName = $null
                            SettingValueDescripter = $null
                            SettingValueType = $null
                            SettingValueRange = [System.Collections.Generic.List[Object]]::new()
                            SettingValueRangeObjects = [System.Collections.Generic.List[Object]]::new()
                        }
                        $possiblevalue = $PossibleValues_Hash["$SettingGUID"]
                        if ($null -ne $possiblevalue){
                            $value = $possiblevalue | Where-Object SettingIndex -eq $setting.SettingIndexValue
                            $SettingObj.SettingValueFriendlyName = $value.ElementName
                            switch ($value){
                                {$null -ne $value.BinaryValue} {$SettingObj.SettingBinaryValue = $value.BinaryValue; $SettingObj.SettingValueDescripter = "Binary"; Break;}
                                {$null -ne $value.UInt32Value} {$SettingObj.SettingValue = $value.UInt32Value; $SettingObj.SettingValueDescripter = "INT"}
                            }
                            $SettingObj.SettingValueRange.AddRange($possiblevalue.ElementName)
                            $SettingObj.SettingValueRangeObjects.AddRange($possiblevalue)
                            $SettingObj.SettingValueType = "Discrete"
                        }
                        else{
                            $rangevalue = $RangeValues_Hash["$SettingGUID"]
                            $min = $rangevalue | Where-Object ElementName -eq "ValueMin"
                            $max = $rangevalue | Where-Object ElementName -eq "ValueMax"
                            $SettingObj.SettingValueDescripter = $rangevalue | Select-Object -First 1 -ExpandProperty Description
                            $SettingObj.SettingValue = $setting.SettingIndexValue
                            $SettingObj.SettingValueFriendlyName = "$($SettingObj.SettingValue) $($SettingObj.SettingValueDescripter)"
                            $SettingObj.SettingValueRange.Add($min.SettingValue)
                            $SettingObj.SettingValueRange.Add($max.SettingValue)
                            $SettingObj.SettingValueType = "Range"
                        }
                        $SettingObj
                    } #foreach Setting
                } #foreach power plan
                $Session | Remove-CimSession -ErrorAction SilentlyContinue
            }
            catch{
                $Session | Remove-CimSession -ErrorAction SilentlyContinue
                if ($_.Exception.Message -like "*HRESULT 0x80070668*"){
                    Write-Error -Message "Access Denied or Unknown Error: HRESULT 0x80070668"
                }
                else{
                    $PSCmdlet.WriteError($_)
                }
            }
        } # foreach
    } #Process
}