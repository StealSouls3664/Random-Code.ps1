# ============================================================
#  COOL POWERSHELL SHOWCASE
#  Safe & read-only: no settings changed, nothing deleted.
#  Run in Windows PowerShell 5.1 or PowerShell 7+ (Windows).
#  If scripts are blocked, run it for this session only with:
#     powershell -ExecutionPolicy Bypass -File .\cool-powershell.ps1
# ============================================================

function Section($title) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
    Write-Host "  $title" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
}

# ---------- 1. BANNER ----------
Clear-Host
$colors = 'Red','Yellow','Green','Cyan','Blue','Magenta'
$text = "  P O W E R S H E L L   S H O W C A S E  "
$i = 0
foreach ($ch in $text.ToCharArray()) {
    Write-Host $ch -NoNewline -ForegroundColor $colors[$i % $colors.Count]
    $i++
    Start-Sleep -Milliseconds 25
}
Write-Host ""

# ---------- 2. SYSTEM SNAPSHOT ----------
Section "SYSTEM SNAPSHOT"
Write-Host "Computer name : $env:COMPUTERNAME"
Write-Host "User          : $env:USERNAME"
Write-Host "PowerShell    : $($PSVersionTable.PSVersion)"
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
Write-Host ("Uptime        : {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes) -ForegroundColor Green
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
Write-Host "RAM           : $freeGB GB free of $totalGB GB"
Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate | Format-List
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion | Format-List

# ---------- 3. PROCESSES ----------
Section "TOP 5 PROCESSES BY CPU TIME"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, Id, @{n='CPU(s)';e={[math]::Round($_.CPU,1)}} | Format-Table -AutoSize

Section "TOP 5 PROCESSES BY MEMORY"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 Name, Id, @{n='MB';e={[math]::Round($_.WorkingSet64/1MB)}} | Format-Table -AutoSize

Section "PROCESS COUNT & SERVICES"
Write-Host "Running processes : $((Get-Process).Count)"
Write-Host "Running services  : $((Get-Service | Where-Object Status -eq 'Running').Count)"
Write-Host "Stopped services  : $((Get-Service | Where-Object Status -eq 'Stopped').Count)"

# ---------- 4. DISKS ----------
Section "DISK USAGE"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
    $total = $_.Used + $_.Free
    $pct = if ($total -gt 0) { [math]::Round(($_.Used / $total) * 100) } else { 0 }
    $bar = ('#' * [math]::Floor($pct / 5)).PadRight(20, '-')
    "{0,-3} [{1}] {2}% used ({3} GB free)" -f $_.Name, $bar, $pct, [math]::Round($_.Free/1GB,1)
}

# ---------- 5. NETWORK ----------
Section "NETWORK"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' } |
    Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, LinkSpeed, MacAddress | Format-Table -AutoSize
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize
try { Write-Host "Public IP : $(Invoke-RestMethod https://api.ipify.org -TimeoutSec 5)" -ForegroundColor Green } catch { Write-Host "Public IP : (offline?)" }
Resolve-DnsName example.com -ErrorAction SilentlyContinue | Select-Object -First 3 Name, Type, IPAddress | Format-Table -AutoSize
Test-Connection 1.1.1.1 -Count 3 -ErrorAction SilentlyContinue | Select-Object Address, @{n='ms';e={ if ($_.ResponseTime) { $_.ResponseTime } else { $_.Latency } }} | Format-Table -AutoSize
Test-NetConnection google.com -Port 443 -WarningAction SilentlyContinue | Select-Object ComputerName, RemotePort, TcpTestSucceeded | Format-Table -AutoSize
Write-Host "Active TCP connections: $((Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue).Count)"
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -First 5 LocalPort, OwningProcess | Format-Table -AutoSize

# ---------- 6. WEATHER ----------
Section "WEATHER (via wttr.in)"
try { Invoke-RestMethod "https://wttr.in/?format=3" -TimeoutSec 5 } catch { Write-Host "Weather unavailable." }

