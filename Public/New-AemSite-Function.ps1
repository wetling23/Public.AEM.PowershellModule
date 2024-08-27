Function New-AemSite {
    <#
        .DESCRIPTION
            Creates a new site.
        .NOTES
            Author: Mike Hashemi
            V2024.08.27.0
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
            PS C:\> $Properties = @{
                name                 = "New Site Name"
                onDemand             = $false
                splashtopAutoInstall = $false
            }
            PS C:\> New-AemSite -AccessToken $token -Properties $Properties -Verbose

            In this example, the command will create a site called "New Site Name". Verbose logging output is sent only to the host.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [String]$AccessToken,

        [Parameter(Mandatory = $True)]
        [Hashtable]$Properties,

        [String]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    Process {
        #region Setup
        #region Initialize variables
        $body = $Properties | ConvertTo-Json -Depth 10
        #endregion Initialize variables

        #region Logging splatting
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
            If ($LogPath) {
                $loggingParams = @{
                    Verbose = $true
                    LogPath = $LogPath
                }
            } Else {
                $loggingParams = @{
                    Verbose = $true
                }
            }
        } Else {
            If ($LogPath) {
                $loggingParams = @{
                    LogPath = $LogPath
                }
            } Else {
                $loggingParams = @{}
            }
        }
        #endregion Logging splatting

        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType First -Message $message
        #endregion Setup

        #region Send request
        #endregion Send request
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/"
            Method      = 'PUT'
            ContentType = 'application/json'
            Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
            Body        = $body
        }

        $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String).Trim()); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Try {
            $response = Invoke-RestMethod @params -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. To prevent errors, {1} will exit. The specific error message is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }

        If ($response.id) {
            $message = ("{0}: Successfully created the site (ID: {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.id); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Return $response
        }
        Else {
            $message = ("{0}: Failed to delete the variable(s).`r`nHTTP status code: {1}`r`nHTTP status description: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.StatusCode, $response.StatusDescription); Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }
    }
} #2024.08.27.0