Function Get-AemComponent {
    <#
        .DESCRIPTION
            Retrieves all components from AutoTask Endpoint Management.
        .NOTES
            Author: Mike Hashemi
            V2026.06.05.0
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            .\Get-AemComoponent -AccessToken <bearer token> -Verbose

            This example returns an array of all AEM components and their properties. Verbose output is sent to the host.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        #region Logging splatting
        if ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
            if ($LogPath) {
                $loggingParams = @{
                    Verbose = $true
                    LogPath = $LogPath
                }
            } else {
                $loggingParams = @{
                    Verbose = $true
                }
            }
        } else {
            if ($LogPath) {
                $loggingParams = @{
                    LogPath = $LogPath
                }
            } else {
                $loggingParams = @{}
            }
        }
        #endregion Logging splatting

        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-ddTHH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Info -Message $message
    }

    Process {
        # Define parameters for Invoke-WebRequest cmdlet.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/components"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Try {
            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }

        $components = ($webResponse | ConvertFrom-Json).components

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/account/components?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page=")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Try {
                $webResponse = (Invoke-WebRequest -UseBasicParsing @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} components." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).components).count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
            
            $components += ($webResponse | ConvertFrom-Json).components
        }

        Return $components
    }
} #2026.06.05.0