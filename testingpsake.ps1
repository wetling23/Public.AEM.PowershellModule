Properties {
    $repoPath = "C:\codeRepository\Public.AEM.PowershellModule"
    $manifest = Import-PowerShellDataFile -Path $repoPath\AutoTaskEndpointManagement.psd1
    $outputPath = "$repoPath\bin\$($manifest.ModuleVersion)\AutoTaskEndpointManagement"
    $srcPsd1 = "$repoPath\AutoTaskEndpointManagement.psd1"
    $outPsd1 = "$outputPath\AutoTaskEndpointManagement.psd1"
    $outPsm1 = "$outputPath\AutoTaskEndpointManagement.psm1"
}

task default -depends Build, Zip

task Clean {
    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -Path $outputPath -Recurse -Force
    }
}

Task Build -depends Clean {
    Write-Verbose "Creating module version [$($manifest.ModuleVersion)]"
    New-Item -Path $outputPath -ItemType Directory > $null

    # Private functions
    Get-ChildItem -Path "$repoPath\Private" -File | ForEach-Object {
        $_ | Get-Content |
            Add-Content -Path $outPsm1 -Encoding utf8
        }

        # Public functions
        Get-ChildItem -Path "$repoPath\Public" -File | ForEach-Object {
            $_ | Get-Content |
                Add-Content -Path $outPsm1 -Encoding utf8
            }

            Copy-Item -Path $srcPsd1 -Destination $outPsd1
}

Task Zip -depends Build {
    Write-Verbose "Zipping module."

    Compress-Archive -Path $outputPath -DestinationPath "$repoPath\bin\$($manifest.ModuleVersion)\AutoTaskEndpointManagement.zip"
}