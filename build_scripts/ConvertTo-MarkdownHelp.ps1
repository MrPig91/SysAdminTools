function ConvertTo-MarkdownHelp {
# found this script to use for creating markdown
#link https://gist.github.com/urasandesu/51e7d31b9fa3e53489a7

# 
# File: Get-HelpByMarkdown.ps1
# 
# Author: Akira Sugiura (urasandesu@gmail.com)
# 
# 
# Copyright (c) 2014 Akira Sugiura
#  
#  This software is MIT License.
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

<#
    .SYNOPSIS
        Gets the comment-based help and converts to GitHub Flavored Markdown.
    .PARAMETER  Name
        A command name to get comment-based help.
    .EXAMPLE
        & .\Get-HelpByMarkdown.ps1 Select-Object > .\Select-Object.md
        
        DESCRIPTION
        -----------
        This example gets comment-based help of `Select-Object` command, and converts GitHub Flavored Markdown format, then saves it to `Select-Object.md` in current directory.
    .INPUTS
        System.String
    .OUTPUTS
        System.String
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    $Name
)

function EncodePartOfHtml {
    param (
        [string]
        $Value
    )

    ($Value -replace '<', '&lt;') -replace '>', '&gt;'
}

try {

    $full = Get-Help $Name -Full

$mdHelp = @"
# $($full.Name)
## SYNOPSIS
$($full.Synopsis)
## SYNTAX
``````powershell
$((($full.syntax | Out-String) -replace "`r`n", "`r`n`r`n").Trim())
``````
## DESCRIPTION
$(($full.description | Out-String).Trim())
## PARAMETERS`n
"@ + $(foreach ($parameter in $full.parameters.parameter) {
@"
### -$($parameter.name) &lt;$($parameter.type.name)&gt;
$(($parameter.description | Out-String).Trim())
``````
$(((($parameter | Out-String).Trim() -split "`r`n")[-5..-1] | % { $_.Trim() }) -join "`r`n")
```````n
"@
}) + @"
## INPUTS
$($full.inputTypes.inputType.type.name)
## OUTPUTS
$($full.returnValues.returnValue[0].type.name)
## NOTES
$(($full.alertSet.alert | Out-String).Trim())
## EXAMPLES`n
"@ + $(foreach ($example in $full.examples.example) {
@"
### $(($example.title -replace '-*', '').Trim())
``````powershell
$(($example.introduction.text,$example.code -JOIN " "),($example.remarks | out-string).Trim() -join "`n`n")
``````

"@
}) + @"
"@

    $mdHelp
    } #try
    catch{

    } #catch
}
