Function Find-AemSoftwareInstance {
    <#
        .DESCRIPTION
            Accepts an application name and optional device group, and returns a list of all devices where the application is installed.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
            V1.0.0.1 date: 25 March 2019
                - Added support for rate-limiting response.
                - Updated loop and properties.
            V1.0.0.2 date: 28 March 2019
                - Added support for 403, 401, and 400 responses.
            V1.0.0.3 date: 29 March 2019
                - Added support for 404 response.
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
        [int]$index = 0
        $http400Devices = @()

        # Setup the parameters for Get-AemDevice.
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

            $allDevices = (Get-AemDevice @deviceQueryParams | Where-Object {($_.siteName -ne 'Deleted Devices') -and ($_.siteName -eq "$SiteName")})
        }
        Else {
            $message = ("{0}: Getting all devices." -f (Get-Date -Format s), $SiteName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $allDevices = (Get-AemDevice @deviceQueryParams | Where-Object {$_.siteName -ne 'Deleted Devices'})
        }

        If (-NOT($allDevices)) {
            $message = ("{0}: Unable to locate devices. To prevent errors, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

        Foreach ($device in $alldevices) {
            $stopLoop = $false
            $message = ("{0}: Checking for `"{1}`" on {2} (device number {3} of {4})." -f (Get-Date -Format s), $Application, $device.hostname, $index, $allDevices.count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $index++

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$($device.Uid)/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
            }

            $message = ("{0}: Getting applications installed on {1}." -f (Get-Date -Format s), $device.hostname)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            Do {
                Try {
                    $webrequest = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match '429') {
                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s))
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Yellow} Else {Write-Host $message -ForegroundColor Yellow; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417}

                        Start-Sleep -Seconds 60
                    }
                    ElseIf ($_.Exception.Message -match '403') {
                        $message = ("{0}: Secret rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s))
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Yellow} Else {Write-Host $message -ForegroundColor Yellow; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417}

                        Start-Sleep -Seconds 60
                    }
                    ElseIf ($_.Exception.Message -match '400') {
                        $message = ("{0}: The remote server returned 400 (Bad Request). This may be caused by a device ({1}) not having any software list." -f (Get-Date -Format s), $device.hostname)
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                        # I am not doing anything with $http400Devices yet. Perhaps I will write them all out to the logging output (in a group), we'll see.
                        $http400Devices += $device

                        $stopLoop = $True
                    }
                    ElseIf ($_.Exception.Message -match '401') {
                        $message = ("{0}: The remote server returned 401. It appears that the access token has expired." -f (Get-Date -Format s))
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Yellow} Else {Write-Host $message -ForegroundColor Yellow; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417}

                        Return
                    }
                    ElseIf ($_.Exception.Message -match '404') {
                        $message = ("{0}: The remote server returned 404. It appears that we were unable to locate {1} ({2})." -f (Get-Date -Format s), $device.hostname, $device.id)
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Yellow} Else {Write-Host $message -ForegroundColor Yellow; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417}

                        $stopLoop = $True
                    }
                    Else {
                        $message = ("{0}: It appears that the web request failed (for {1}). The specific error message is: {2}" -f (Get-Date -Format s), $device.hostname, $_.Exception.Message)
                        If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

                        Return
                    }
                }
            }
            While ($stopLoop -eq $false)

            # Used "-like" instead of "-match" on purpose.
            If ($webrequest.software.Name -like "$Application*") {
                $message = ("{0}: Found `"{1}`"." -f (Get-Date -Format s), $Application)
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

                Foreach ($app in $webrequest.software) {
                    If ($app.name -Match "$Application") {
                        $obj = New-Object -TypeName PSObject -Property @{
                            DeviceName         = $device.hostname
                            SiteName           = $device.siteName
                            ApplicationName    = $app.name
                            ApplicationVersion = $app.version
                            OperatingSystem    = $device.operatingSystem
                        }

                        $obj
                    }
                }
            }
        }
    }
} #1.0.0.3