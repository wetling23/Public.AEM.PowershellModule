Function Add-EventLogSource {
    <#
        .DESCRIPTION
            Adds an Event Log source, for script/module logging. Adding an Event Log source requires administrative rights.
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 19 April 2017
                - Initial release.
            V1.0.0.1 date: 1 May 2017
                - Minor updates to status handling.
            V1.0.0.2 date: 4 May 2017
                - Added additional return value.
            V1.0.0.3 date: 22 May 2017
                - Changed output to reduce the number of "Write-Host" messages.
            V1.0.0.4 date: 21 June 2017
                - Fixed typo.
                - Significantly improved performance.
                - Changed logging.
            V1.0.0.5 date: 21 June 2017
                - Added a return value if the event log source exists.
            V1.0.0.6 date: 28 June 2017
                - Added [CmdletBinding()].
            V1.0.0.7 date: 28 June 2017
                - Added a check for the source, then a check on the status of the query.
            V1.0.0.8 date 9 February 2018
                - Updated output to remove a message.
        .PARAMETER EventLogSource
            Mandatory parameter. This parameter is used to specify the event source, that script/modules will use for logging.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        $EventLogSource
    )

    # Check if $EventLogSource exists as a source. If the shell is not elevated and the check fails to access the Security log, assume the source does not exist.
    Try {
        $sourceExists = [System.Diagnostics.EventLog]::SourceExists("$EventLogSource")
    }
    Catch {
        $sourceExists = $False
    }

    If ($sourceExists -eq $False) {
        $message = ("{0}: The event source `"{1}`" does not exist. Prompting for elevation." -f (Get-Date -Format s), $EventLogSource)
        Write-Host $message -ForegroundColor White
        
        Try {
            Start-Process PowerShell –Verb RunAs -ArgumentList "New-EventLog –LogName Application –Source $EventLogSource -ErrorAction Stop"
        }
        Catch [System.InvalidOperationException] {
            $message = ("{0}: It appears that the user cancelled the operation." -f (Get-Date -Format s))
            Write-Host $message -ForegroundColor Yellow
            Return "Error"
        }
        Catch {
            $message = ("{0}: Unexpected error launching an elevated Powershell session. The specific error is: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            Write-Host $message -ForegroundColor Red
            Return "Error"
        }

        Return "Success"
    }
    Else {
        $message = ("{0}: The event source `"{1}`" already exists. There is no action for {2} to take." -f (Get-Date -Format s), $EventLogSource, $MyInvocation.MyCommand)
        Write-Verbose $message

        Return "Success"
    }
} #1.0.0.8

