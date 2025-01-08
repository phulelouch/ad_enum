<#
.SYNOPSIS
    Finds machines on the local (or specified) domain where the current user 
    (or specified credentials) has local administrator access.

.DESCRIPTION
    This script enumerates one or more target machines (or the entire domain, 
    if no -ComputerName is specified) to see whether the current user has 
    local administrator rights on each. 

    The behavior is mostly the same as the original function 
    Find-LocalAdminAccess, just wrapped in a script so it runs immediately.

.PARAMETER ComputerName
    Specifies an array of one or more hosts to check. If omitted, the script 
    uses Get-DomainComputer to enumerate all domain hosts.

.PARAMETER ComputerDomain
    Specify a different domain to check.

.PARAMETER ComputerLDAPFilter
    LDAP filter used by Get-DomainComputer.

.PARAMETER ComputerSearchBase
    LDAP search base used by Get-DomainComputer.

.PARAMETER ComputerOperatingSystem
    Filter domain computers by operating system.

.PARAMETER ComputerServicePack
    Filter domain computers by service pack.

.PARAMETER ComputerSiteName
    Filter domain computers by site name.

.PARAMETER CheckShareAccess
    Switch. (Currently unused in the logic below; remove or modify as needed.)

.PARAMETER Server
    Specify a domain controller for queries.

.PARAMETER SearchScope
    Specify AD search scope for computers (Base, OneLevel, Subtree).

.PARAMETER ResultPageSize
    Page size for LDAP queries.

.PARAMETER ServerTimeLimit
    Maximum time for the server to spend searching.

.PARAMETER Tombstone
    Include deleted/tombstoned objects.

.PARAMETER Credential
    [Management.Automation.PSCredential] object for alternate user context.

.PARAMETER Delay
    Delay (in seconds) between enumerating hosts.

.PARAMETER Jitter
    Percentage jitter to apply to -Delay (0.0 - 1.0).

.PARAMETER Threads
    Number of threads to use for parallel enumeration.

.EXAMPLE
    .\Find-LocalAdminAccess.ps1

    Enumerates all computers on the current domain and shows which ones 
    the current user can access as a local administrator.

.EXAMPLE
    .\Find-LocalAdminAccess.ps1 -ComputerName PC1,PC2 -Verbose

    Checks only PC1 and PC2 for local admin access.

.EXAMPLE
    $SecPassword = ConvertTo-SecureString 'Password123!' -AsPlainText -Force
    $Cred = New-Object System.Management.Automation.PSCredential('TESTLAB\dfm.a', $SecPassword)
    .\Find-LocalAdminAccess.ps1 -ComputerDomain testlab.local -Credential $Cred

    Checks all machines in the testlab.local domain under the specified alternate credentials.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
