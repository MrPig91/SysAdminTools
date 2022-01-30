<#
.SYNOPSIS
    This will grab all user profiles found on a local or remote computer (by default it ignores special profiles).
.DESCRIPTION
    This will grab all user profiles found on a local or remote computer (by default it ignores special profiles). It will resolve the SID to find the
    user account associated with the profile (whether local account or domain account). You can use StaleUsersOnly to only grab accounts that are no longer part of the domain.
.EXAMPLE
    PS C:\> Get-UserProfile

    ComputerName    ProfileName             AccountName             DomainName      Special Loaded LastUseTime
    ------------    -----------             -----------             ----------      ------- ------ -----------
    DESKTOP-RFR3S01 Syrius Cleveland        Syrius Cleveland        DESKTOP-RFR3S01 False   True   9/23/2021 10:18:40 PM


    This grabs all user profiles on the local computer and displays the most important information in a table.
.EXAMPLE
    Get-UserProfile -ComputerName Test01v -StaleUsersOnly

    ComputerName    ProfileName   AccountName DomainName Special Loaded LastUseTime
    ------------    -----------   ----------- ---------- ------- ------ -----------
    Test01v         testuser                            False    False  8/20/2021 11:23:48 AM


    This grabs only the user profiles that have AccountName and DomainName that equal an empty string on the computer Test01v
.EXAMPLE
    Get-UserProfile -ComputerName Test01v -StaleUsersOnly | Remove-UserProfile
    User profile [C:\Users\testuser] has been successfully removed from computer [Test01v]


    This grabs only the user profiles that have AccountName and DomainName that equal an empty string on the computer
    Test01v and pipes the results to Remove-UserProfile command which then deletes this user's profile (folder and hive registry).
.INPUTS
    [string[]]$ComputerName
.OUTPUTS
    spz.Utility.UserProfile
.NOTES
    Requires Admin if ran aganist a remote computer
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Get%E2%80%90UserProfile
#>
function Get-UserProfile {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [Alias("CN","MachineName")]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [switch]$IncludeSpecialAccounts,
        [switch]$StaleUsersOnly
    )

    Begin {
        $cimParamerters = @{
            ClassName = "Win32_UserProfile"
        }
        if (-not$IncludeSpecialAccounts.IsPresent){
            $cimParamerters["Filter"] = "Special=false"
        }
    }

    Process{
        foreach ($computer in $ComputerName){
            try{
                Write-Information "Creating Cim Session for computer [$computer]"
                $cimSession = New-CimConnection -ComputerName $computer -ErrorAction Stop
                $cimParamerters["CimSession"] = $cimSession
                $UserProfiles = Get-CimInstance @cimParamerters
                foreach ($profile in $UserProfiles){
                    try{
                        $ResolvedSID = Resolve-SId -SID $profile.SID -ComputerName $computer -ErrorAction Stop
                    }
                    catch{
                        $ResolvedSID = $null
                        Write-Warning "Unable to resolve SID [$($profle.SID)] on computer [$computer]"
                    }
                    $userProfile = [PSCustomObject]@{
                        PSTypeName = "SysAdminTools.UserProfile"
                        ComputerName = $computer
                        LocalPath = $profile.LocalPath
                        ProfileName = ($profile.LocalPath -split '\\' | Select-Object -Last 1)
                        SID = $profile.SID
                        Loaded = $profile.loaded
                        Special = $profile.special
                        LastUseTime = $profile.LastUseTime
                        AccountName = $ResolvedSID.AccountName
                        DomainName = $ResolvedSID.ReferencedDomainName
                    }
                    if ($StaleUsersOnly){
                        if ($UserProfile.AccountName -eq "" -and $UserProfile.DomainName -eq ""){
                            $userProfile
                        }
                    }
                    else{
                        $userProfile
                    }
                }
                $cimSession | Remove-CimSession
            }
            catch{
                $PSCmdlet.WriteError($_)
            } #try/catch
        } #foreach
    } #process
}