# ---------- 7. BATTERY / HARDWARE ----------
Section "BATTERY & HARDWARE"
$bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if ($bat) { Write-Host "Battery: $($bat.EstimatedChargeRemaining)%" } else { Write-Host "No battery detected (desktop?)" }
Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, @{n='GB';e={$_.Capacity/1GB}}, Speed | Format-Table -AutoSize
Get-PnpDevice -PresentOnly -Class Monitor -ErrorAction SilentlyContinue | Select-Object FriendlyName | Format-Table -AutoSize

# ---------- 8. FILES ----------
Section "10 LARGEST FILES IN YOUR DOCUMENTS"
Get-ChildItem "$HOME\Documents" -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending | Select-Object -First 10 @{n='MB';e={[math]::Round($_.Length/1MB,1)}}, Name | Format-Table -AutoSize

Section "FILE TYPES IN DOWNLOADS"
Get-ChildItem "$HOME\Downloads" -File -ErrorAction SilentlyContinue |
    Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 8 Count, Name | Format-Table -AutoSize

Section "FILES MODIFIED IN THE LAST 24 HOURS (Desktop)"
Get-ChildItem "$HOME\Desktop" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object LastWriteTime -gt (Get-Date).AddDays(-1) | Select-Object Name, LastWriteTime | Format-Table -AutoSize

# ---------- 9. INSTALLED SOFTWARE & STARTUP ----------
Section "INSTALLED SOFTWARE (first 15)"
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
    Where-Object DisplayName | Sort-Object DisplayName | Select-Object -First 15 DisplayName, DisplayVersion | Format-Table -AutoSize

Section "STARTUP PROGRAMS"
Get-CimInstance Win32_StartupCommand | Select-Object Name, Location | Format-Table -AutoSize

Section "SCHEDULED TASKS (ready, first 10)"
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object State -eq 'Ready' | Select-Object -First 10 TaskName | Format-Table -AutoSize

# ---------- 10. EVENT LOGS ----------
Section "LAST 5 SYSTEM ERRORS"
Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 5 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, ProviderName, @{n='Message';e={($_.Message -split "`n")[0]}} | Format-Table -AutoSize -Wrap

# ---------- 11. MATH & DATA FUN ----------
Section "MATH PLAYGROUND"
Write-Host "Fibonacci (first 15): " -NoNewline
$a,$b = 0,1; (1..15 | ForEach-Object { $a; $a,$b = $b,($a+$b) }) -join ', '
Write-Host "Primes under 60     : " -NoNewline
(2..60 | Where-Object { $n=$_; -not (2..[math]::Sqrt($n) | Where-Object { $n % $_ -eq 0 }) -or $n -eq 2 }) -join ', '
$fact = [bigint]1; foreach ($n in 1..15) { $fact *= $n }
Write-Host "Factorial of 15     : $fact"
Write-Host "2 to the power 100  : $([bigint]::Pow(2,100))"
Write-Host "Pi                  : $([math]::PI)"
Write-Host "Square root of 2    : $([math]::Sqrt(2))"
Write-Host "Sum 1..100          : $((1..100 | Measure-Object -Sum).Sum)"

Section "RANDOM STUFF"
Write-Host "Dice roll      : $(Get-Random -Minimum 1 -Maximum 7)"
Write-Host "Coin flip      : $(('Heads','Tails') | Get-Random)"
Write-Host "Lottery picks  : $((1..49 | Get-Random -Count 6 | Sort-Object) -join ' - ')"
Write-Host "Magic 8-ball   : $(('It is certain','Ask again later','Very doubtful','Signs point to yes','Cannot predict now','Outlook good') | Get-Random)"
Write-Host "New GUID       : $([guid]::NewGuid())"
$chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%'
Write-Host "Random password: $(-join (1..20 | ForEach-Object { $chars | Get-Random }))"

# ---------- 12. TEXT & ENCODING ----------
Section "TEXT TRICKS"
$msg = "PowerShell is awesome"
Write-Host "Original   : $msg"
Write-Host "Upper      : $($msg.ToUpper())"
Write-Host "Reversed   : $(-join $msg[-1..-($msg.Length)])"
Write-Host "Word count : $(($msg -split ' ').Count)"
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($msg))
Write-Host "Base64     : $b64"
Write-Host "Decoded    : $([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)))"
$sha = [Security.Cryptography.SHA256]::Create()
Write-Host "SHA-256    : $(([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($msg)))) -replace '-','')"
Write-Host "Morse-ish  : $(($msg.ToCharArray() | ForEach-Object { [int]$_ }) -join ' ')"