[OutputType([String])]
param(
    [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
    [Alias('DNSHostName')]
    [String[]]
    $ComputerName,

    [ValidateNotNullOrEmpty()]
    [String]
    $ComputerDomain,

    [ValidateNotNullOrEmpty()]
    [String]
    $ComputerLDAPFilter,

    [ValidateNotNullOrEmpty()]
    [String]
    $ComputerSearchBase,

    [ValidateNotNullOrEmpty()]
    [Alias('OperatingSystem')]
    [String]
    $ComputerOperatingSystem,

    [ValidateNotNullOrEmpty()]
    [Alias('ServicePack')]
    [String]
    $ComputerServicePack,

    [ValidateNotNullOrEmpty()]
    [Alias('SiteName')]
    [String]
    $ComputerSiteName,

    [Switch]
    $CheckShareAccess,

    [ValidateNotNullOrEmpty()]
    [Alias('DomainController')]
    [String]
    $Server,

    [ValidateSet('Base', 'OneLevel', 'Subtree')]
    [String]
    $SearchScope = 'Subtree',

    [ValidateRange(1, 10000)]
    [Int]
    $ResultPageSize = 200,

    [ValidateRange(1, 10000)]
    [Int]
    $ServerTimeLimit,

    [Switch]
    $Tombstone,

    [Management.Automation.PSCredential]
    [Management.Automation.CredentialAttribute()]
    $Credential = [Management.Automation.PSCredential]::Empty,

    [ValidateRange(1, 10000)]
    [Int]
    $Delay = 0,

    [ValidateRange(0.0, 1.0)]
    [Double]
    $Jitter = .3,

    [Int]
    [ValidateRange(1, 100)]
    $Threads = 20
)

BEGIN {
    # Build up arguments for Get-DomainComputer based on input parameters
    $ComputerSearcherArguments = @{
        'Properties' = 'dnshostname'
    }
    if ($PSBoundParameters['ComputerDomain'])       { $ComputerSearcherArguments['Domain']         = $ComputerDomain }
    if ($PSBoundParameters['ComputerLDAPFilter'])   { $ComputerSearcherArguments['LDAPFilter']     = $ComputerLDAPFilter }
    if ($PSBoundParameters['ComputerSearchBase'])   { $ComputerSearcherArguments['SearchBase']     = $ComputerSearchBase }
    if ($PSBoundParameters['ComputerOperatingSystem']) { $ComputerSearcherArguments['OperatingSystem'] = $ComputerOperatingSystem }
    if ($PSBoundParameters['ComputerServicePack'])  { $ComputerSearcherArguments['ServicePack']    = $ComputerServicePack }
    if ($PSBoundParameters['ComputerSiteName'])     { $ComputerSearcherArguments['SiteName']       = $ComputerSiteName }
    if ($PSBoundParameters['Server'])               { $ComputerSearcherArguments['Server']         = $Server }
    if ($PSBoundParameters['SearchScope'])          { $ComputerSearcherArguments['SearchScope']    = $SearchScope }
    if ($PSBoundParameters['ResultPageSize'])       { $ComputerSearcherArguments['ResultPageSize'] = $ResultPageSize }
    if ($PSBoundParameters['ServerTimeLimit'])      { $ComputerSearcherArguments['ServerTimeLimit']= $ServerTimeLimit }
    if ($PSBoundParameters['Tombstone'])            { $ComputerSearcherArguments['Tombstone']      = $Tombstone }
    if ($PSBoundParameters['Credential'])           { $ComputerSearcherArguments['Credential']     = $Credential }

    # If no explicit ComputerName was provided, enumerate the domain
    if (-not $ComputerName) {
        Write-Verbose '[Find-LocalAdminAccess] Querying computers in the domain...'
        $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
    }
    else {
        $TargetComputers = $ComputerName
    }

    Write-Verbose "[Find-LocalAdminAccess] TargetComputers length: $($TargetComputers.Length)"
    if ($TargetComputers.Length -eq 0) {
        throw '[Find-LocalAdminAccess] No hosts found to enumerate.'
    }

    # The scriptblock that will be run locally (or in threads) to check each host
    $HostEnumBlock = {
        Param($ComputerName, $TokenHandle)

        if ($TokenHandle) {
            # Impersonate the token produced by LogonUser()/Invoke-UserImpersonation
            $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
        }

        ForEach ($TargetComputer in $ComputerName) {
            # Quick up check:
            $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
            if ($Up) {
                $Access = Test-AdminAccess -ComputerName $TargetComputer
                if ($Access.IsAdmin) {
                    # If admin, simply output the hostname
                    $TargetComputer
                }
            }
        }

        if ($TokenHandle) {
            Invoke-RevertToSelf
        }
    }

    # If credentials are specified, do an impersonation upfront
    $LogonToken = $Null
    if ($PSBoundParameters['Credential']) {
        # Decide on Quiet or not based on Delay usage
        if ($Delay) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
        else {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
        }
    }
}

PROCESS {
    # If a delay is specified, process each host in a loop to respect that delay
    if ($Delay) {
        Write-Verbose "[Find-LocalAdminAccess] Total number of hosts: $($TargetComputers.count)"
        Write-Verbose "[Find-LocalAdminAccess] Delay: $Delay, Jitter: $Jitter"
        $Counter = 0
        $RandNo  = New-Object System.Random

        ForEach ($TargetComputer in $TargetComputers) {
            $Counter++
            # Sleep for a semi-random interval around $Delay * (1 +/- $Jitter)
            $SleepTime = $RandNo.Next((1 - $Jitter) * $Delay, (1 + $Jitter) * $Delay)
            Start-Sleep -Seconds $SleepTime

            Write-Verbose "[Find-LocalAdminAccess] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count))"
            Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $LogonToken
        }
    }
    else {
        # Otherwise, use threading for speed
        Write-Verbose "[Find-LocalAdminAccess] Using threading with threads: $Threads"

        $ScriptParams = @{
            'TokenHandle' = $LogonToken
        }
        New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock `
            -ScriptParameters $ScriptParams -Threads $Threads
    }
}

END {
    if ($LogonToken) {
        Invoke-RevertToSelf
    }
}
