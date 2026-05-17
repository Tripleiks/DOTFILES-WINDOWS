# =============================================================================
# 90-deferred.ps1 - Slow extras that load AFTER the first prompt
#
# WHY THIS EXISTS
#   Some modules (Terminal-Icons, posh-git, PSFzf) and tab-completions
#   (gh, winget, dotnet, scoop, chocolatey) take noticeable time to load.
#   If we loaded them on startup, every new PowerShell window would feel
#   sluggish. So we queue them here and run them on the FIRST prompt -
#   the shell appears instantly, and the extras finish loading silently
#   before you finish typing your first command.
#
# HOW IT WORKS
#   We wrap the prompt function. The first time it runs, it triggers all
#   the deferred work. After that, the wrapper is essentially a no-op
#   (one boolean check per prompt).
# =============================================================================

# Queue the standard deferred work.
Register-DeferredLoad {
    if (Get-Module -ListAvailable Terminal-Icons -ErrorAction SilentlyContinue) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    }
}

Register-DeferredLoad {
    if (Get-Module -ListAvailable posh-git -ErrorAction SilentlyContinue) {
        Import-Module posh-git -ErrorAction SilentlyContinue
    }
}

Register-DeferredLoad {
    if (Get-Module -ListAvailable PSFzf -ErrorAction SilentlyContinue) {
        try {
            Import-Module PSFzf -ErrorAction Stop
            # Ctrl+T = file picker, Ctrl+R = history picker.
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction SilentlyContinue
        } catch {}
    }
}

# Tab-completions for popular CLIs. Each block is independently guarded.
Register-DeferredLoad {
    if (Test-Command 'gh') {
        try { gh completion -s powershell 2>$null | Out-String | Invoke-Expression } catch {}
    }
}

Register-DeferredLoad {
    if (Test-Command 'winget') {
        Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
            $Local:word = $wordToComplete.Replace('"', '""')
            $Local:ast  = $commandAst.ToString().Replace('"', '""')
            winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
}

Register-DeferredLoad {
    if (Test-Command 'dotnet') {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            dotnet complete --position $cursorPosition $commandAst.ToString() |
                ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
        }
    }
}

Register-DeferredLoad {
    if (Test-Command 'scoop') {
        $scoopCompletion = Join-Path (Split-Path (Get-Command scoop).Source -Parent) '..\modules\scoop-completion\scoop-completion.psm1'
        if (Test-Path $scoopCompletion) {
            Import-Module $scoopCompletion -ErrorAction SilentlyContinue
        }
    }
}

# Chocolatey tab completion (a common Windows package manager).
Register-DeferredLoad {
    $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if ($env:ChocolateyInstall -and (Test-Path $ChocolateyProfile)) {
        Import-Module $ChocolateyProfile -ErrorAction SilentlyContinue
    }
}

# Wrap the current prompt to flush deferred actions on its first invocation.
# After flushing, the wrapper stays in place but is effectively a no-op around
# the inner prompt. Per-prompt overhead is one bool check.
$Global:__DeferredFlushed = $false
$Global:__PromptInner     = $function:prompt
function Global:prompt {
    if (-not $Global:__DeferredFlushed) {
        $Global:__DeferredFlushed = $true
        foreach ($action in $Global:__DeferredActions) {
            try { & $action } catch {
                $Global:ProfileLoadErrors += [pscustomobject]@{
                    Module  = 'deferred'
                    Message = $_.Exception.Message
                }
            }
        }
    }
    & $Global:__PromptInner
}
