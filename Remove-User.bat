@echo off
setlocal EnableDelayedExpansion
title Remove User Accounts
color 0E

:: Admin check
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Please RIGHT-CLICK this file and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Popup opens directly
set "PICKFILE=%TEMP%\picked_users.txt"
if exist "%PICKFILE%" del /q "%PICKFILE%" 2>nul

powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "$self=$env:USERNAME; $svc=@('All Users','systemprofile','LocalService','NetworkService'); $acc=@(); try { $acc=@(Get-LocalUser -ErrorAction Stop | Where-Object { $_.Name -ne $self } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled=([string]$_.Enabled); Type='Account'} }) } catch { $raw=net user; foreach ($ln in $raw) { $t=$ln.Trim(); if ($t -and $t -notmatch '^-+$' -and $t -ne 'User accounts' -and $t -notmatch 'command completed' -and $t -notmatch 'accounts for') { foreach ($w in ($t -split '\s+')) { if ($w -and $w -ne $self -and $w -notmatch '^\\\\') { $acc+=@([pscustomobject]@{Name=$w; Enabled='?'; Type='Account'}) } } } } }; $prof=@(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $self -and $svc -notcontains $_.Name -and ($acc.Name -notcontains $_.Name) } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled='-'; Type='Folder'} }); $all=@($acc)+@($prof); if (-not $all -or $all.Count -eq 0) { 'NO_USERS_FOUND' | Out-File -FilePath '%TEMP%\picked_users.txt' -Encoding ASCII } else { $sel=$all | Out-GridView -Title 'Select users to DELETE (Ctrl+Click = multiple) - Press OK | by Suraj Chauhan | Contact: edev.suraj@gmail.com' -OutputMode Multiple; if ($sel) { $sel | ForEach-Object { $_.Name } | Out-File -FilePath '%TEMP%\picked_users.txt' -Encoding ASCII } }" 2>nul

set "USERS="
if not exist "%PICKFILE%" (
    echo.
    echo  Cancelled. Nothing was deleted.
    echo.
    pause
    exit /b 0
)
findstr /I /C:"NO_USERS_FOUND" "%PICKFILE%" >nul 2>&1
if not errorlevel 1 (
    del /q "%PICKFILE%" 2>nul
    echo.
    echo  [INFO] No other deletable user found.
    echo.
    pause
    exit /b 0
)
for /f "usebackq delims=" %%L in ("%PICKFILE%") do (
    if defined USERS (
        set "USERS=!USERS! "%%L""
    ) else (
        set "USERS="%%L""
    )
)
del /q "%PICKFILE%" 2>nul
if not defined USERS (
    echo.
    echo  Cancelled. Nothing was deleted.
    echo.
    pause
    exit /b 0
)

echo.
echo  Deleting...
echo.

for %%U in (%USERS%) do call :DeleteOne %%U

echo.
echo  Done. Remaining accounts:
net user | findstr /V /C:"User accounts" /C:"---" /C:"The command completed"
echo.
pause
exit /b 0

:: ============================================================
::  Delete one user
:: ============================================================
:DeleteOne
set "TARGET=%~1"
if "%TARGET%"=="" exit /b 0
if "%TARGET%"==" " exit /b 0

echo  -^> "%TARGET%"

:: Safety: never delete self
if /i "%TARGET%"=="%USERNAME%" (
    echo  [SKIP] Current logged-in user, cannot delete.
    exit /b 0
)

:: Safety: skip Windows service profiles
for %%P in ("All Users" systemprofile LocalService NetworkService) do (
    if /i "%TARGET%"=="%%~P" (
        echo  [SKIP] Windows service profile.
        exit /b 0
    )
)

:: Check if account exists
net user "%TARGET%" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [SKIP] Account not found.
    goto :DeleteProfileFolder
)

:: Delete account
net user "%TARGET%" /delete
if %errorlevel% neq 0 (
    echo  [FAIL] Could not delete account.
) else (
    echo  [OK] Account deleted.
)

:DeleteProfileFolder
:: Delete profile folder
if exist "C:\Users\%TARGET%" (
    rmdir /S /Q "C:\Users\%TARGET%" 2>nul
    if exist "C:\Users\%TARGET%" (
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq 'C:\Users\%TARGET%' } | Remove-CimInstance -ErrorAction Stop } catch {}" 2>nul
        if exist "C:\Users\%TARGET%" (
            echo  [FAIL] Folder still exists. Restart PC and try again.
        ) else (
            echo  [OK] Profile folder deleted.
        )
    ) else (
        echo  [OK] Profile folder deleted.
    )
)

:: Cleanup orphan CIM entry
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like '*\%TARGET%' }; if ($p) { $p | Remove-CimInstance }" 2>nul

echo  Done: "%TARGET%"
exit /b 0
