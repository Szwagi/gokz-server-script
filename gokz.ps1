# The directory steamcmd and the server will be installed to.
# It is not recommended to reuse steamcmd from older installations of a CSGO server,
# as that may overwrite your configs, or not work at all in some cases.
# For example, set this to:
# $steamCmdDir = "C:\steamcmd"
$steamCmdDir = "C:\steamcmd"

# Set this to the path of your game's CSGO folder if you want your maps/models/materials/sound/scripts folders to be
# symlinked to the server, this is useful when mapping. MAKE SURE TO INCLUDE THE 'csgo' DIRECTORY!!!
# For example, set this to:
# $gameDir = "C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\csgo"
$gameDir = ""

# The map the server will run at startup.
# Make sure this map is in the maps folder, or the server will fail to start.
# For example, set this to:
# $startMap = "kz_beginnerblock_go"
$startMap = ""

# =======================================

$ErrorActionPreference = "Stop"
$global:ProgressPreference = "SilentlyContinue"

# You can remove this 'if' block after you've ran it for the first time, so you don't get the UAC prompts every time.
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; 
    exit 
}

if (-Not (Test-Path -Path $steamCmdDir)) {
    New-Item -Path $steamCmdDir -ItemType Directory | Out-Null
}
Set-Location -Path $steamCmdDir

if (-Not (Test-Path -Path $steamCmdDir\steamcmd.exe)) {
    Invoke-WebRequest -Uri "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -OutFile "steamcmd.zip"
    Expand-Archive -Path "steamcmd.zip" -DestinationPath "."
    Remove-Item -Path "steamcmd.zip"
}

Write-Output "Updating the server"
$steamcmdArgList = @("+@ShutdownOnFailedCommand", "1")
$steamcmdArgList += @("+@NoPromptForPassword", "1")
$steamcmdArgList += @("+login", "anonymous")
$steamcmdArgList += @("+app_update", "740")
$steamcmdArgList += @("+quit")
Start-Process steamcmd.exe -Wait -ArgumentList $steamcmdArgList

$srcdsDir = "$steamCmdDir\\steamapps\\common\\Counter-Strike Global Offensive Beta - Dedicated Server"
$csgoDir = "$srcdsDir\\csgo"

