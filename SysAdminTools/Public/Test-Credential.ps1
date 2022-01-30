<#
.SYNOPSIS
    Verifies that a given credential is valid or invalid.
.DESCRIPTION
    Will test a given username with a given password and return either true or false.
    True if the credentials provided are valid and false if they are not.
.PARAMETER UserName
    The username you want to test the credentials for. Accpets pipeline input.
.PARAMETER Password
    The password you want to test with the UserName that was provided. Requires a secure string to be inputted. 
.EXAMPLE
    PS C:\> Test-Credential -Credential "MrPig"
    True

    This example shows you can enter in just a username and it will prompt for the password, it return "True" which indicates that the credentials are valid.
.EXAMPLE
    PS C:\> Test-Credential
    cmdlet Test-Credential at command pipeline position 1
    Supply values for the following parameters:
    Credential
    False

    If you do not enter in any parameters it will prompt for Credentials.
    Since credentials enter in this example were not valid it return a false boolean value.
.EXAMPLE
    PS C:\> Test-Credential -UserName syrius.cleveland -Password (Read-Host -AsSecureString)
    ***********
    False

    This example uses the Read-Host -AsSecureString command to provide the value for the password and filles our the UserName parameter beforehand.
    Since credentials enter in this example were not valid it return a false boolean value.
.INPUTS
    None
.OUTPUTS
    Boolean
.NOTES
    Requires secure string for password. I made the Output just a simple boolean value since the rest of the cmdlets that have test as the verb do the same.
.LINK
    https://github.com/MrPig91/SysAdminTools/wiki/Test%E2%80%90Credential
#>
function Test-Credential{
    [Cmdletbinding(DefaultParameterSetName = "Credentials")]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="Credentials")]
        [pscredential]$Credential,

        [Parameter(ParameterSetName="IsAdmin")]
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
        ParameterSetName="UserNameandPassword")]
        [String]$UserName = $ENV:USERNAME,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,
        ParameterSetName="UserNameandPassword")]
        [securestring]$Password,

        [Parameter(ParameterSetName="IsAdmin")]
        [switch]$IsAdmin
    )

    Begin{
        Write-Information "Adding System.DirectoryServices.AccountManagement assembly" -Tags "Begin"
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        Write-Information "Checking to see if computer is part of a domain using Get-CimInstance" -Tags "Process"
        $PartofDomain = (Get-CimInstance -ClassName Win32_ComputerSystem).PartOfDomain

        if ($PartofDomain){
            $ContextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
        }
        else{
            $ContextType = [System.DirectoryServices.AccountManagement.ContextType]::Machine
        }
    }

    Process{
        try{
            $Previous = $ErrorActionPreference
            $ErrorActionPreference = "Stop"
            if ($IsAdmin){
                if ($PartofDomain){
                    $Identity = [System.Security.Principal.WindowsIdentity]::new($UserName)
                    $WinPrincipal = [Security.Principal.WindowsPrincipal]::new($Identity)
                    $Admin = $WinPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
                    Write-Information "Username $Username is admin: $Admin"
                    
                    return $Admin
                }
                else{
                    $Admingroupmember = (Get-LocalGroupMember -Name Administrators).Name | foreach {$_.Split('\',2)[1]}
                    $Admin = ($Admingroupmember -contains $UserName.Split('\',2)[0])
                    return $Admin
                }
            }

            if ($PSCmdlet.ParameterSetName -eq "UserNameAndPassword"){
                $Credential = [System.Management.Automation.PSCredential]::new($UserName,$Password)
            }
            
            $PrincipalContext = [System.DirectoryServices.AccountManagement.PrincipalContext]::new($ContextType)
    
            Write-Information "Validating Credentials" -Tags "Process"
            $ValidatedCreds = $PrincipalContext.ValidateCredentials($Credential.UserName,$Credential.GetNetworkCredential().Password)
            Write-Information "Username $($Credential.UserName) with provided password resulted in: $ValidatedCreds" -Tags "Process"
            $ErrorActionPreference = $Previous
            return $ValidatedCreds
        }
        catch{
            $ErrorActionPreference = $Previous
            $PSCmdlet.WriteError($_)
        }
    } #Process
}