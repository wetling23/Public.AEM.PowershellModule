Function Get-AemJob {
    <#
        .DESCRIPTION
            Accepts a Datto RMM job unique ID and returns the job's status.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 29 October 2019
                - Initial release.
            V1.0.0.1 date: 5 December 2019
            V1.0.0.2 date: 11 December 2019
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER JobUid
            Represents the unique ID (e.g. 44e7a880-8c4b-44cf-8133-b1d17a9aea5e) of the desired job. A job's UID is available in the Actvity Log (Setup -> Activity Log).
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:> Get-AemJob -AccessToken '<access token>' -JobUid '44e7a880-8c4b-44cf-8133-b1d17a9aea5e' -Verbose

            In this example, the cmdlet retrieves the status of the job with unique ID '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'. Verbose output is sent to the host.
        .EXAMPLE
            PS C:> Get-AemJob -AccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -JobUid '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'

            In this example, the cmdlet retrieves the status of the job with unique ID '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'. The cmdlet's output is written to the host and to the Windows Application log.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [ValidateScript( {
                try {
                    $null = [System.Guid]::Parse($_)
                    $true
                }
                catch {
                    throw "The value provided for DeviceUID is not formatted properly."
                }
            } )]
        [string]$JobUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    Process {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        # Initialize variables.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/job/$JobUid"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
        }

        Try {
            $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: Unexpected error getting the RMM job. To prevent errors, {1} will exit.The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Return "Error"
        }

        $webResponse | ConvertFrom-Json
    }
} #1.0.0.2