Function Find-AemSoftwareInstance {
    <#
        .DESCRIPTION
            Accepts an application name and optional device group, and returns a list of all devices where the application is installed.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
        .PARAMETER Application
            Represents the name of an application, for which to search.
        .PARAMETER AemAccessToken
            Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteName
            When included, search for the specified application on machines from this site. If not included, search on machines in all sites (except Deleted Devices).
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Find-AemApplicationInstance -Application "CentraStage" -AemAccessToken <token>

            In this example, the function will search the audit data of devices in all sites (except Deleted Devices), for CentraStage. Output will be written to the event log and host.
        .EXAMPLE
            PS C:\> Find-AemApplicationInstance -Application "CentraStage" -AemAccessToken <token> -SiteName <site name>

            In this example, the function will search the audit data of devices in <site name> for CentraStage. Output will be written to the event log and host
        .EXAMPLE
            PS C:\> Find-AemApplicationInstance -Application "CentraStage" -AemAccessToken <token> -ApiUrl https://merlot.centrastage.net -BlockLogging

            In this example, the function will search the audit data of devices in all sites (except Deleted Devices), for CentraStage. Output will be written to the event log and host.
            In this example, the AEM instance is located in the "merlot" region.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$Application,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AemAccessToken,

        [string]$SiteName,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }
    }

    Process {
        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        # Initialize variables.
        [hashtable]$devicesWithApp = @{}
        [int]$index = 0

        # Setup the parameters for Get-AemDevices.
        If (($PSBoundParameters['Verbose'])) {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
                Verbose        = $True
            }
        }
        Else {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
            }
        }

        # Retrieve device information from the API.
        If ($SiteName) {
            $message = ("{0}: Getting all devices in {1}." -f (Get-Date -Format s), $SiteName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $allDevices = (Get-AemDevices @deviceQueryParams | Where-Object {($_.siteName -ne 'Deleted Devices') -and ($_.siteName -eq "$SiteName")})
        }
        Else {
            $message = ("{0}: Getting all devices." -f (Get-Date -Format s), $SiteName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $allDevices = (Get-AemDevices @deviceQueryParams | Where-Object {$_.siteName -ne 'Deleted Devices'})
        }

        If (-NOT($allDevices)) {
            $message = ("{0}: Unable to locate devices. To prevent errors, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        Foreach ($device in $alldevices) {
            $message = ("{0}: Checking for {1} on {2} (device number {3} of {4})." -f (Get-Date -Format s), $Application, $device.hostname, $index, $allDevices.count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$($device.Uid)/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Getting applications installed on {1}." -f (Get-Date -Format s), $device.hostname)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webrequest = Invoke-WebRequest @params -ErrorAction Stop | ConvertFrom-Json
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. The specific error message is: {1}" -f (Get-Date -Format s), $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}
            }

            Switch ($webrequest.software.count) {
                {$_ -gt 0} {
                    # We have a device with a list of installed software.
                    If ($webrequest.software.Name -match "$Application") {
                        $message = ("{0}: Found {1}." -f (Get-Date -Format s), $Application)
                        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

                        $devicesWithApp.add($device.hostname, $device.siteName)
                    }

                    Continue
                }
                {$_ -eq 0} {
                    Write-Host ("{0}: {1} returned no software information." -f (Get-Date -Format s), $device.hostname)
                    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417}

                    Continue
                }
            }

            $index++
        }

        Return $devicesWithApp
    }
} #1.0.0.0
Function Get-AemDevices {
    <#
        .DESCRIPTION
            Retrieves either individual or all devices from AutoTask Endpoint Management. 
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 16 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Fixed typo in help.
                - Changed return to filter out duplicate devices based on the Id field.
            V1.0.0.2 date: 17 June 2018
                - Removed uniqueness filter from return statement.
            V1.0.0.3 date: 16 August 2018
                - Updated white space.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceId
            Represents the ID number (e.g. 23423) of the desired device.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
    #>
    [CmdletBinding(DefaultParameterSetName = ’AllDevices’)]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = ’AllDevices’)]
        [Parameter(ParameterSetName = ’IDFilter’)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = ’IDFilter’)]
        [int]$DeviceId,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }

        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
    }

    Process {
        Switch ($PsCmdlet.ParameterSetName) {
            {$_ -in ("IDFilter", "AllDevices")} {
                # Define parameters for Invoke-WebRequest cmdlet.
                $params = @{
                    Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/devices"
                    Method      = 'GET'
                    ContentType = 'application/json'
                    Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
                }

                $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            }
            "IDFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/devices")+"/device/id/$DeviceId")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            }
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            $webResponse = (Invoke-WebRequest @params -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        Switch ($PsCmdlet.ParameterSetName) {
            "AllDevices" {
                $devices = ($webResponse | ConvertFrom-Json).devices
            }
            "IDFilter" {
                $devices = ($webResponse | ConvertFrom-Json)
            }
        }

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/account/devices?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization'	= 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Making web request for page {1}." -f (Get-Date -Format s), $page.TrimStart("page="))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = (Invoke-WebRequest @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} devices." -f (Get-Date -Format s), (($webResponse|ConvertFrom-Json).devices).count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            
            $devices += ($webResponse|ConvertFrom-Json).devices
        }

        Return $devices
    }
} #1.0.0.3