if ($gameDir.Length -gt 0) {
    $foldersToSymlink = @("maps", "models", "materials", "sound", "scripts")
    foreach ($it in $foldersToSymlink) {
        if (Test-Path -Path "$csgoDir\\$it") {
            $file = Get-Item -Path "$csgoDir\\$it" -Force
            if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $file.Delete()
            }
            else {
                Remove-Item -Path "$csgoDir\\$it" -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        New-Item -ItemType SymbolicLink -Path "$csgoDir\\$it" -Target "$gameDir\\$it" -Force | Out-Null
    }
}

$downloadDir = "$steamCmdDir\\gokz-script-downloads"
if (-Not (Test-Path -Path $downloadDir)) {
    New-Item -Path $downloadDir -ItemType Directory | Out-Null
}
Set-Location -Path $downloadDir

$metamodVersion = "1.11"
$metamodLatest = Invoke-WebRequest -Uri "https://mms.alliedmods.net/mmsdrop/$metamodVersion/mmsource-latest-windows" -UseBasicParsing
$metamodLatestUrl = "https://mms.alliedmods.net/mmsdrop/$metamodVersion/$metamodLatest"
$metamodInstalled = Get-Content -Path "metamod-installed.txt" -ErrorAction SilentlyContinue
if ($metamodInstalled -ne $metamodLatest) {
    Write-Output "Updating MetaMod"
    Invoke-WebRequest -Uri $metamodLatestUrl -OutFile "metamod.zip"
    Expand-Archive -Path "metamod.zip" -DestinationPath $csgoDir -Force
    Remove-Item -Path "metamod.zip"
    Set-Content -Path "metamod-installed.txt" -Value $metamodLatest
}

$sourcemodDatabasesFile = @"
"Databases"
{
	"driver_default"		"sqlite"
	"default"
	{
		"driver"			"default"
		"host"				"localhost"
		"database"			"sourcemod"
		"user"				"root"
		"pass"				""
	}
	"storage-local"
	{
		"driver"			"sqlite"
		"database"			"sourcemod-local"
	}
	"clientprefs"
	{
		"driver"			"sqlite"
		"host"				"localhost"
		"database"			"clientprefs-sqlite"
		"user"				"root"
		"pass"				""
	}
	"gokz"
	{
		"driver"			"sqlite"
		"host"				"localhost"
		"database"			"gokz-sqlite"
		"user"				"root"
		"pass"				""
	}
}
"@

$sourcemodVersion = "1.11"
$sourcemodLatest = Invoke-WebRequest -Uri "https://sm.alliedmods.net/smdrop/$sourcemodVersion/sourcemod-latest-windows" -UseBasicParsing
$sourcemodLatestUrl = "https://sm.alliedmods.net/smdrop/$sourcemodVersion/$sourcemodLatest"
$sourcemodInstalled = Get-Content -Path "sourcemod-installed.txt" -ErrorAction SilentlyContinue
if ($sourcemodInstalled -ne $sourcemodLatest) {
    Write-Output "Updating SourceMod"
    Invoke-WebRequest -Uri $sourcemodLatestUrl -OutFile "sourcemod.zip"
    Remove-Item -Path sourcemod-unzip -ErrorAction SilentlyContinue
    Expand-Archive -Path "sourcemod.zip" -DestinationPath "sourcemod-unzip" -Force
    Remove-Item -Path "sourcemod.zip"
    $filesNotToOverwrite = @("databases.cfg", "admins_simple.ini")
    Get-ChildItem -Path "sourcemod-unzip" | Copy-Item -Destination $csgoDir -Recurse -Force -Exclude $filesNotToOverwrite
    Remove-Item -Path "sourcemod-unzip" -Recurse
    Set-Content -Path "sourcemod-installed.txt" -Value $sourcemodLatest

    $databasesPath = "$csgoDir\\addons\\sourcemod\\configs\\databases.cfg"
    if (-Not (Test-Path -Path $databasesPath)) {
        Set-Content -Path $databasesPath -Value $sourcemodDatabasesFile
    }
    $adminsPath = "$csgoDir\\addons\\sourcemod\\configs\\admins_simple.ini"
    if (-Not (Test-Path -Path $adminsPath)) {
        Set-Content -Path $adminsPath -Value '"!127.0.0.1" "99:z"'
    }
}

$mapiResponse = Invoke-WebRequest -Uri "https://api.github.com/repos/danzayau/MovementAPI/releases/latest" -UseBasicParsing
$mapiResponse = $mapiResponse | ConvertFrom-Json
$mapiInstalled = Get-Content -Path "movementapi-installed.txt" -ErrorAction SilentlyContinue
if ($mapiInstalled -ne $mapiResponse.tag_name) {
    Write-Output "Updating MovementAPI"
    $allAssets = $mapiResponse.assets
    $asset = $null
    for ($i = 0; $i -lt $allAssets.Length; $i++) {
        $assetRegex = "^MovementAPI-v[0-9\.]+\.zip$"
        if ($allAssets[$i].name -Match $assetRegex) {
            $asset = $allAssets[$i]
            break
        }
    }
    if ($asset -eq $null) {
        Write-Output "Not updating MovementAPI because the releases format changed, script needs an update"
    }
    else {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "movementapi.zip"
        Expand-Archive -Path "movementapi.zip" -DestinationPath $csgoDir -Force
        Remove-Item -Path "movementapi.zip"
        Set-Content -Path "movementapi-installed.txt" -Value $mapiResponse.tag_name
    }
}

$gokzResponse = Invoke-WebRequest -Uri "https://api.github.com/repos/KZGlobalTeam/gokz/releases/latest" -UseBasicParsing
$gokzResponse = $gokzResponse | ConvertFrom-Json
$gokzInstalled = Get-Content -Path "gokz-installed.txt" -ErrorAction SilentlyContinue
if ($gokzInstalled -ne $gokzResponse.tag_name) {
    Write-Output "Updating GOKZ"
    $allAssets = $gokzResponse.assets
    $asset = $null
    for ($i = 0; $i -lt $allAssets.Length; $i++) {
        $assetRegex = if ($gokzInstalled -eq $null) {"^GOKZ-v[0-9\.]+\.zip$"} else {"^GOKZ-v[0-9\.]+-upgrade\.zip$"}
        if ($allAssets[$i].name -Match $assetRegex) {
            $asset = $allAssets[$i]
            break
        }
    }
    if ($asset -eq $null) {
        Write-Output "Not updating GOKZ because the releases format changed, script needs an update"
    }
    else {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "gokz.zip"
        Expand-Archive -Path "gokz.zip" -DestinationPath $csgoDir -Force
        Remove-Item -Path "gokz.zip"
        Set-Content -Path "gokz-installed.txt" -Value $gokzResponse.tag_name
    }
}

if ($startMap.Length -eq 0) {
    $startMap = "kz_beginnerblock_go"
    $startMapDir = "$csgoDir\\maps\\$startMap.bsp"
    if (-Not (Test-Path -Path $startMapDir)) {
        Write-Output "Downloading $startMap (default start map)"
        Invoke-WebRequest -Uri "https://maps.global-api.com/bsps/kz_beginnerblock_go.bsp" -OutFile $startMapDir
    }
}

Set-Location -Path $srcdsDir
$srcdsArgList = @("-game", "csgo")
$srcdsArgList += @("-console")
$srcdsArgList += @("-usercon")
$srcdsArgList += @("-nobreakpad")
$srcdsArgList += @("-tickrate", "128")
$srcdsArgList += @("+sv_lan", "1")
$srcdsArgList += @("+hostname", '"GOKZ Server"')
$srcdsArgList += @("+map", $startMap)
Start-Process srcds.exe -ArgumentList $srcdsArgList
