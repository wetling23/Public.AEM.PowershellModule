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

        [string]$EventLogSource,

        [string]$LogPath
    )

    Begin {
        $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
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
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        # Make request.
        $message = ("{0}: Making the web request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Try {
            $null = Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Return "Error"
        }
    }
} #1.0.0.4