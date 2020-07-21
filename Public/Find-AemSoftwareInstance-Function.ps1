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
            V1.0.0.4 date: 5 December 2019
            V1.0.0.5 date: 11 December 2019
            V1.0.0.6 date: 30 June 2020
            V1.0.0.7 date: 21 July 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER Application
            Represents the name of an application, for which to search.
        .PARAMETER AccessToken
            Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteName
            When included, search for the specified application on machines from this site. If not included, search on machines in all sites (except Deleted Devices).
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Find-AemSoftwareInstance -Application "CentraStage" -AccessToken <token> -Verbose

            In this example, the function will search the audit data of devices in all sites (except Deleted Devices), for CentraStage. Output will be written to the event log and host. Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Find-AemSoftwareInstance -Application "CentraStage" -AccessToken <token> -SiteName <site name>

            In this example, the function will search the audit data of devices in <site name> for CentraStage. Output will be written to the event log and host
        .EXAMPLE
            PS C:\> Find-AemSoftwareInstance -Application "CentraStage" -AccessToken <token> -ApiUrl https://merlot.centrastage.net -BlockLogging

            In this example, the function will search the audit data of devices in all sites (except Deleted Devices), for CentraStage. Output will be written to the event log and host.
            In this example, the AEM instance is located in the "merlot" region.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$Application,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [string]$SiteName,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
    }

    Process {
        # Initialize variables.
        [int]$index = 0
        $http400Devices = @()

        # Splatting parameters.
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
                    Verbose = $true
                    LogPath = $LogPath
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

        # Retrieve device information from the API.
        If ($SiteName) {
            $message = ("{0}: Getting all devices in {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $SiteName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $allDevices = (Get-AemDevice @commandParams | Where-Object { ($_.siteName -ne 'Deleted Devices') -and ($_.siteName -eq "$SiteName") })
        }
        Else {
            $message = ("{0}: Getting all devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $SiteName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $allDevices = (Get-AemDevice @commandParams | Where-Object { $_.siteName -ne 'Deleted Devices' })
        }

        If (-NOT($allDevices)) {
            $message = ("{0}: Unable to locate devices. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        Foreach ($device in $alldevices) {
            $stopLoop = $false
            $message = ("{0}: Checking for `"{1}`" on {2} (device number {3} of {4})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Application, $device.hostname, $index, $allDevices.count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $index++

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$($device.Uid)/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Getting applications installed on {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.hostname)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Do {
                Try {
                    $webrequest = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match '429') {
                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message -BlockStdErr $BlockStdErr }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf ($_.Exception.Message -match '403') {
                        $message = ("{0}: Secret rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message -BlockStdErr $BlockStdErr }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf ($_.Exception.Message -match '400') {
                        $message = ("{0}: The remote server returned 400 (Bad Request). This may be caused by a device ({1}) not having any software list." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.hostname)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        # I am not doing anything with $http400Devices yet. Perhaps I will write them all out to the logging output (in a group), we'll see.
                        $http400Devices += $device

                        $stopLoop = $True
                    }
                    ElseIf ($_.Exception.Message -match '401') {
                        $message = ("{0}: The remote server returned 401. It appears that the access token has expired." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message -BlockStdErr $BlockStdErr }

                        Return
                    }
                    ElseIf ($_.Exception.Message -match '404') {
                        $message = ("{0}: The remote server returned 404. It appears that we were unable to locate {1} ({2})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.hostname, $device.id)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message -BlockStdErr $BlockStdErr }

                        $stopLoop = $True
                    }
                    Else {
                        $message = ("{0}: It appears that the web request failed (for {1}). The specific error message is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $device.hostname, $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return
                    }
                }
            }
            While ($stopLoop -eq $false)

            # Used "-like" instead of "-match" on purpose.
            If ($webrequest.software.Name -like "$Application*") {
                $message = ("{0}: Found `"{1}`"." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Application)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

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
} #1.0.0.7