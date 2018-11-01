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
        .EXAMPLE
            Get-AemSites -AemAccessToken $token
            This will return all sites.
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
            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
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
                $webResponse = (Invoke-WebRequest -UseBasicParsing @params).Content
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
