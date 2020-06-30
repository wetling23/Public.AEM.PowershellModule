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