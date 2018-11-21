Function Set-AemSiteDescription {
    <#
        .DESCRIPTION
            Sets the description of the AEM site 
        .NOTES 
            Author: Konstantin Kaminskiy
            V1.0.0.0 date: 14 November 2018
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
        .PARAMETER Description
            A string with the intended description of the site.
        .EXAMPLE
            Set-AemSiteDescription -AemAccessToken $token -SiteUID $SiteUid -Description "The one site to rule them all!"
            This will set the site description to "The one site to rule them all!".
            
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [Parameter(Mandatory = $True)]
        [string]$Description,

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
    $Description = @{"description" = "$description";
                     "name" = (Get-AemSites -AemAccessToken $AemAccessToken -SiteUid $SiteUid -ApiUrl $ApiUrl | 
                               Select-Object -ExpandProperty name) 
                    } | ConvertTo-Json
    $params = @{
        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid"
        Method      = 'Post'
        ContentType = 'application/json'
        Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
        Body        = "$Description"
    }

    $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            

        # Make request.
        $message = ("{0}: Making the web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | Out-Null
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

    }
} #1.0.0.0