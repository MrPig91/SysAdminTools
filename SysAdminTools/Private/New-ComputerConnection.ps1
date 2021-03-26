function New-CimConnection {
    [CmdletBinding()]
    param(
        [string]$ComputerName
    )

        Try{
            $CimSession = New-CimSession -ComputerName $ComputerName -OperationTimeoutSec 1 -ErrorAction Stop
        }
        catch{
            try{
                Write-Information "Unable to connect to $ComputerName with Wsman, using DCOM protocl instead" -Tags 'Connection'
                $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption (New-CimSessionOption -Protocol Dcom) -OperationTimeoutSec 1 -ErrorAction Stop
            }
            catch{
                $PSCmdlet.WriteError($_)
            }   
        }
        $CimSession
}