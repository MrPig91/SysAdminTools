function Resolve-SID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SID,
        
        [Parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    Process {
        $params=@{
            ErrorAction="Stop"
            ResourceURI="wmicimv2/win32_SID"
            SelectorSet=@{SID="$SID"}
            Computername=$Computername
        }
        try {
            Get-WSManInstance @params
        }
        catch{
            try{
                Write-Information "Failed to resolve SID using WSMan, switching to WMI"
                [wmi]"\\$ComputerName\root\cimv2:win32_sid.sid='$SID'"
            }
            catch{
                Write-Information "Failed to resolve SID using WSMan and WMI, throwing an error"
                throw $_
            }
        }
    }
}