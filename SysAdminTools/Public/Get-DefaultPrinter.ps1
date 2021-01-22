<#
.SYNOPSIS
    Gets the default printer of a remote machine.
.DESCRIPTION
    Gets the default printer of a remote machine of a specfifc user, including Shared Server Printers.
.PARAMETER ComputerName
    Use this paramter to specify the computer(s) you want to run the command aganist using its name or IPAddress.
.PARAMETER SamAccountName
    This paramter allows you to only grab the default printers of the specifed user(s). This value is evaluated against the leaf of the localpath from Win32_UserProfile class
.PARAMETER Quiet
    This parameter prevents errors being generated if the computer is unreachable
.EXAMPLE
    PS C:\> Get-DefaultPrinter -ComputerName Client01v

    PrintServer PrinterName UserName ComputerName
    ----------- ----------- -------- ------------
    Local       OneNote     pwsh.cc  Client01v

    This example gets the default printer of the only logged in user on Client01v.
.EXAMPLE
    PS C:\>Get-DefaultPrinter -ComputerName Client01v,dc01v

    PrintServer PrinterName            UserName      ComputerName
    ----------- -----------            --------      ------------
    Local       OneNote                pwsh.cc       Client01v
    Local       Microsoft Print to PDF Administrator dc01v


    PS C:\> Get-DefaultPrinter -ComputerName Client01v,dc01v -SamAccountName pwsh.cc

    PrintServer PrinterName UserName ComputerName
    ----------- ----------- -------- ------------
    Local       OneNote     pwsh.cc  Client01v

    In this example it shows how the SamAccountName parameter works by only grabbing default users specified. Only pwsh.cc was returned by the second command even though the current user Administrator had a default printer on dc01v.
.EXAMPLE
    PS C:\>Test-Connection -ComputerName client01v -Count 1 -Quiet
    False
    PS C:\Users\Administrator> Get-DefaultPrinter -ComputerName Client01v,dc01v -Quiet

    PrintServer PrinterName            UserName      ComputerName
    ----------- -----------            --------      ------------
    Local       Microsoft Print to PDF Administrator dc01v

    In this example we can see how the quiet paramter works, by omitting errors of computers that are unreachable such as Client01v.
.INPUTS
    String
.OUTPUTS
    PsCustomObject
        SysAdminTool.DefaultPrinter
.NOTES
    Uses WsMan Protocol as default and fallsback to DCOM. Grabs default printer from registry using StdRegProv wmi class in the root\default namespace
#>
function Get-DefaultPrinter{
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("CN","Name","MachineName","IPAddress")]
        [string[]]$ComputerName = $ENV:COMPUTERNAME,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("UserName")]
        [string[]]$SamAccountName,

        [switch]$Quiet
    )

    Begin{
        #Keys to use to reference each regsitry hive, only need HKEY_Users, the other are left for future reference
        #$HKEY_CLASSES_ROOT = 2147483648
        #$HKEY_CURRENT_USER = 2147483649
        #$HKEY_LOCAL_MACHINE = 2147483650
        $HKEY_USERS = 2147483651
        #$HKEY_CURRENT_CONFIG = [Convert]::ToUInt32(2147483653)
    }

    Process{
        foreach ($computer in $ComputerName){
            if (Test-Connection -ComputerName $Computer -Quiet -Count 1){
                try{
                    Write-Information "Test connection to computer $computer successful, creating Cim Session and grabbing win32_UserProfile" -Tags "Process"
                    try{
                        $session = New-CimSession -ComputerName $computer -OperationTimeoutSec 1 -ErrorAction Stop
                    }
                    catch{
                        Write-Information "Unable to create Cim Session using WsMan, creating fallback session using DCOM"
                        $CimSessionOption = New-CimSessionOption -Protocol Dcom
                        $session = New-CimSession -ComputerName $computer -SessionOption $CimSessionOption -OperationTimeoutSec 1
                    }
                    $AllUserProfiles = Get-CimInstance -ClassName Win32_UserProfile -CimSession $session -Filter "SPECIAL=$false"
                    $RemoteRegistry = Get-CimClass -Namespace "root\default" -ClassName StdRegProv -CimSession $session

                    $currentUsersReg = ($RemoteRegistry | Invoke-CimMethod -Name "EnumKey" -Arguments @{hDefKey=$HKEY_USERS;sSubKeyName = ""} -CimSession $session).sNames

                    $currentUsers = $AllUserProfiles | where SID -in $currentUsersReg 

                    foreach ($user in $currentUsers){
                        $SID = $user.SID
                        $UserName = Split-Path $user.LocalPath -Leaf
                        if ($PSBoundParameters.ContainsKey("SamAccountName") -and ($UserName -notin $SamAccountName)){
                            Write-Information "SamAccountName parameter was used, and the user $UserName was not found as a current user on $computer" -Tags "Process"
                            continue
                        }

                        Write-Information "Attempting to grab default printer for user $UserName" -Tags "Process"
                        $Printer = ($RemoteRegistry | Invoke-CimMethod -MethodName GetStringValue -Arguments @{hDefKey=$HKEY_USERS;sSubKeyName = "$SID\Software\Microsoft\Windows NT\CurrentVersion\Windows";sValueName = "Device"} -CimSession $session).sValue

                        if ($Printer){
                            Write-Information "A default printer was found for user $UserName, creating output object" -Tags "Process"
                            if ($Printer.StartsWith('\\')){
                                $PrinterPath = $printer.Split(",")[0]
                                $ServerandPrinter = $PrinterPath.Split('\',[System.StringSplitOptions]::RemoveEmptyEntries)
                                [PSCustomObject]@{
                                    PSTypeName = "SysAdminTools.DefaultPrinter"
                                    PrintServer = $ServerandPrinter[0]
                                    PrinterName = $ServerandPrinter[1]
                                    UserName = $UserName
                                    ComputerName = $computer
                                }
                            }
                            else{
                                $PrinterPath = $printer.Split(",")[0]
                                [PSCustomObject]@{
                                    PSTypeName = "SysAdminTools.DefaultPrinter"
                                    PrintServer = "Local"
                                    PrinterName = $PrinterPath
                                    UserName = $UserName
                                    ComputerName = $computer
                                }
                            }
                        } #if
                        else{
                            Write-Information "No default printer was found for user $Username" -Tags "Process"
                        }
                    } #foreach user
                    $session | Remove-CimSession
                } #try
                catch [System.Runtime.InteropServices.COMException]{
                    Write-Warning "WMI query failed on $computer. Ensure 'Windows Management Instrumentation (WMI-In)' firewall rule is enabled."
                    $PSCmdlet.WriteError($_)
                }
                catch{
                    Write-Warning "An uncaught execption has occurred please open an issue at https://github.com/MrPig91/SysAdminTools/issues"
                    $PSCmdlet.WriteError($_)
                }
            } #if connection
            else{
                if ($Quiet){
                    Write-Information "The quiet switch was used, skipping the connection fail error for $computer" -Tags "Process"
                }
                else{
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Net.NetworkInformation.PingException]::new("$computer is unreachable"),
                        'TestConnectionException',
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $computer
                    )
                    $PSCmdlet.WriteError($ErrorRecord)
                }
            }
        } #foreach computer
    } #Process
}