Function Set-AemDeviceUDF {
    <#
        .DESCRIPTION
            Sets or appends to the user defined feilds of the device 
        .NOTES 
            Author: Konstantin Kaminskiy
            V1.0.0.0 date: 5 November 2018
                - Initial release.
        .PARAMETER AemAccessToken
            Mandatory parameter. Represents the token returned once successful authentication to the API is achieved. Use New-AemApiAccessToken to obtain the token.
        .PARAMETER DeviceUid
            Represents the UID number (e.g. 9fd7io7a-fe95-44k0-9cd1-fcc0vcbc7900) of the desired device.
        .PARAMETER ApiUrl
            Default value is 'https://zinfandel-api.centrastage.net'. Represents the URL to AutoTask's AEM API, for the desired instance.
        .PARAMETER EventLogSource
            Default value is 'AemPowerShellModule'. This parameter is used to specify the event source, that script/modules will use for logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .PARAMETER UdfData
            A hash table pairing the udfs and their intended values.
        .EXAMPLE
            $udfs = @{
                'udf1' = "String One"
                'udf2' = "String Two"
            }
            Set-AemDeviceUDF -AemAccessToken $token -DeviceUID $deviceUid -UdfData $udfs
            This will set the udfs to the values provided in $udfs.
        .EXAMPLE
            $udfs = Get-AemDevices -AemAccessToken $token -DeviceId '764402' | Select-Object -ExpandProperty udf
            $newudfs = @{'udf6' = "$($udfs.udf6) - This data should be added"}
            Set-AemDeviceUDF -AemAccessToken $token -DeviceUid $uid -UdfData $newudfs -Verbose
            This will append to the udfs for the device. 
            
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)]
        [string]$AemAccessToken,

        [Parameter(Mandatory = $True)]
        [string]$DeviceUid,

        [Parameter(Mandatory = $True)]
        [hashtable]$UdfData,

        [string]$ApiUrl = 'https://zinfandel-api.centrastage.net',

        [string]$EventLogSource = 'AemPowerShellModule',

        [switch]$BlockLogging
    )

    Begin {
        If (-NOT($BlockLogging)) {
            $return = Add-EventLogSource -EventLogSource $EventLogSource
    
            If ($return -ne "Success") {
                $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
                Write-Host $message -ForegroundColor Yellow;

                $BlockLogging = $True
            }
        }

        $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
    }

    Process {    
    # Define parameters for Invoke-WebRequest cmdlet.
    $params = @{
        Uri         = '{0}/api{1}' -f $ApiUrl, "/v2/device/$DeviceUid/udf"
        Method      = 'Post'
        ContentType = 'application/json'
        Headers     = @{'Authorization' = 'Bearer {0}' -f $AemAccessToken}
        Body        = ($UdfData | ConvertTo-Json)
    }

    $message = ("{0}: Updated `$params hash table. The values are:`n{1}." -f (Get-Date -Format s), (($params | Out-String) -split "`n"))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}
            

        # Make request.
        $message = ("{0}: Making the web request." -f (Get-Date -Format s), $MyInvocation.MyCommand)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        Try {
            Invoke-WebRequest @params -UseBasicParsing -ErrorAction Stop | Out-Null
        }
        Catch {
            $message = ("{0}: It appears that the web request failed. Check your credentials and try again. To prevent errors, {1} will exit. The specific error message is: {2}" `
                    -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
            If ($BlockLogging) {Write-Host $message -ForegroundColor Red} Else {Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

            Return "Error"
        }

    }
} #1.0.0.0