#requires -Version 5.1
<#
.SYNOPSIS
Share a local HTTP/mixed proxy with a Linux server through SSH.
.EXAMPLE
.\pp.ps1 root@192.168.1.14
.EXAMPLE
.\pp.ps1 user@server -LocalPort 7897 -RemotePort 17898 -SshPort 22
.EXAMPLE
.\pp.ps1 root@192.168.1.14 -RemoteCommand 'curl -I https://example.com'
.NOTES
Keep this window open. Proxy variables apply only to this SSH shell and its
children. Other sessions and system services need their own proxy settings.
The local proxy must support HTTP CONNECT (Clash mixed-port is supported).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-zA-Z0-9_][a-zA-Z0-9_.@:\[\]-]*$')]
    [string]$Server,

    [ValidateRange(0, 65535)]
    [int]$LocalPort = 0,

    [ValidateRange(1, 65535)]
    [int]$RemotePort = 17897,

    [ValidateRange(1, 65535)]
    [int]$SshPort = 22,

    [string]$RemoteCommand
)

$ErrorActionPreference = 'Stop'

function Test-LocalPort([int]$Port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $Port)
        return ($task.Wait(500) -and $client.Connected)
    }
    catch { return $false }
    finally { $client.Dispose() }
}

try {
    $ssh = Get-Command ssh.exe -CommandType Application -ErrorAction Stop
    if ($LocalPort -eq 0) {
        foreach ($candidate in @(7897, 7890, 10809, 1080, 8080, 8888)) {
            if (Test-LocalPort $candidate) {
                $LocalPort = $candidate
                break
            }
        }
        if ($LocalPort -eq 0) {
            throw 'No local proxy port found. Start your proxy or specify -LocalPort.'
        }
    }
    elseif (-not (Test-LocalPort $LocalPort)) {
        throw "Nothing is listening on 127.0.0.1:$LocalPort."
    }

    $proxyUrl = "http://127.0.0.1:$RemotePort"
    $remoteScript = @"
unset IFS
export http_proxy='$proxyUrl' https_proxy='$proxyUrl'
export HTTP_PROXY='$proxyUrl' HTTPS_PROXY='$proxyUrl'
export all_proxy='$proxyUrl' ALL_PROXY='$proxyUrl'
export no_proxy='localhost,127.0.0.1,::1' NO_PROXY='localhost,127.0.0.1,::1'
"@
    if ($PSBoundParameters.ContainsKey('RemoteCommand')) {
        $remoteScript += "`n" + $RemoteCommand + "`n"
    }
    else {
        $remoteScript += @'

printf '\nProxy ready: %s\nExit this shell to close the tunnel.\n\n' "$https_proxy"
exec "${SHELL:-/bin/sh}" -l
'@
    }
    # Base64 avoids nested Windows/SSH/POSIX quoting and preserves command text.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript.Replace("`r`n", "`n")))
    # Empty IFS keeps the decoded script in one argument without double quotes,
    # which Windows PowerShell 5.1 would otherwise strip for native programs.
    # eval restores shell syntax; the first decoded line restores normal IFS.
    $remote = "IFS=; eval `$(printf %s $encoded | base64 -d)"
    $sshArgs = @(
        '-p', "$SshPort",
        '-o', 'ExitOnForwardFailure=yes',
        '-o', 'ServerAliveInterval=30',
        '-o', 'ServerAliveCountMax=3',
        '-R', "127.0.0.1:${RemotePort}:127.0.0.1:$LocalPort"
    )
    if (-not $PSBoundParameters.ContainsKey('RemoteCommand')) { $sshArgs += '-t' }
    $sshArgs += @($Server, $remote)
    Write-Host "Proxy: local 127.0.0.1:$LocalPort -> $Server 127.0.0.1:$RemotePort"
    Write-Host 'If the remote port is occupied, choose another with -RemotePort.'
    & $ssh.Source @sshArgs
    exit $LASTEXITCODE
}
catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
