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