# =============================================================================
# 70-net.ps1 - Network tools
#
# WHAT THIS GIVES YOU
#     myip                       -> your local IPv4 addresses
#     publicip                   -> what the internet sees you as
#                                   (calls api.ipify.org only when run)
#     portcheck <host> <port>    -> is that port reachable? (with timeout)
#     listening                  -> what TCP ports this PC is listening on
#                                   and which process owns each
#     dig <name> [-Type A|MX...] -> DNS lookup
#     netinfo                    -> physical network adapters
#
#   None of these "phone home" automatically - they only run when you type
#   the command.
# =============================================================================

# Local IPv4 addresses (excluding loopback / APIPA).
function Global:myip {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
        Select-Object InterfaceAlias, IPAddress, PrefixLength
}

# Public IP — explicit network call.
function Global:publicip {
    try {
        (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5).ip
    } catch {
        Write-Warning "publicip: $_"
    }
}

# Port check — TCP probe with timeout.
function Global:portcheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Host_,
        [Parameter(Mandatory)][int]$Port,
        [int]$TimeoutMs = 2000
    )
    $tcp = [System.Net.Sockets.TcpClient]::new()
    try {
        $iar = $tcp.BeginConnect($Host_, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            $tcp.EndConnect($iar) | Out-Null
            [pscustomobject]@{ Host = $Host_; Port = $Port; Open = $true }
        } else {
            [pscustomobject]@{ Host = $Host_; Port = $Port; Open = $false }
        }
    } catch {
        [pscustomobject]@{ Host = $Host_; Port = $Port; Open = $false; Error = $_.Exception.Message }
    } finally { $tcp.Close() }
}

# Listening ports on this machine.
function Global:listening {
    Get-NetTCPConnection -State Listen |
        Sort-Object LocalPort -Unique |
        Select-Object @{n='Port';e={$_.LocalPort}},
                      @{n='Address';e={$_.LocalAddress}},
                      @{n='Process';e={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}},
                      @{n='PID';e={$_.OwningProcess}}
}

# DNS lookup wrapper.
function Global:dig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [string]$Type = 'A')
    Resolve-DnsName -Name $Name -Type $Type -ErrorAction SilentlyContinue
}

# Network speed of active adapter.
function Global:netinfo {
    Get-NetAdapter -Physical | Where-Object Status -eq 'Up' |
        Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress
}