Function Get-AemDevicesFromSite {
    <#
        .DESCRIPTION
            Retrieves all devices from a user-specified site.
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 17 June 2018
                - Initial release.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }
    }

    Process {
        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/devices"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            $webResponse = (Invoke-WebRequest @params -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        $devices = ($webResponse | ConvertFrom-Json).devices

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/site/$SiteUid/devices?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Making web request for page {1}." -f (Get-Date -Format s), $page.TrimStart("page="))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = (Invoke-WebRequest @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} devices." -f (Get-Date -Format s), (($webResponse|ConvertFrom-Json).devices).count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            
            $devices += ($webResponse | ConvertFrom-Json).devices
        }

        Return $devices
    }
} #1.0.0.0
Function Get-AemSites {
    <#
        .DESCRIPTION
            Retrieves either individual or all sites from AutoTask Endpoint Management. 
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 17 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Removed uniqueness filter from return statement.
            V1.0.0.2 date: 17 August 2018
                - Updated white space.
                - Changed parameter name from SiteId to SiteUid for clarity.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
    #>
    [CmdletBinding(DefaultParameterSetName = ’AllSites’)]
    Param (
        [Parameter(Mandatory = $True)]
        [Parameter(ParameterSetName = ’AllSites’)]
        [Parameter(ParameterSetName = ’IDFilter’)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = ’IDFilter’)]
        [string]$SiteUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource
    
            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }

        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
    }

    Process {
        Switch ($PsCmdlet.ParameterSetName) {
            {$_ -in ("IDFilter", "AllSites")} {
                # Define parameters for Invoke-WebRequest cmdlet.
                $params = @{
                    Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/sites"
                    Method      = 'GET'
                    ContentType = 'application/json'
                    Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
                }

                $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            }
            "IDFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/sites")+"/site/$SiteUid")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            }
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            $webResponse = (Invoke-WebRequest @params -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        Switch ($PsCmdlet.ParameterSetName) {
            "AllSites" {
                $sites = ($webResponse | ConvertFrom-Json).sites
            }
            "IDFilter" {
                $sites = ($webResponse | ConvertFrom-Json)
            }
        }

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/account/sites?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Making web request for page {1}." -f (Get-Date -Format s), $page.TrimStart("page="))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = (Invoke-WebRequest @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} sites." -f (Get-Date -Format s), (($webResponse | ConvertFrom-Json).sites).count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            
            $sites += ($webResponse | ConvertFrom-Json).sites
        }

        Return $sites
    }
} #1.0.0.2
Function Get-AemSoftwareList {
    <#
        .DESCRIPTION
            Accepts a device UID and returns a list of installed applications.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
        .PARAMETER
        .EXAMPLE
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = 'IdFilter')]
        [int]$DeviceId,

        [Parameter(Mandatory = $True, ParameterSetName = 'UidFilter')]
        [string]$DeviceUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }
    }

    Process {
        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        # Setup the parameters for Get-AemDevices.
        If (($PSBoundParameters['Verbose'])) {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
                Verbose        = $True
            }
        }
        Else {
            $deviceQueryParams = @{
                AemAccessToken = $AemAccessToken
            }
        }
        If ($BlockLogging) {
            $deviceQueryParams.add("BlockLogging", $True)
        }
        Else {
            $deviceQueryParams.add("EventLogSource", $EventLogSource)
        }

        Switch ($PsCmdlet.ParameterSetName) {
            "IdFilter" {
                $DeviceUId = (Get-AemDevices -DeviceId $DeviceId @deviceQueryParams).Uid
            }
        }

        If ($DeviceId -as [int]) {
            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Getting installed applications." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = Invoke-WebRequest @params -ErrorAction Stop | ConvertFrom-Json
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. The specific error message is: {1}" -f (Get-Date -Format s), $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            Return $webResponse.software
        }
        Else {
            $message = ("{0}: Unable to determine the Uid of the device with ID {1}. To prevent errors, {2} will exit." -f (Get-Date -Format s), $DeviceId, $MyInvocation.MyCommand)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }
    }
}
Function Get-AemUsers {
    <#
        .DESCRIPTION
            Retrieves all users from AutoTask Endpoint Management.
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 22 August 2018
                - Initial release.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            .\Get-AemUsers -AemAccessToken <bearer token>

            This example returns an array of all AEM users and their properties.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AemAccessToken,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }

        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
    }

    Process {
        # Define parameters for Invoke-WebRequest cmdlet.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/users"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            $webResponse = (Invoke-WebRequest @params -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        $users = ($webResponse | ConvertFrom-Json).users

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/account/users?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization'	= 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Making web request for page {1}." -f (Get-Date -Format s), $page.TrimStart("page="))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Try {
                $webResponse = (Invoke-WebRequest @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} devices." -f (Get-Date -Format s), (($webResponse|ConvertFrom-Json).devices).count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            
            $users += ($webResponse|ConvertFrom-Json).users
        }

        Return $users
    }
} #1.0.0.0
Function New-AemApiAccessToken {
    <#
        .DESCRIPTION
            Retrieves an authorization token from AutoTask.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 15 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Added missing closing backet.
            V1.0.0.2 date: 16 August 2018
                - Removed Ssl3 and Tsl protocol support.
                - Added return.
                - Fixed output bug. The -BlockLogging parameter was blocking all output.
                - Updated white space.
        .LINK
        .PARAMETER ApiKey
            Mandatory parameter. Represents the API key to AEM's REST API.
        .PARAMETER ApiSecretKey
                Mandatory parameter. Represents the API secret key to AEM's REST API.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            .\New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$ApiKey,

        [Parameter(Mandatory = $True)]
        [string]$ApiSecretKey,
        
        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )
    #requires -Version 3.0

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
            Write-Host $message -ForegroundColor Yellow;

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    # Specify security protocols.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Tls11,Tls12'

    # Convert password to secure string.
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force

    # Define parameters for Invoke-WebRequest cmdlet.
    $params = @{
        Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
        Uri         = '{0}/auth/oauth/token' -f $ApiUrl
        Method      = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = 'grant_type=password&username={0}&password={1}' -f $ApiKey, $ApiSecretKey
    }

    $message = ("{0}: Requesting a bearer token from AutoTask." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    # Request access token.
    Try {
        $webResponse = Invoke-WebRequest @params -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error generating an authorization token. To prevent errors, {1} will exit. The specific error message is: {2}" `
                -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

        Return "Error"
    }

    If ($webResponse) {
        $webResponse
    }
    Else {
        Return "Error"
    }
} #1.0.0.2
