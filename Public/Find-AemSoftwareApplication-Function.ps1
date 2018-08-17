
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