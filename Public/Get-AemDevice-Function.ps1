Function Get-AemDevice {
    <#
        .DESCRIPTION
            Retrieves either individual devices by ID or UID, or all devices from AutoTask Endpoint Management.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 16 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Fixed typo in help.
                - Changed return to filter out duplicate devices based on the Id field.
            V1.0.0.2 date: 17 June 2018
                - Removed uniqueness filter from return statement.
            V1.0.0.3 date: 16 August 2018
                - Updated white space.
            V1.0.0.4 date: 18 November 2018
                - Konstantin Kaminskiy renamed to Get-AemDevice, added ability to get device by UID.
            V1.0.0.5 date: 21 November 2018
                - Updated white space.
            V1.0.0.6 date: 25 March 2019
                - Added support for rate-limiting response.
            V1.0.0.7 date: 8 April 2019
                - Added alias for Get-AemDevices.
            V1.0.0.8 date: 5 December 2019
            V1.0.0.9 date: 11 December 2019
            V1.0.0.10 date: 16 March 2020
            V1.0.0.11 date: 17 March 2020
            V1.0.0.12 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceId
            Represents the ID number (e.g. 23423) of the desired device.
        .PARAMETER DeviceUID
            Represents the UID (31fcea20-3924-c976-0a59-52ec4a2bbf6f) of the desired device.
        .PARAMETER All
            Use this parameter to get all devices from Autotask Endpoint Management.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            Get-AemDevice -AccessToken $token -Verbose

            This will return all devices. Verbose output is sent to the host.
        .EXAMPLE
            Get-AemDevice -AccessToken $token -DeviceId $id

            This will return the device matching the specified id.
        .EXAMPLE
            Get-AemDevice -AccessToken $token -DeviceUID $UID

            This will return the device matching the specified UID.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AllDevices')]
    [alias('Get-AemDevices')]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $false, ParameterSetName = 'IDFilter')]
        [int]$DeviceId,
        
        [Parameter(Mandatory = $false, ParameterSetName = 'UIDFilter')]
        [string]$DeviceUID,

        [Parameter(Mandatory = $false, ParameterSetName = 'SiteFilter')]
        [ValidateScript( {
                try {
                    $null = [System.Guid]::Parse($_)
                    $true
                }
                catch {
                    $false
                }
            })]
        [System.Guid]$SiteUID,

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
        $message = ("{0}: Operating in the {1} parameter set." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Initialize variables.
        $devices = $null
        $loopCount = 0

        Switch ($PsCmdlet.ParameterSetName) {
            { $_ -in ("IDFilter", "AllDevices", "UIDFilter", "SiteFilter") } {
                # Define parameters for Invoke-WebRequest cmdlet.
                $params = @{
                    Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/devices"
                    Method      = 'GET'
                    ContentType = 'application/json'
                    Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                }

                $message = ("{0}: Updated `$params hash table. The values are:`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            }
            "IDFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/devices")+"/device/id/$DeviceId")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            }
            "UIDFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/devices")+"/device/$DeviceUID")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            }
            "SiteFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/devices")+"/site/$SiteUID/devices")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            }
        }

        # Make request.
        $message = ("{0}: Making the first web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        Try {
            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        Switch ($PsCmdlet.ParameterSetName) {
            { $_ -in ("AllDevices", "SiteFilter") } {
                $devices = ($webResponse | ConvertFrom-Json).devices
            }
            { $_ -in ("IDFilter", "UIDFilter") } {
                $devices = ($webResponse | ConvertFrom-Json)
            }
        }

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $stopLoop = $false
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]

            If ($PsCmdlet.ParameterSetName -ne "SiteFilter") {
                $resourcePath = "/v2/account/devices?$page"
            }
            Else {
                $resourcePath = "/v2/site/$SiteUID/devices?$page"
            }

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page="))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Do {
                Try {
                    $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match '429') {
                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: It appears that the web request failed. The specific error message is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return
                    }
                }
            }
            While ($stopLoop -eq $false)

            $message = ("{0}: Retrieved an additional {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).devices).count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $devices += ($webResponse | ConvertFrom-Json).devices
        }

        Return $devices
    }
} #1.0.0.11