Section "DATE & TIME"
$now = Get-Date
Write-Host "Now              : $now"
Write-Host "Day of week      : $($now.DayOfWeek)"
Write-Host "Day of year      : $($now.DayOfYear)"
Write-Host "Days until Jan 1 : $([math]::Ceiling(((Get-Date -Year ($now.Year+1) -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0) - $now).TotalDays))"
Write-Host "UTC time         : $($now.ToUniversalTime())"
Write-Host "Time zone        : $((Get-TimeZone).DisplayName)"
Write-Host "Unix timestamp   : $([DateTimeOffset]::Now.ToUnixTimeSeconds())"

# ---------- 13. DATA FORMATS ----------
Section "JSON / CSV DEMO"
$data = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 3 Name, Id
$data | ConvertTo-Json -Compress
$data | ConvertTo-Csv -NoTypeInformation
$data | ConvertTo-Html -Fragment | Select-Object -First 4

# ---------- 14. BENCHMARK ----------
Section "MINI BENCHMARK"
$t = Measure-Command { 1..200000 | ForEach-Object { $_ * 2 } | Out-Null }
Write-Host "200,000 loop iterations took $([math]::Round($t.TotalMilliseconds)) ms" -ForegroundColor Green

# ---------- 15. VISUAL FUN ----------
Section "PROGRESS BAR"
foreach ($p in 0..100) {
    Write-Progress -Activity "Reticulating splines" -Status "$p%" -PercentComplete $p
    Start-Sleep -Milliseconds 15
}
Write-Progress -Activity "Reticulating splines" -Completed

Section "ASCII ROCKET"
$rocket = @'
      /\
     /  \
    |    |
    | PS |
    |    |
   /|    |\
  / |____| \
    /_||_\
     (  )
      ''
'@
Write-Host $rocket -ForegroundColor Cyan

Section "SINE WAVE"
foreach ($x in 0..40) {
    $pos = [math]::Round(20 + 18 * [math]::Sin($x / 3))
    (' ' * $pos) + '*'
}

Section "RAINBOW GRADIENT BAR"
$grad = 'Red','DarkYellow','Yellow','Green','Cyan','Blue','Magenta'
foreach ($c in $grad) { Write-Host ("█" * 8) -NoNewline -ForegroundColor $c }
Write-Host ""

Section "MATRIX RAIN (3 seconds)"
$width = [math]::Min($Host.UI.RawUI.WindowSize.Width, 80)
$end = (Get-Date).AddSeconds(3)
while ((Get-Date) -lt $end) {
    $line = -join (1..$width | ForEach-Object { if ((Get-Random -Max 4) -eq 0) { [char](Get-Random -Min 33 -Max 126) } else { ' ' } })
    Write-Host $line -ForegroundColor Green
    Start-Sleep -Milliseconds 40
}

Section "COUNTDOWN"
foreach ($n in 5..1) { Write-Host "$n..." -ForegroundColor Magenta; Start-Sleep -Milliseconds 400 }
Write-Host "LIFTOFF!" -ForegroundColor Red

# ---------- 16. SOUND & SPEECH ----------
Section "SOUND & SPEECH"
try {
    Add-Type -AssemblyName System.Speech
    $speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $speaker.Rate = 1
    Write-Host "Speaking: 'Hello from PowerShell. Your computer is ready.'"
    $speaker.Speak("Hello from PowerShell. Your computer is ready.")
} catch { Write-Host "Speech not available." }
try {
    # little ascending melody
    foreach ($f in 523,587,659,698,784) { [Console]::Beep($f, 150) }
} catch { Write-Host "Beep not available." }

# ---------- 17. GUI TOUCHES ----------
Section "GUI TOUCHES"
Start-Process calc.exe
Start-Sleep -Seconds 2
Get-Process -Name CalculatorApp, calc, Calculator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "Opened and closed the Calculator."
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.MessageBox]::Show("Showcase complete! ✨", "PowerShell", 'OK', 'Information')

# ---------- DONE ----------
Section "ALL DONE"
Write-Host "Finished at $(Get-Date -Format 'HH:mm:ss'). Have fun exploring!" -ForegroundColor Green
