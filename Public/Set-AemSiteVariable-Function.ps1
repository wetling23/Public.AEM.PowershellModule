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