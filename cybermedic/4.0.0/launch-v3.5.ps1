# CyberMedic v3.5 - Launcher Selettore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "CyberMedic Launcher v3.5"
$form.Size = New-Object System.Drawing.Size(420, 260)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 40)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Seleziona la modalita' di avvio:"
$label.Location = New-Object System.Drawing.Point(25, 25)
$label.Size = New-Object System.Drawing.Size(360, 30)
$label.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

$btnWinUI = New-Object System.Windows.Forms.Button
$btnWinUI.Text = "Versione Installer"
$btnWinUI.Location = New-Object System.Drawing.Point(25, 70)
$btnWinUI.Size = New-Object System.Drawing.Size(350, 45)
$btnWinUI.BackColor = [System.Drawing.Color]::FromArgb(179, 136, 255)
$btnWinUI.ForeColor = [System.Drawing.Color]::Black
$btnWinUI.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnWinUI.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnWinUI.Add_Click({ $form.Tag = "WinUI3"; $form.Close() })
$form.Controls.Add($btnWinUI)

$btnPortable = New-Object System.Windows.Forms.Button
$btnPortable.Text = "Versione Portatile"
$btnPortable.Location = New-Object System.Drawing.Point(25, 130)
$btnPortable.Size = New-Object System.Drawing.Size(350, 45)
$btnPortable.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 65)
$btnPortable.ForeColor = [System.Drawing.Color]::White
$btnPortable.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnPortable.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnPortable.Add_Click({ $form.Tag = "Portable"; $form.Close() })
$form.Controls.Add($btnPortable)

[void]$form.ShowDialog()

$root = $PSScriptRoot
if ($form.Tag -eq "WinUI3") {
    $exePath = Join-Path $root "winui3\CyberMedic.WinUI\bin\Debug\net8.0-windows10.0.19041.0\CyberMedic.WinUI.exe"
    if (Test-Path $exePath) {
        Write-Host "Avvio di CyberMedic WinUI 3 in corso..." -ForegroundColor Green
        Start-Process -FilePath $exePath
    } else {
        [System.Windows.Forms.MessageBox]::Show("Eseguibile WinUI 3 non trovato nel percorso di build!", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
} elseif ($form.Tag -eq "Portable") {
    Write-Host "Avvio della versione portatile PowerShell..." -ForegroundColor Cyan
    $gui = Join-Path $root "CyberMedic_GUI.ps1"
    if (Test-Path $gui) {
        & "powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -File $gui
    } else {
        [System.Windows.Forms.MessageBox]::Show("CyberMedic_GUI.ps1 non trovato!", "Errore", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}
