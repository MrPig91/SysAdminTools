function New-CimConnection {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [Parameter()]
        [ValidateSet("WsMan", "Dcom")]
        [string]$Protocol = "WsMan"
    )

    $CimSessionOption = New-CimSessionOption -Protocol $Protocol

    Try{
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption $CimSessionOption -OperationTimeoutSec 1 -ErrorAction Stop
    }
    catch{
        try{
            switch ($Protocol){
                "WsMan" {$CimSessionOption = New-CimSessionOption -Protocol "Dcom"; $Backup = "Dcom"}
                "Dcom" {$CimSessionOption = New-CimSessionOption -Protocol "WsMan"; $Backup = "WsMan"}
            }
            $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption $CimSessionOption -OperationTimeoutSec 1 -ErrorAction Stop
            Write-Warning "Unable to connect to $ComputerName with $Protocol, using $Backup protocol instead! Try using setting the Protocol parameter to $Backup for faster execution time."
        }
        catch{
            $PSCmdlet.WriteError($_)
        }   
    }

    $CimSession
}