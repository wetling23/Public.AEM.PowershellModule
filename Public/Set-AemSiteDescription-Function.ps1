Function Set-AemSiteDescription {
    <#
        .DESCRIPTION
            Sets the description of the AEM site
        .NOTES
            Author: Konstantin Kaminskiy
            V1.0.0.0 date: 14 November 2018
                - Initial release.
            V1.0.0.1 date: 21 November 2018
                - Updated white space.
                - Changed Out-Null to $null.
            V1.0.0.2 date: 5 December 2019
            V1.0.0.3 date: 11 December 2019
            V1.0.0.4 date: 23 June 2020
            V1.0.0.5 date: 30 June 2020
            V1.0.0.6 date: 21 July 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER Description
            A string with the intended description of the site.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            Set-AemSiteDescription -AccessToken $token -SiteUID $SiteUid -Description "The one site to rule them all!" -Verbose
            This will set the site description to "The one site to rule them all!". Verbose output is sent to the host.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [Parameter(Mandatory = $True)]
        [string]$Description,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Setup the parameters for Get-AemDevice.
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
            If ($EventLogSource -and (-NOT $LogPath)) {
                $commandParams = @{
                    Verbose        = $true
                    EventLogSource = $EventLogSource
                    AccessToken    = $AccessToken
                    ApiUrl         = $ApiUrl
                }
            }
            ElseIf ($LogPath -and (-NOT $EventLogSource)) {
                $commandParams = @{
                    Verbose     = $true
                    LogPath     = $LogPath
                    AccessToken = $AccessToken
                    ApiUrl      = $ApiUrl
                }
            }
            Else {
                $commandParams = @{
                    Verbose = $true
                }
            }
        }
        Else {
            If ($EventLogSource -and (-NOT $LogPath)) {
                $commandParams = @{
                    Verbose        = $false
                    EventLogSource = $EventLogSource
                    AccessToken    = $AccessToken
                    ApiUrl         = $ApiUrl
                }
            }
            ElseIf ($LogPath -and (-NOT $EventLogSource)) {
                $commandParams = @{
                    Verbose     = $false
                    LogPath     = $LogPath
                    AccessToken = $AccessToken
                    ApiUrl      = $ApiUrl
                }
            }
            Else {
                $commandParams = @{
                    Verbose     = $false
                    AccessToken = $AccessToken
                    ApiUrl      = $ApiUrl
                }
            }
        }
    }

    Process {
        # Define parameters for Invoke-WebRequest cmdlet.
        $description = @{
            "description" = "$description"
            "name"        = (Get-AemSites -SiteUid $SiteUid @commandParams | Select-Object -ExpandProperty name)
        } | ConvertTo-Json

        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid"
            Method      = 'Post'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            Body        = "$description"
        }

        $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Make request.
        $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        Try {
            $null = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
} #1.0.0.6