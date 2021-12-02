function Get-LogonFailureReason {
    param($EventRecord)
    # modified this function from "https://www.powershellgallery.com/packages/PoShEvents/0.4.1/Content/Public%5CGet-LogonFailureEvent.ps1"
    $Reason = $null
    $Status = $null
    $SubStatus = $null
    switch ($EventRecord.FailureReason) {
        "%%2305" { $Reason = 'The specified user account has expired.' }
        "%%2309" { $Reason = "The specified account's password has expired." }
        "%%2310" { $Reason = 'Account currently disabled.' }
        "%%2311" { $Reason = 'Account logon time restriction violation.' }
        "%%2312" { $Reason = 'User not allowed to logon at this computer.' }
        "%%2313" { $Reason = 'Unknown user name or bad password.' }
        "%%2304" { $Reason = 'An Error occurred during Logon.' }
    }
    if ($EventRecord.Id -eq 4625) {
        switch ($EventRecord.Status) {
            "0xC0000234" { $Status = "Account locked out" }
            "0xC0000193" { $Status = "Account expired" }
            "0xC0000133" { $Status = "Clocks out of sync" }
            "0xC0000224" { $Status = "Password change required" }
            "0xc000015b" { $Status = "User does not have logon right" }
            "0xc000006d" { $Status = "Logon failure" }
            "0xc000006e" { $Status = "Account restriction" }
            "0xc00002ee" { $Status = "An error occurred during logon" }
            "0xC0000071" { $Status = "Password expired" }
            "0xC0000072" { $Status = "Account disabled" }
            "0xC0000413" { $Status = "Authentication firewall prohibits logon" }
            default { $Status = $Event.Status }
        }
        if ($EventRecord.Status -ne $EventRecord.SubStatus) {
            switch ($EventRecord.SubStatus) {
                "0xC0000234" { $SubStatus = "Account locked out" }
                "0xC0000193" { $SubStatus = "Account expired" }
                "0xC0000133" { $SubStatus = "Clocks out of sync" }
                "0xC0000224" { $SubStatus = "Password change required" }
                "0xc000015b" { $SubStatus = "User does not have logon right" }
                "0xc000006d" { $SubStatus = "Logon failure" }
                "0xc000006e" { $SubStatus = "Account restriction" }
                "0xc00002ee" { $SubStatus = "An error occurred during logon" }
                "0xC0000071" { $SubStatus = "Password expired" }
                "0xC0000072" { $SubStatus = "Account disabled" }
                "0xc000006a" { $SubStatus = "Incorrect password" }
                "0xc0000064" { $SubStatus = "Account does not exist" }
                "0xC0000413" { $SubStatus = "Authentication firewall prohibits logon" }
                default { $SubStatus = $EventRecord.SubStatus }
            }
        }
    } elseif ($EventRecord.Id -eq 4771)  {
        switch ($EventRecord.Status) {
            "0x1" { $Status = "Client's entry in database has expired" }
            "0x2" { $Status = "Server's entry in database has expired" }
            "0x3" { $Status = "Requested protocol version # not supported" }
            "0x4" { $Status = "Client's key encrypted in old master key" }
            "0x5" { $Status = "Server's key encrypted in old master key" }
            "0x6" { $Status = "Client not found in Kerberos database" }    #Bad user name, or new computer/user account has not replicated to DC yet
            "0x7" { $Status = "Server not found in Kerberos database" } # New computer account has not replicated yet or computer is pre-w2k
            "0x8" { $Status = "Multiple principal entries in database" }
            "0x9" { $Status = "The client or server has a null key" } # administrator should reset the password on the account
            "0xA" { $Status = "Ticket not eligible for postdating" }
            "0xB" { $Status = "Requested start time is later than end time" }
            "0xC" { $Status = "KDC policy rejects request" } # Workstation restriction
            "0xD" { $Status = "KDC cannot accommodate requested option" }
            "0xE" { $Status = "KDC has no support for encryption type" }
            "0xF" { $Status = "KDC has no support for checksum type" }
            "0x10" { $Status = "KDC has no support for padata type" }
            "0x11" { $Status = "KDC has no support for transited type" }
            "0x12" { $Status = "Clients credentials have been revoked" } # Account disabled, expired, locked out, logon hours.
            "0x13" { $Status = "Credentials for server have been revoked" }
            "0x14" { $Status = "TGT has been revoked" }
            "0x15" { $Status = "Client not yet valid - try again later" }
            "0x16" { $Status = "Server not yet valid - try again later" }
            "0x17" { $Status = "Password has expired" } # The user’s password has expired.
            "0x18" { $Status = "Pre-authentication information was invalid" } # Usually means bad password
            "0x19" { $Status = "Additional pre-authentication required*" }
            "0x1F" { $Status = "Integrity check on decrypted field failed" }
            "0x20" { $Status = "Ticket expired" } #Frequently logged by computer accounts
            "0x21" { $Status = "Ticket not yet valid" }
            "0x21" { $Status = "Ticket not yet valid" }
            "0x22" { $Status = "Request is a replay" }
            "0x23" { $Status = "The ticket isn't for us" }
            "0x24" { $Status = "Ticket and authenticator don't match" }
            "0x25" { $Status = "Clock skew too great" } # Workstation’s clock too far out of sync with the DC’s
            "0x26" { $Status = "Incorrect net address" } # IP address change?
            "0x27" { $Status = "Protocol version mismatch" }
            "0x28" { $Status = "Invalid msg type" }
            "0x29" { $Status = "Message stream modified" }
            "0x2A" { $Status = "Message out of order" }
            "0x2C" { $Status = "Specified version of key is not available" }
            "0x2D" { $Status = "Service key not available" }
            "0x2E" { $Status = "Mutual authentication failed" } # may be a memory allocation failure
            "0x2F" { $Status = "Incorrect message direction" }
            "0x30" { $Status = "Alternative authentication method required*" }
            "0x31" { $Status = "Incorrect sequence number in message" }
            "0x32" { $Status = "Inappropriate type of checksum in message" }
            "0x3C" { $Status = "Generic error (description in e-text)" }
            "0x3D" { $Status = "Field is too long for this implementation" }
            default { $Status = $EventRecord.Status }
        }
    }
    [PSCustomObject]@{
        Reason = $Reason
        Status = $Status
        SubStatus = $SubStatus
    }
}