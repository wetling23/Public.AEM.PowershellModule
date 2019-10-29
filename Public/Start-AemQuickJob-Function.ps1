Function Start-AemQuickJob {
    <#
        .DESCRIPTION
            Accepts a device unique ID and a component unique ID to trigger the quick job to run.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 24 October 2019
                - Initial release.
        .PARAMETER AemAccessToken
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
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:> Start-AemQuickJob -AemAccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -DeviceUID 894cc30a-ad10-57f5-82e7-5a3eac72b61f -JobName TestJob -ComponentGuid 377ffb75-9bbc-4c99-9fac-8966292a429b

            In this example, the cmdlet will start the generate a new access token and will start a job called "TestJob" to run component with ID 377ffb75-9bbc-4c99-9fac-8966292a429b, on the device with UID 894cc30a-ad10-57f5-82e7-5a3eac72b61f.

        .EXAMPLE
            PS C:> Start-AemQuickJob -AemAccessToken (New-AemApiAccessToken -ApiKey <api public key> -ApiUrl <api private key>) -DeviceUID 894cc30a-ad10-57f5-82e7-5a3eac72b61f -JobName TestJob -ComponentGuid 377ffb75-9bbc-4c99-9fac-8966292a429b -Variables @{name='licensekey';value='xxxxx-xxxxx-xxxxx-xxxxx-xxxxx'}

            In this example, the cmdlet will start the generate a new access token and will start a job called "TestJob" to run component with ID 377ffb75-9bbc-4c99-9fac-8966292a429b, on the device with UID 894cc30a-ad10-57f5-82e7-5a3eac72b61f. In this case, the licensekey variable and value are passed to the component.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string]$AemAccessToken,

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
            Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/device/$DeviceUID/quickjob"
            Method      = 'PUT'
            ContentType = 'application/json'
            Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken }
        }

        $message = ("{0}: Building request body." -f [datetime]::Now)
        If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $apiRequestBody = @{
            jobName      = $JobName
            jobComponent = @{
                componentUid = $ComponentGuid
            }
        }

        If ($Variables) {
            $message = ("{0}: One or more component variables were provided, updating the request body." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $apiRequestBody.jobComponent.Add('variables', @($Variables))
        }

        $params.Add('Body', ($apiRequestBody | ConvertTo-Json -Depth 5))

        Try {
            $message = ("{0}: Making the web request." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $webResponse = (Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop).Content
        }
        Catch {
            $message = ("{0}: Unexpected error starting the RMM job. To prevent errors, {1} will exit.The specific error is: {2}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

            Return "Error"
        }

        ($webResponse | ConvertFrom-Json).Job
    }
} #1.0.0.0