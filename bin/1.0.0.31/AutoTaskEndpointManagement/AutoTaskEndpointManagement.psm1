Function Add-EventLogSource {
    <#
        .DESCRIPTION
            Adds an Event Log source, for script/module logging. Adding an Event Log source requires administrative rights.
        .NOTES 
            Author: Mike Hashemi
            V1.0.0.0 date: 19 April 2017
                - Initial release.
            V1.0.0.1 date: 1 May 2017
                - Minor updates to status handling.
            V1.0.0.2 date: 4 May 2017
                - Added additional return value.
            V1.0.0.3 date: 22 May 2017
                - Changed output to reduce the number of "Write-Host" messages.
            V1.0.0.4 date: 21 June 2017
                - Fixed typo.
                - Significantly improved performance.
                - Changed logging.
            V1.0.0.5 date: 21 June 2017
                - Added a return value if the event log source exists.
            V1.0.0.6 date: 28 June 2017
                - Added [CmdletBinding()].
            V1.0.0.7 date: 28 June 2017
                - Added a check for the source, then a check on the status of the query.
            V1.0.0.8 date 9 February 2018
                - Updated output to remove a message.
        .PARAMETER EventLogSource
            Mandatory parameter. This parameter is used to specify the event source, that script/modules will use for logging.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        $EventLogSource
    )

    # Check if $EventLogSource exists as a source. If the shell is not elevated and the check fails to access the Security log, assume the source does not exist.
    Try {
        $sourceExists = [System.Diagnostics.EventLog]::SourceExists("$EventLogSource")
    }
    Catch {
        $sourceExists = $False
    }

    If ($sourceExists -eq $False) {
        $message = ("{0}: The event source `"{1}`" does not exist. Prompting for elevation." -f (Get-Date -Format s), $EventLogSource)
        Write-Host $message -ForegroundColor White
        
        Try {
            Start-Process PowerShell –Verb RunAs -ArgumentList "New-EventLog –LogName Application –Source $EventLogSource -ErrorAction Stop"
        }
        Catch [System.InvalidOperationException] {
            $message = ("{0}: It appears that the user cancelled the operation." -f (Get-Date -Format s))
            Write-Host $message -ForegroundColor Yellow
            Return "Error"
        }
        Catch {
            $message = ("{0}: Unexpected error launching an elevated Powershell session. The specific error is: {1}" -f (Get-Date -Format s), $_.Exception.Message)
            Write-Host $message -ForegroundColor Red
            Return "Error"
        }

        Return "Success"
    }
    Else {
        $message = ("{0}: The event source `"{1}`" already exists. There is no action for {2} to take." -f (Get-Date -Format s), $EventLogSource, $MyInvocation.MyCommand)
        Write-Verbose $message

        Return "Success"
    }
} #1.0.0.8
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
    [alias('Get-AemDevice')]
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
Function Get-AemDeviceAudit {
    <#
        .DESCRIPTION
            Retrieves device audit data.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 2 November 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceUId
            Represents the UID (31fcea20-3924-c976-0a59-52ec4a2bbf6f) of the desired device.
        .PARAMETER Type
            Represents the type of audit data to return. The command supports "All", "Software", "Hardware".
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            Get-AemDeviceAudit -AccessToken $token -DeviceUId 31fcea20-3924-c976-0a59-52ec4a2bbf6f -Type All -Verbose

            In this example, the command will get hardware and software audit data from the device with UID 31fcea20-3924-c976-0a59-52ec4a2bbf6f. Verbose logging data will be written only to the session host.
        .EXAMPLE
            Get-AemDeviceAudit -AccessToken $token -DeviceUId 31fcea20-3924-c976-0a59-52ec4a2bbf6f -Type Hardware -Verbose -LogPath C:\Temp\log.txt

            In this example, the command will get hardware and software audit data from the device with UID 31fcea20-3924-c976-0a59-52ec4a2bbf6f. Verbose logging data will be written to the session host and C:\Temp\log.txt.
        .EXAMPLE
            Get-AemDeviceAudit -AccessToken $token -DeviceUId 31fcea20-3924-c976-0a59-52ec4a2bbf6f -Type Software -LogPath C:\Temp\log.txt

            In this example, the command will get software audit data from the device with UID 31fcea20-3924-c976-0a59-52ec4a2bbf6f. Limited logging data will be written to C:\Temp\log.txt.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory)]
        [string]$DeviceUid,

        [Parameter(Mandatory)]
        [ValidateSet('All', 'Software', 'Hardware')]
        [string]$Type,

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
        Try {
            Switch ($Type) {
                { $_ -eq 'Hardware' } {
                    $message = ("{0}: Getting hardware properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                    $params = @{
                        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid"
                        Method      = 'GET'
                        ContentType = 'application/json'
                        Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                    }

                    $device = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json
                }
                { $_ -eq 'Software' } {
                    $message = ("{0}: Getting software properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                    $params = @{
                        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                        Method      = 'GET'
                        ContentType = 'application/json'
                        Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                    }

                    $device = ((Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json).software
                }
                { $_ -eq 'All' } {
                    $params = @{
                        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid"
                        Method      = 'GET'
                        ContentType = 'application/json'
                        Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                    }

                    $device = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json

                    $params = @{
                        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                        Method      = 'GET'
                        ContentType = 'application/json'
                        Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                    }

                    $software = ((Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json).software

                    $device | Add-Member -MemberType NoteProperty -Name software -Value $software
                }
            }

            If ($device) {
                $message = ("{0}: Returning properties of {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DeviceUId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                $device
            }
            Else {
                $message = ("{0}: No properties returned for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DeviceUId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                Return "Error"
            }
        }
        Catch {
            $message = ("{0}: Unexpected error accessing the REST API. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Return "Error"
        }
    }
} #1.0.0.0
Function Get-AemDevicesFromSite {
    <#
        .DESCRIPTION
            Retrieves all devices from a user-specified site.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 17 June 2018
                - Initial release.
            V1.0.0.1 date: 5 December 2019
            V1.0.0.2 date: 11 December 2019
            V1.0.0.3 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            Get-AemDevicesFromSite -AccessToken $token -SiteUid $uid -Verbose
            This will get the devices for the specified site. Verbose output is sent to the host.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

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
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/devices"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
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

        $devices = ($webResponse | ConvertFrom-Json).devices

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/site/$SiteUid/devices?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page="))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Try {
                $webResponse = (Invoke-WebRequest @params -UseBasicParsing).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).devices).count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            
            $devices += ($webResponse | ConvertFrom-Json).devices
        }

        Return $devices
    }
} #1.0.0.3
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
            V1.0.0.3 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER JobUid
            Represents the unique ID (e.g. 44e7a880-8c4b-44cf-8133-b1d17a9aea5e) of the desired job. A job's UID is available in the Actvity Log (Setup -> Activity Log).
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
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

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
    }
    Process {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Initialize variables.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/job/$JobUid"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
        }

        Try {
            $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: Unexpected error getting the RMM job. To prevent errors, {1} will exit.The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $webResponse | ConvertFrom-Json
    }
} #1.0.0.3
Function Get-AemSite {
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
            V1.0.0.3 date: 5 December 2019
            V1.0.0.4 date: 11 December 2019
            V1.0.0.5 date: 3 March 2020
            V1.0.0.6 date: 23 June 2020
            V1.0.0.7 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            Get-AemSites -AccessToken $token -Verbose
            This will return all sites. Verbose output is sent to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AllSites')]
    [alias('Get-AemSites')]
    Param (
        [Parameter(Mandatory = $True)]
        [Parameter(ParameterSetName = 'AllSites')]
        [Parameter(ParameterSetName = 'IDFilter')]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = 'IDFilter')]
        [string]$SiteUid,

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
        Switch ($PsCmdlet.ParameterSetName) {
            { $_ -in ("IDFilter", "AllSites") } {
                # Define parameters for Invoke-WebRequest cmdlet.
                $params = @{
                    Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/sites"
                    Method      = 'GET'
                    ContentType = 'application/json'
                    Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
                }

                $message = ("{0}: Updated `$params hash table. The values are:`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            }
            "IDFilter" {
                $params.set_item("Uri", "$(($params.Uri).TrimEnd("/account/sites")+"/site/$SiteUid")")

                $message = ("{0}: Updated `$params hash table (Uri key). The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
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
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page="))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Try {
                $webResponse = (Invoke-WebRequest -UseBasicParsing @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} sites." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).sites).count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            
            $sites += ($webResponse | ConvertFrom-Json).sites
        }

        Return $sites
    }
} #1.0.0.7
Function Get-AemSiteVariable {
    <#
        .DESCRIPTION
            Retrieve site variables from the RMM REST API.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 22 March 2021
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUId
            Represents the UID (31fcea20-3924-c976-0a59-52ec4a2bbf6f) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            $token = New-AemApiAccessToken -ApiKey <public API key> -ApiSecretKey (<secret API key> | ConvertTo-SecureString -AsPlainText -Force)
            Get-AemSiteVariable -AccessToken $token -SiteUId 31fcea20-3924-c976-0a59-52ec4a2bbf6f -Verbose

            In this example, the command will get all site variables from the site with UID "31fcea20-3924-c976-0a59-52ec4a2bbf6f". Verbose logging output will be written only to the session host.
        .EXAMPLE
            $siteUid = [pscustomobject]@{'SiteUid' = '8478ad6d-8291-437c-8713-cfe34ec70112'}
            $siteUid | Get-AemSiteVariable -AccessToken "<access ID>" -LogPath C:\temp\log.txt

            In this example, the command will get all site variables from the site with UID "8478ad6d-8291-437c-8713-cfe34ec70112". Limited logging output will be written to the session host and C:\temp\log.txt.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string]$AccessToken,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$SiteUid,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Initialize variables.
        $vars = [System.Collections.Generic.List[PSObject]]::new()
    }
    Process {
        Try {
            $message = ("{0}: Getting variables from {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $SiteUid)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/variables"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content | ConvertFrom-Json

            If ($webResponse.pageDetails.nextPageUrl) {
                Do {
                    $page = ($webResponse.pageDetails.nextPageUrl).Split('&')[-1]
                    $resourcePath = "/v2/site/$SiteUrl/variables?$page"

                    $params = @{
                        Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                        Method      = 'GET'
                        ContentType = 'application/json'
                        Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
                    }

                    $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page="))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                    Try {
                        $webResponse = (Invoke-WebRequest -UseBasicParsing @params).Content
                    } Catch {
                        $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                                -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }

                    $message = ("{0}: Retrieved an additional {1} variables." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).variables).count)
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                    $vars.Add(($webResponse | ConvertFrom-Json).variables)
                }
                While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl)
            }
            Else {
                Return [PSCustomObject]@{
                    SiteUid = $SiteUid
                    Variables = $webresponse.variables
                }
            }
        }
        Catch {
            If ($_ -match 'Site variables are only supported on managed sites') {
                $message = ("{0}: Site variables are only supported on managed sites. Site {1} is not a managed site." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $SiteUid)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }
            }
            Else {
                $message = ("{0}: Unexpected error accessing the REST API. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
    }
} #1.0.0.0
Function Get-AemSoftwareList {
    <#
        .DESCRIPTION
            Accepts a device UID and returns a list of installed applications.
        .NOTES
            V1.0.0.0 date: 17 August 2018
                - Initial release.
            V1.0.0.1 date: 23 August 2018
                - Updated output.
                - Fixed bug in setting up the web request parameters.
            V1.0.0.2 date: 26 February 2019
                - Fixed bug in call to get RMM device.
            V1.0.0.3 date: 5 December 2019
            V1.0.0.4 date: 11 December 2019
            V1.0.0.5 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceId
            Device to get the software list for, by id.
        .PARAMETER DeviceUID
            Device to get the software list for, by uid.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            Get-AemSoftwareList -DeviceUid $uid -AccessToken $token -Verbose
            Get the list of software for the agent specified by the uid. Verbose output is sent to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True, ParameterSetName = 'IdFilter')]
        [int]$DeviceId,

        [Parameter(Mandatory = $True, ParameterSetName = 'UidFilter')]
        [string]$DeviceUid,

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
        $message = ("{0}: Operating in {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Setup the parameters for Get-AemDevices.
        If (($PSBoundParameters['Verbose'])) {
            $deviceQueryParams = @{
                AccessToken = $AccessToken
                Verbose     = $True
            }
        }
        Else {
            $deviceQueryParams = @{
                AccessToken = $AccessToken
            }
        }
        If ($BlockLogging) {
            $deviceQueryParams.add("BlockLogging", $True)
        }
        Else {
            $deviceQueryParams.add("EventLogSource", $EventLogSource)
        }

        Switch ($PsCmdlet.ParameterSetName) {
            "IdFilter" {
                $message = ("{0}: Attempting to retrieve the UID of device {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DeviceId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                $DeviceUId = (Get-AemDevice -DeviceId $DeviceId @deviceQueryParams).Uid
            }
        }

        If ($DeviceUId) {
            $message = ("{0}: Found {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DeviceUid)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/audit/device/$DeviceUid/software"
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Getting installed applications." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Try {
                $webResponse = Invoke-WebRequest -UseBasicParsing @params -ErrorAction Stop | ConvertFrom-Json
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. The specific error message is: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            Return $webResponse.software
        }
        Else {
            $message = ("{0}: Unable to determine the Uid of the device with ID {1}. To prevent errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $DeviceId, $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
} #1.0.0.5
Function Get-AemUser {
    <#
        .DESCRIPTION
            Retrieves all users from AutoTask Endpoint Management.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 22 August 2018
                - Initial release.
            V1.0.0.1 date: 5 December 2019
            V1.0.0.2 date: 11 December 2019
            V1.0.0.3 date: 30 June 2020
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
            .\Get-AemUsers -AccessToken <bearer token> -Verbose

            This example returns an array of all AEM users and their properties. Verbose output is sent to the host.
    #>
    [CmdletBinding()]
    [alias('Get-AemUsers')]
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
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
    }

    Process {
        # Define parameters for Invoke-WebRequest cmdlet.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/account/users"
            Method      = 'GET'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
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

        $users = ($webResponse | ConvertFrom-Json).users

        While ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl) {
            $page = ((($webResponse | ConvertFrom-Json).pageDetails).nextPageUrl).Split("&")[1]
            $resourcePath = "/v2/account/users?$page"

            $params = @{
                Uri         = '{0}/api{1}' -f $ApiUrl, $resourcePath
                Method      = 'GET'
                ContentType = 'application/json'
                Headers     = @{'Authorization'	= 'Bearer {0}' -f $AccessToken }
            }

            $message = ("{0}: Making web request for page {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page.TrimStart("page="))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Try {
                $webResponse = (Invoke-WebRequest -UseBasicParsing @params).Content
            }
            Catch {
                $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                        -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Retrieved an additional {1} devices." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), (($webResponse | ConvertFrom-Json).devices).count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
            
            $users += ($webResponse | ConvertFrom-Json).users
        }

        Return $users
    }
} #1.0.0.3
Function New-AemApiAccessToken {
    <#
        .DESCRIPTION
            Retrieves an authorization token from AutoTask.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 15 June 2018
                - Initial release.
            V1.0.0.1 date: 17 June 2018
                - Added missing closing backet.
            V1.0.0.2 date: 16 August 2018
                - Removed Ssl3 and Tsl protocol support.
                - Added return.
                - Fixed output bug. The -BlockLogging parameter was blocking all output.
                - Updated white space.
            V1.0.0.3 date: 27 October 2018 - by Konstantin Kaminskiy
                - Adjusted returned data to include only the access token itself to increase ease of use.
            V1.0.0.4 date: 16 October 2019
            V1.0.0.5 date: 5 December 2019
            V1.0.0.6 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER ApiKey
            Mandatory parameter. Represents the API key to AEM's REST API.
        .PARAMETER ApiSecretKey
            Mandatory parameter. Represents the API secret key to AEM's REST API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            .\New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force
        .EXAMPLE
            $token = New-AemApiAccessToken -ApiKey XXXXXXXXXXXXXXXXXXXX -ApiSecretKey XXXXXXXXXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force
            Store your token in a variable for later use and re-use.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$ApiKey,

        [Parameter(Mandatory = $True)]
        [securestring]$ApiSecretKey,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )
    #requires -Version 3.0

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

    # Specify security protocols.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]'Tls11,Tls12'

    # Convert password to secure string.
    $securePassword = ConvertTo-SecureString -String 'public' -AsPlainText -Force

    # Define parameters for Invoke-WebRequest cmdlet.
    $params = @{
        Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('public-client', $securePassword)
        Uri         = '{0}/auth/oauth/token' -f $ApiUrl
        Method      = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = 'grant_type=password&username={0}&password={1}' -f $ApiKey, [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiSecretKey))
    }

    $message = ("{0}: Requesting a bearer token from AutoTask." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

    # Request access token.
    Try {
        $webResponse = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop | Select-Object -ExpandProperty access_token
    }
    Catch {
        $message = ("{0}: Unexpected error generating an authorization token. To prevent errors, {1} will exit. The specific error message is: {2}" `
                -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    }

    If ($webResponse) {
        $webResponse
    }
    Else {
        Return "Error"
    }
} #1.0.0.6
Function New-AemSiteDescription {
    <#
        .DESCRIPTION
            Creates a new site variable.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 20 January 2022
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER Variable
            Represents a hashtable of variable properties, to create.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            New-AemSiteDescription -AccessToken $token -SiteUID 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900 -Variable @(@{"name" = "PatchGroup"; "value" = "Prod"; masked = "false" }, @{"name" = "PatchTeam"; "value" = "Team 1"; masked = "false" }) -Verbose

            In this example, the command will create a two new site variables ("PatchGroup" and "PatchTeam") with the specified values (neither field will be masked), in the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900". Verbose logging output is sent to the host only.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [Parameter(Mandatory = $True)]
        [hashtable]$Variable,

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
        $body = $Variable | ConvertTo-Json -Depth 10

        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/variable"
            Method      = 'PUT'
            ContentType = 'application/json'
            Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
            Body        = $body
        }

        $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Make request.
        $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        Try {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        If ($response.StatusCode -eq 200) {
            $message = ("{0}: Successfully created the variable(s)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
        }
        Else {
            $message = ("{0}: Failed to delete the variable(s).`r`nHTTP status code: {1}`r`nHTTP status description: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.StatusCode, $response.StatusDescription)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
} #1.0.0.0
Function Out-ItGlueAsset {
    <#
        .DESCRIPTION
            Accepts a PSCustomObject, converts it to JSON and uploads it to ITGlue. Supports POST and PATCH HTTP methods.

            This cmdlet is used to update standard asset types (e.g. configurations, passwords, documents, contacts, etc.).
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Data
            Custom PSObject containing asset properties.
        .PARAMETER HttpMethod
            Used to dictate whether the cmdlet should use POST or PATCH when sending data to ITGlue.
        .PARAMETER AssetInstanceId
            When included, is used to update (PATCH) a specifc instance of an asset.
        .PARAMETER AssetType
            Represents the type of asset being created/updated.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Out-ItGlueAsset -Data $uploadData -HttpMethod POST -AssetType configurations -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new configuration asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times.
        .EXAMPLE
            PS C:\> Out-ItGlueAsset -Data $uploadData -HttpMethod PATCH -AssetType configurations -AssetInstanceId 123456 -UserCred (Get-Credential) -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the asset with ID 123456, using the provided ITGlue user credentials. Verbose output is sent to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory = $True)]
        [ValidateSet('POST', 'PATCH')]
        [string]$HttpMethod,

        [int64]$AssetInstanceId,

        [Parameter(Mandatory = $True)]
        [ValidateSet('configurations', 'contacts')]
        [string]$AssetType,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # We are patching, but don't have a asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($AssetInstanceId))) {
        $AssetInstanceId = Read-Host -Message "Enter an asset instance ID"
    }

    # Initialize variables.
    $loopCount = 0
    $429Count = 0
    $HttpMethod = $HttpMethod.ToUpper()
    $stopLoop = $false

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
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
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If ($HttpMethod -eq 'PATCH') {
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/$AssetType/$AssetInstanceId")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/$AssetType/$AssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/$AssetType")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/$AssetType"
    }
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $HttpMethod)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
                If ($_.Exception.Message -match 429) {
                    If ($429Count -lt 9) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $429Count++

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $AssetInstanceId, $MyInvocation.MyCommand)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`n`t
                PowerShell returned: {4}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)
    #endregion Main

    $response
} #1.0.0.1
Function Out-PsLogging {
    <#
        .DESCRIPTION
            Logging function, for host, event log, or a log file.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 3 December 2019
                - Initial release.
            V1.0.0.1 date: 7 January 2020
            V1.0.0.2 date: 22 January 2020
            V1.0.0.3 date: 17 March 2020
            V1.0.0.4 date: 15 June 2020
            V1.0.0.5 date: 30 June 2020
            V1.0.0.6 date: 8 April 2021
            V1.0.0.7 date: 10 September 2021
            V1.0.0.8 date: 20 September 2021
        .LINK
            https://github.com/wetling23/logicmonitor-posh-module
        .PARAMETER EventLogSource
            Default parameter set. Represents the Windows Application log event source.
        .PARAMETER LogPath
            Path and file name of the target log file. If the file does not exist, the cmdlet will create it.
        .PARAMETER ScreenOnly
            When this switch parameter is included, the logging output is written only to the host.
        .PARAMETER Message
            Message to output.
        .PARAMETER MessageType
            Type of message to output. Valid values are "Info", "Warning", "Error", and "Verbose". When writing to a log file, all output is "info" but will be written to the host, with the appropriate message type.
        .PARAMETER BlockStdErr
            When set to $True, the cmdlet will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Info -LogPath C:\Temp\log.txt

            In this example, the message, "Test" will be written to the host and appended to C:\Temp\log.txt. If the path does not exist, or the user does not have write access, the message will only be written to the host.
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Warning -EventLogSource TestScript

            In this example, the message, "Test" will be written to the host and to the Windows Application log, as a warning and with the event log source/event ID "TestScript"/5417.
            If the event source does not exist and the session is elevated, the event source will be created.
            If the event source does not exist and the session is not elevated, the message will only be written to the host.
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Verbose -ScreenOnly

            In this example, the message, "Test" will be written to the host as a verbose message.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SessionOnly')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'EventLog')]
        [string]$EventLogSource,

        [ValidateScript( {
                If (-NOT ($_ | Split-Path -Parent | Test-Path) ) {
                    Throw "Path does not exist."
                }
                If (-NOT ($_ | Test-Path) ) {
                    "" | Add-Content -Path $_
                }
                If (-NOT ($_ | Test-Path -PathType Leaf) ) {
                    Throw "The LogPath argument must be a file."
                }
                Return $true
            })]
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [System.IO.FileInfo]$LogPath,

        [switch]$ScreenOnly,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error', 'Verbose', 'First')]
        [string]$MessageType,

        [boolean]$BlockStdErr
    )

    # Initialize variables.
    $elevatedSession = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    If ($PsCmdlet.ParameterSetName -eq "EventLog") {
        If ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) {
            # The event source does not exists, nothing else to do.

            $logType = "EventLog"
        } ElseIf (-NOT ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) -and $elevatedSession) {
            # The event source does not exist, but the session is elevated, so create it.
            Try {
                New-EventLog -LogName Application -Source $EventLogSource -ErrorAction Stop

                $logType = "EventLog"
            } Catch {
                Write-Error ("[ERROR] {0}: Unable to create the event source ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

                $logType = "SessionOnly"
            }
        } ElseIf (-NOT $elevatedSession) {
            # The event source does not exist, and the session is not elevated.
            Write-Error ("[ERROR] {0}: The event source ({1}) does not exist and the command was not run in an elevated session, unable to create the event source. No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

            $logType = "SessionOnly"
        }
    } ElseIf ($PsCmdlet.ParameterSetName -eq "File") {
        # Check if we have rights to the path in $LogPath.
        Try {
            [System.Io.File]::OpenWrite($LogPath).Close()
        } Catch {
            Write-Error ("[ERROR] {0}: Unable to write to the log file path ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $LogPath)

            $logType = "SessionOnly"
        }

        $logType = "LogFile"
    } Else {
        $logType = "SessionOnly"
    }

    Switch ($logType) {
        "SessionOnly" {
            Switch ($MessageType) {
                "Info" { Write-Host "[INFO] $Message" }
                "Warning" { Write-Warning "[WARNING] $Message" }
                "Error" { If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { Write-Verbose "[INFO] $Message" -Verbose }
            }
        }
        "EventLog" {
            Switch ($MessageType) {
                "Info" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[INFO] $Message" -EventId 5417; Write-Host "[INFO] $Message" }
                "Warning" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message "[WARNING] $Message" -EventId 5417; Write-Warning "[WARNING] $Message" }
                "Error" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message "[ERROR] $Message" -EventId 5417; If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[VERBOSE] $Message" -EventId 5417; Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[INFO] $Message" -EventId 5417; Write-Verbose "[INFO] $Message" -Verbose }
            }
            If ($BlockStdErr) {

            }
        }
        "LogFile" {
            Switch ($MessageType) {
                "Info" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[INFO] $Message", [Text.Encoding]::UTF8); Write-Host "[INFO] $Message" }
                "Warning" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[WARNING] $Message", [Text.Encoding]::UTF8); Write-Warning "[WARNING] $Message" }
                "Error" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[ERROR] $Message", [Text.Encoding]::UTF8); If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[VERBOSE] $Message", [Text.Encoding]::UTF8); Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { [System.IO.File]::WriteAllLines($LogPath, "[INFO] $Message", [Text.Encoding]::UTF8); Write-Verbose "[INFO] $Message" -Verbose }
            }
        }
    }
} #1.0.0.8
Function Remove-AemSiteVariable {
    <#
        .DESCRIPTION
            Deletes a site variable.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 20 January 2022
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER VariableId
            Represents the ID of the variable to delete.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            $vars = Get-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900
            $varId = $vars.Variables | Where-Object {$_.name -eq 'PatchGroup'} | Select-Object -ExpandProperty id
            Remove-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900 -VariableId $varId -LogPath C:\Temp\log.txt

            In this example, the command will query the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900" for all variables before returning the id property value of the variable named "PatchGroup".
            Next, the command will delete the site variable with the discovered ID, in the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900". Limited logging output will be written to the host and C:\Temp\log.txt.
        .EXAMPLE
            Remove-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900 -VariableId 12345 -Verbose

            In this example, the command will delete the site variable with ID 12345, in the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900". Verbose logging output is sent to the host only.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [Parameter(Mandatory = $True)]
        [int]$VariableId,

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
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/variable/$VariableId"
            Method      = 'DELETE'
            ContentType = 'application/json'
            Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
        }

        $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Make request.
        $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        Try {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        If ($response.StatusCode -eq 200) {
            $message = ("{0}: Successfully delete the variable(s)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
        } Else {
            $message = ("{0}: Failed to delete the variable(s).`r`nHTTP status code: {1}`r`nHTTP status description: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.StatusCode, $response.StatusDescription)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
} #1.0.0.0
Function Set-AemDeviceUdf {
    <#
        .DESCRIPTION
            Sets the user defined fields of the device.
        .NOTES
            Author: Konstantin Kaminskiy
            V1.0.0.0 date: 5 November 2018
                - Initial release.
            V1.0.0.1 date: 21 November 2018
                - Updated white space.
                - Changed Out-Null to $null.
            V1.0.0.2 date: 5 December 2019
            V1.0.0.3 date: 11 December 2019
            V1.0.0.4 date: 23 June 2020
            V1.0.0.5 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired device.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER UdfData
            A hash table pairing the udfs and their intended values.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            $udfs = @{
                'udf1' = "String One"
                'udf2' = "String Two"
            }
            Set-AemDeviceUDF -AccessToken $token -DeviceUID $deviceUid -UdfData $udfs

            This will set the udfs to the values provided in $udfs.
        .EXAMPLE
            $udfs = Get-AemDevices -AccessToken $token -DeviceId '764402' | Select-Object -ExpandProperty udf
            $newudfs = @{'udf6' = "$($udfs.udf6) - This data should be added"}
            Set-AemDeviceUDF -AccessToken $token -DeviceUid $uid -UdfData $newudfs -Verbose

            This will append to the udfs for the device.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$DeviceUid,

        [Parameter(Mandatory = $True)]
        [hashtable]$UdfData,

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
        # Define parameters for Invoke-WebRequest cmdlet.
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/device/$DeviceUid/udf"
            Method      = 'Post'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
            Body        = ($UdfData | ConvertTo-Json)
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
} #1.0.0.5
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
Function Set-AemSiteVariable {
    <#
        .DESCRIPTION
            Updates one site variable.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 20 January 2022
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER SiteUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired site.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER VariableId
            Represents the ID of the variable to update.
        .PARAMETER Variable
            Represents a hashtable of variable properties, to update.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            $vars = Get-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900
            $varId = $vars.Variables | Where-Object {$_.name -eq 'PatchGroup'} | Select-Object -ExpandProperty id
            Set-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900 -VariableId $varId -Variable @{"name" = "PatchGroup"; "value" = "Alpha"; masked = "false" } -LogPath C:\Temp\log.txt

            In this example, the command will query the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900" for all variables before returning the id property value of the variable named "PatchGroup".
            Next, the command will update the site variable with the discovered ID, with the specified value, in the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900". Limited logging output will be written to the host and C:\Temp\log.txt.
        .EXAMPLE
            Set-AemSiteVariable -AccessToken $token -SiteUid 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900 -VariableId 12345 -Variable @{"name" = "PatchGroup"; "value" = "Alpha"; masked = "false" } -Verbose

            In this example, the command will update the site variable with ID 12345 with the specified value, in the site with UID "9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900". Verbose logging output is sent to the host only.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True)]
        [string]$SiteUid,

        [Parameter(Mandatory = $True)]
        [int]$VariableId,

        [Parameter(Mandatory = $True)]
        [hashtable]$Variable,

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
        $body = $Variable | ConvertTo-Json -Depth 10

        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/site/$SiteUid/variable/$VariableId"
            Method      = 'POST'
            ContentType = 'application/json'
            Headers     = @{ 'Authorization' = 'Bearer {0}' -f $AccessToken }
            Body        = $body
        }

        $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($params | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Make request.
        $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        Try {
            $response = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        If ($response.StatusCode -eq 200) {
            $message = ("{0}: Successfully updated the variable." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }
        } Else {
            $message = ("{0}: Failed to delete the variable(s).`r`nHTTP status code: {1}`r`nHTTP status description: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.StatusCode, $response.StatusDescription)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
} #1.0.0.0
Function Start-AemQuickJob {
    <#
        .DESCRIPTION
            Accepts a device unique ID and a component unique ID to trigger the quick job to run.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 24 October 2019
                - Initial release.
            V1.0.0.1 date: 29 October 2019
            V1.0.0.2 date: 30 October 2019
            V1.0.0.3 date: 5 December 2019
            V1.0.0.4 date: 11 December 2019
            V1.0.0.5 date: 30 June 2020
        .LINK
            https://github.com/wetling23/Public.AEM.PowershellModule
        .PARAMETER AccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceUID
            Represents the UID (31fcea20-3924-c976-0a59-52ec4a2bbf6f) of the desired device.
        .PARAMETER JobName
            Represents the name of the job, once it is created.
        .PARAMETER ComponentGuid
            Unique ID of the component, which will be run. As of 24 October 2019, this value is only available in the UI (on the component definition page), not via the API.
        .PARAMETER Variables
            Optional hashtable of variables (name and value) to pass into the component.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:> Start-AemQuickJob -AccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -DeviceUID 894cc30a-ad10-57f5-82e7-5a3eac72b61f -JobName TestJob -ComponentGuid 377ffb75-9bbc-4c99-9fac-8966292a429b -Verbose

            In this example, the cmdlet will start the generate a new access token and will start a job called "TestJob" to run component with ID 377ffb75-9bbc-4c99-9fac-8966292a429b, on the device with UID 894cc30a-ad10-57f5-82e7-5a3eac72b61f. Verbose output is sent to the host.
        .EXAMPLE
            PS C:> Start-AemQuickJob -AccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -DeviceUID 894cc30a-ad10-57f5-82e7-5a3eac72b61f -JobName TestJob -ComponentGuid 377ffb75-9bbc-4c99-9fac-8966292a429b -Variables @{name='licensekey';value='xxxxx-xxxxx-xxxxx-xxxxx-xxxxx'}

            In this example, the cmdlet will start the generate a new access token and will start a job called "TestJob" to run component with ID 377ffb75-9bbc-4c99-9fac-8966292a429b, on the device with UID 894cc30a-ad10-57f5-82e7-5a3eac72b61f. In this case, the licensekey variable and value are passed to the component.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [Alias("AemAccessToken")]
        [string]$AccessToken,

        [Parameter(Mandatory = $True, ValueFromPipeline)]
        [ValidateScript( {
                try {
                    $null = [System.Guid]::Parse($_)
                    $true
                }
                catch {
                    throw "The value provided for DeviceUID is not formatted properly."
                }
            } )]
        [string]$DeviceUID,

        [Parameter(Mandatory)]
        [string]$JobName,

        [Parameter(Mandatory)]
        [ValidateScript( {
                try {
                    $null = [System.Guid]::Parse($_)
                    $true
                }
                catch {
                    throw "The value provided for ComponentGuid is not formatted properly."
                }
            } )]
        [string]$ComponentGuid,

        [hashtable]$Variables,

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
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        # Initialize variables.
        $inputVariables = @()
        $params = @{
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/device/$DeviceUID/quickjob"
            Method      = 'PUT'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AccessToken }
        }

        $message = ("{0}: Building request body." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

        $apiRequestBody = @{
            jobName      = $JobName
            jobComponent = @{
                componentUid = $ComponentGuid
            }
        }

        If ($Variables) {
            $message = ("{0}: One or more component variables were provided, updating the request body." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            Foreach ($var in $Variables.GetEnumerator()) {
                $message = ("{0}: Adding {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $var.Name)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

                $inputVariables += @{name = $var.Name; value = $var.Value }
            }

            $apiRequestBody.jobComponent.Add('variables', @($inputVariables))
        }

        $params.Add('Body', ($apiRequestBody | ConvertTo-Json -Depth 5))

        Try {
            $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message -BlockStdErr $BlockStdErr } }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: Unexpected error starting the RMM job. To prevent errors, {1} will exit.The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        ($webResponse | ConvertFrom-Json).Job
    }
} #1.0.0.5
