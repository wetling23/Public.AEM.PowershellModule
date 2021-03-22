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