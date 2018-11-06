Get-Module AutoTaskEndpointManagement | Remove-Module -ErrorAction SilentlyContinue
Import-Module $PSScriptRoot\..\bin\$(Get-ChildItem -Path $PSScriptRoot\..\bin | Select-Object -Last 1)\AutoTaskEndpointManagement\AutoTaskEndpointManagement.psd1
. $PSScriptRoot\helpertest.ps1

Describe 'Testing functions for use of -UseBasicParsing' {
    $functions = Get-Command -Module AutoTaskEndpointManagement | Select-Object -ExpandProperty Name
    foreach ($function in $functions) {
        It "$function has the same count of Invoke-WebRequest as -UseBasicParsing" {
            $functioncode = Get-Content Function:\$function
            $functioncode = Remove-CommentsAndWhiteSpace -Scriptblock $functioncode
            $CountInvoke = ([regex]::Matches($functioncode,"Invoke-WebRequest")).count
            $CountUseBasic = ([regex]::Matches($functioncode,"-UseBasicParsing")).count
            ($CountInvoke) -eq ($CountUseBasic) | Should -be $true
        }
    }
}