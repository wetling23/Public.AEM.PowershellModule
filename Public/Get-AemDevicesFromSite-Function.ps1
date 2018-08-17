
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