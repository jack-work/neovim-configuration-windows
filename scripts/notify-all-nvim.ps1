# Send notification to all running Neovim instances
# Usage: .\notify-all-nvim.ps1 "Your message here"

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [ValidateSet("INFO", "WARN", "ERROR")]
    [string]$Level = "INFO"
)

$levelMap = @{
    "INFO" = "vim.log.levels.INFO"
    "WARN" = "vim.log.levels.WARN"
    "ERROR" = "vim.log.levels.ERROR"
}

# Find all neovim server pipes (format: nvim.<PID>.0)
$pipes = Get-ChildItem '//./pipe/' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^nvim\.\d+\.0$' } |
    Select-Object -ExpandProperty Name

if (-not $pipes) {
    Write-Host "No running Neovim instances found"
    exit 1
}

$escapedMessage = $Message -replace "'", "''"
$luaCmd = "vim.notify('$escapedMessage', $($levelMap[$Level]))"

$count = 0
foreach ($pipe in $pipes) {
    $serverAddr = "\\.\pipe\$pipe"
    try {
        # Use --remote-expr to execute lua (redirect all output to suppress terminal noise)
        $null = nvim --server $serverAddr --remote-expr "luaeval(""vim.notify('$escapedMessage', $($levelMap[$Level]))"")" 2>&1
        $count++
        Write-Host "Notified: $pipe"
    } catch {
        Write-Host "Failed to notify: $pipe"
    }
}

Write-Host "Sent notification to $count Neovim instance(s)"
