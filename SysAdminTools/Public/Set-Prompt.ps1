<#
.SYNOPSIS
    This function will set the Powershell prompt with some predefined functions like the CPU/Mem, Random Command, etc.
.DESCRIPTION
    This function uses the "function Prompt {}" function to set the powershell prompt with a new function. You can add a prefix to your main prompt display,
    change the color of the foreground or background.
.EXAMPLE
    PS C:\> Set-Prompt -Name CPU_Memory -Prefix Admin -ForegroundColor Red -BackGroundColor Blue
    [Non-Admin]CPU: 100% | Mem: 37%:\>
    
    Tthis function sets the prompt to display the current CPU and memory usage. Also lets you know if the user is an admin or not. Also changed the color of the prompt.
.EXAMPLE
    PS C:\>Set-Prompt -Name Measure_Command -Prefix Error_Count,Admin -ForegroundColor Red -BackGroundColor Green
    [7][Non-Admin]0 milliseconds:\> 1.. 100  | foreach {Get-CimInstance -ClassName Win32_Process | where name -eq "Explorer.exe"} | Out-Null
    [7][Non-Admin]4.18 seconds:\> 1.. 100  | foreach {Get-CimInstance -ClassName Win32_Process -Filter "Name='Explorer.exe'"} | Out-Null
    [7][Non-Admin]3.05 seconds:\>

    This example sets the prompt to show the amount of time it took the last command to run and displays the number of errors as a prefix. Here you can see
    that filtering with the Filter paramter of Get-CimInstance is faster than filtering on the left. Always filter left when possible. This particular prompt is useful
    when creating new functions and trying to optmize them.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    The CPU_Memory prompt does create a job that runs in the background to grab the most current reading of the CPU usage. This job is removed whenver a new prompt is set.
    Three global variables are created with the use of this function prompt_FGColor,prompt_BGColor, and Prompt_Prefixblock. These are necessary to be in the global scope
    so that the prompt function can read them. 
#>
function Set-Prompt{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("Random_Cmdlet","Time-short","Time-long","Date-Time","Random_Fact","Measure_Command","CPU_Memory","System_Uptime")]
        [string]$Name,

        [ValidateSet("Admin","Time","Error_Count","Debug")]
        [string[]]$Prefix,

        [ConsoleColor]$ForegroundColor = $host.UI.RawUI.ForegroundColor,

        [ConsoleColor]$BackGroundColor = $host.UI.RawUI.BackgroundColor
    )

    New-Variable -Name prompt_FGColor -Value $ForegroundColor -Scope Global -Force
    New-Variable -Name prompt_BGColor -Value $BackGroundColor -Scope Global -Force
    New-Variable -Name Prompt_Prefixblock -Value $null -Scope Global -Force

    if (Get-Job -Name CPU_Mem_Prompt -ErrorAction SilentlyContinue){
        Remove-Job -Name CPU_Mem_Prompt -Force
    }

    $Global:Prompt_Prefixblock = foreach ($Pre in $Prefix){
        switch ($Pre){
            "Admin" {{
                        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                        $principal = [Security.Principal.WindowsPrincipal] $identity
                        $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
            
                        if ($principal.IsInRole($adminRole)){
                           "[Admin]"
                        }
                        else{
                            "[Non-Admin]"
                    }
                }}
    
            "Time" {{
                "[$((Get-Date).ToShortTimeString())]"
            }}
    
            "Error_Count" {{
                "[$($Error.Count)]"
            }}

            "Debug" {{
                if (Test-Path variable:/PSDebugContext) {'[DBG]'}
            }}
        }
    }

    switch ($Name) {
        "Random_Cmdlet" {
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$((Get-Command -Verb ((Get-Verb).Verb | Get-Random) | Get-Random).name):\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }
        "Time-short" {
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$((Get-Date).ToShortTimeString()):\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }
        "Time-long" {
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$((Get-Date).ToLongTimeString()):\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }

        }
        "Date-Time"{
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$((Get-Date).ToString()):\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }
        "Random_Fact" {
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$((Invoke-RestMethod -Method Get -Uri 'https://uselessfacts.jsph.pl/random.json?language=en').Text)`nPS :\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }
        "Measure_Command" {
            function global:prompt {
                $lastcommand = Get-History | select -Last 1
                $timespan = New-TimeSpan -Start $lastcommand.StartExecutionTime -End $lastcommand.EndExecutionTime

                if ($timespan.Minutes -lt 1){
                    if ($timespan.Seconds -lt 1){
                        Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalMilliseconds,2)) milliseconds:\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                        return " "
                    }
                    Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalSeconds,2)) seconds:\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                    return " "
                }
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalMinutes,2)) minutes:\>"
                return " "
            }
        }
        "CPU_Memory" {

            Start-Job -Name CPU_Mem_Prompt -ScriptBlock {
                get-counter -Counter "\processor(_total)\% processor time","\memory\% committed bytes in use" -Continuous |
                    foreach {"CPU: $([math]::Round($_.CounterSamples.cookedvalue[0]))% | Mem: $([math]::Round($_.CounterSamples.cookedvalue[1]))%:\>"}
            }  | Out-Null

            function global:prompt {
                $jobresults = Receive-Job CPU_Mem_Prompt | select -First 1
                if ($jobresults){
                    Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$jobresults" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                    return " "
                }
                $results = get-counter -Counter "\processor(_total)\% processor time","\memory\% committed bytes in use" |
                foreach {"$(($Prompt_Prefixblock | foreach {&$_}) -join '')CPU: $([math]::Round($_.CounterSamples.cookedvalue[0]))% | Mem: $([math]::Round($_.CounterSamples.cookedvalue[1]))%:\>"}

                Write-Host $results -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }

        "System_Uptime" {
            function global:prompt {
                $Lastboot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
                $timespan = New-TimeSpan -Start $Lastboot -End (Get-Date)

                if ($timespan.TotalDays -lt 0){
                    if ($timespan.TotalHours -lt 0){
                        Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalMinutes,2)) minutes:\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                        return " "
                    }
                    Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalHours,2)) hours:\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                    return " "
                }
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')$([math]::round($timespan.TotalDays,2)) days:\>" -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }

        default {
            function global:prompt {
                Write-Host "$(($Prompt_Prefixblock | foreach {&$_}) -join '')PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " -ForegroundColor $prompt_FGColor -BackgroundColor $prompt_BGColor -NoNewline
                return " "
            }
        }
    }
}