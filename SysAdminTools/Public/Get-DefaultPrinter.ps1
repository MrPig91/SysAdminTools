<#
.SYNOPSIS
    Gets the default printer of a remote machine.
.DESCRIPTION
    Gets the default printer of a remote machine of a specfifc user, including Shared Server Printers.
.EXAMPLE
    PS C:\> Get-DefaultPrinter -ComputerName Client01v

    PrintServer PrinterName UserName
    ----------- ----------- --------
    Local       Adobe PDF   Mr.Pigs91

    This example gets the default printer of the only logged in user on Client01v.
.INPUTS
    String
.OUTPUTS
    PsCustomObject
.NOTES
    None
#>
function Get-DefaultPrinter{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]$ComputerName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$SamAccountName,
        [switch]$AllUsers
    )
    try{
        if (Test-Connection -ComputerName $Computername -Quiet -Count 1){
            $RemoteRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users',$ComputerName)
            $CurrentUsers = $RemoteRegistry.GetSubKeyNames() | foreach {if ($_.length -eq 46){ Get-ADUser -Filter {sid -eq $_}}}
            if ($PSBoundParameters.ContainsKey("SamAccountname")){
                if ($CurrentUsers.SamAccountname -contains $SamAccountName){
                    $ChosenUsers = ($CurrentUsers | where SamAccountname -eq $SamAccountName).SID.Value
                }
                else{
                        Write-Warning "$SamAccountName was not found logged into $ComputerName. Finding other logged in Users"
                        Get-DefaultPrinter -ComputerName $ComputerName
                }
            }
            elseif (($CurrentUsers | Measure).Count -eq 1){
                $ChosenUsers = $CurrentUsers.SID.Value
            }
            elseif (!($AllUsers)){
                    $i = 0
                    [System.Collections.ArrayList]$options = @{}
                    foreach ($user in $CurrentUsers){
                        $options += [System.Management.Automation.Host.ChoiceDescription]::new("&$i - $($user.SamAccountname)",$user.SID.Value)
                        $i++
                    }

                    $result = $host.UI.PromptForChoice("Current Users","Please Chose a User",$options[0..($options.Count -1)],0)
                    $ChosenUsers = $options[$result].HelpMessage
            }
            else{
                $ChosenUsers = $CurrentUsers | foreach {$_.SID.Value}
            }
            if ($ChosenUsers){
                foreach ($ChosenUser in $ChosenUsers){
                    $ChosenUserName = ($CurrentUsers | where {$_.SID.Value -eq $ChosenUser}).SamAccountname
                    $DevicesCheck = $RemoteRegistry.OpenSubKey("$ChosenUser\Software\Microsoft\Windows NT\CurrentVersion\Windows")
                    if ($DevicesCheck.GetValueNames() -contains "Device"){
                        $Printer = $DevicesCheck.GetValue("Device")
                        if ($Printer.StartsWith('\\')){
                            $PrinterPath = $printer.Split(",")[0]
                            $ServerandPrinter = $PrinterPath.Split('\',[System.StringSplitOptions]::RemoveEmptyEntries)
                            [PSCustomObject]@{
                                PrintServer = $ServerandPrinter[0]
                                PrinterName = $ServerandPrinter[1]
                                UserName = $ChosenUserName
                            }
                        }
                        else{
                            $PrinterPath = $printer.Split(",")[0]
                            [PSCustomObject]@{
                                PrintServer = "Local"
                                PrinterName = $PrinterPath
                                UserName = $ChosenUserName
                            }
                        }
                    }
                }
            }
            else{
                if (!($PSBoundParameters.ContainsKey("SamAccountName"))){
                    Write-Warning "No users are logged into $ComputerName"
                }
            }
        }
        else{
            Write-Warning "$ComputerName is offline or is unreachable."
        }
    }
    catch{
        Write-Host "An Error Has Occured, $($_.Exception)"
    }
}