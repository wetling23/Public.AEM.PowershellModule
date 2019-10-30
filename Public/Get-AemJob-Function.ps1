Function Get-AemJob {
    <#
        .DESCRIPTION
            Accepts a Datto RMM job unique ID and 
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 29 October 2019
                - Initial release.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER JobUid
            Represents the unique ID (e.g. 44e7a880-8c4b-44cf-8133-b1d17a9aea5e) of the desired job. A job's UID is available in the Actvity Log (Setup -> Activity Log).
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:> Get-AemJob -AemAccessToken '<access token>' -JobUid '44e7a880-8c4b-44cf-8133-b1d17a9aea5e' -BlockLogging

            In this example, the cmdlet retrieves the status of the job with unique ID '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'. The cmdlet's output is written only to the host.
        .EXAMPLE
            PS C:> Get-AemJob -AemAccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -JobUid '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'

            In this example, the cmdlet retrieves the status of the job with unique ID '44e7a880-8c4b-44cf-8133-b1d17a9aea5e'. The cmdlet's output is written to the host and to the Windows Application log.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string]$AemAccessToken,

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

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource

            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message

                $BlockLogging = $True
            }
        }

        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }
    }

    Process {
        $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
        If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        # Initialize variables.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/job/$JobUid"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken }
        }

        Try {
            $message = ("{0}: Making the web request." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: Unexpected error getting the RMM job. To prevent errors, {1} will exit.The specific error is: {2}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

            Return "Error"
        }

        $webResponse | ConvertFrom-Json
    }
} #1.0.0.0