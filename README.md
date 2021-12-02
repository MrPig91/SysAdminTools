# SysAdminTools
A repo where I can put all my System Admin Tools that I have built over the years.

# Instructions
Open a powershell as administrator and run the following command:
```Powershell
Install-Module -Repository PSGallery -Name SysAdminTools
```

If you want to update to the latest version, run this command:
```Powershell
Update-Module SysAdminTools
```

If you get and error like the following "The 'Command' command was found in the module 'SysAdminTools', but the module could not be loaded." then you will need to set your Execution Policy to remote signed by running the command below. Please note that execution policy is not a security feature, so changing it will not make your system more or less secure. Execution Policy is used to prevent you from accidentally running scripts that goes aganist the policy, but it does not prevent those scripts being ran in bypass mode. You can read more about Execution Policy on its about page [here](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.1)
```Powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
```
