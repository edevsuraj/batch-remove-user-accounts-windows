@echo off
setlocal EnableDelayedExpansion
title Remove User Account + Data
chcp 65001 >nul 2>&1
color 0E

:: ============================================================
::  Remove-User.bat
::  Run as Administrator. Popup list se select karo kaun-kaunse user delete
::  karne hain (ya naam manually likho), phir account + C:\Users\<name> data delete.
::  Guest / Default / Public / dusre Admin accounts BHI delete hote hain.
::  Sirf 2 cheez safe: (1) khud ka logged-in user, (2) Windows service profiles.
::  WARNING: Deleted data cannot be recovered.
::  Repo: https://github.com/edevsuraj/batch-remove-user-accounts-windows
:: ============================================================

:: ---------- 1. Admin check ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Please RIGHT-CLICK this file and choose "Run as administrator".
    echo  [ERROR] Bina Admin rights ke user delete nahi hoga.
    echo.
    pause
    exit /b 1
)

:menu
cls
echo ============================================================
echo   Windows User Account + Data Remover
echo ============================================================
echo.
echo  Current logged-in user : %USERNAME%
echo  Computer               : %COMPUTERNAME%
echo.
echo  --- Existing local accounts (net user) ---
net user | findstr /V /C:"User accounts" /C:"---" /C:"The command completed"
echo.
echo  --- Profile folders in C:\Users ---
if exist "C:\Users" dir /B "C:\Users"
echo.
echo ------------------------------------------------------------
echo  WARNING: Selected user ka account + C:\Users\^<name^> ka
echo  saara data PERMANENTLY delete ho jayega. Soch kar aage badhe.
echo  Guest / Default / Public / dusre Admin BHI delete honge.
echo  Sirf tumhara khud ka account (%USERNAME%) safe rahega.
echo ------------------------------------------------------------
echo.
echo  Kaise select karna hai?
echo   [1] Popup list se select karo (Recommended - list me se highlight + OK)
echo   [2] Naam manually type karo
echo.
set "MODE="
set /p "MODE=Choice (1/2, Enter=1): "
if "%MODE%"=="2" goto :manual
goto :popup

:: ============================================================
::  POPUP: PowerShell Out-GridView se multi-select
:: ============================================================
:popup
set "PICKFILE=%TEMP%\picked_users.txt"
if exist "%PICKFILE%" del /q "%PICKFILE%" 2>nul
echo.
echo  Popup khul raha hai... delete karne wale users SELECT karo, phir OK dabao.
echo  (Ctrl key ke saath click = multiple select. Cancel = manual typing.)
echo.
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "$self=$env:USERNAME; $svc=@('All Users','systemprofile','LocalService','NetworkService'); $acc=@(); try { $acc=@(Get-LocalUser -ErrorAction Stop | Where-Object { $_.Name -ne $self } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled=([string]$_.Enabled); Type='Account'} }) } catch { $raw=net user; foreach ($ln in $raw) { $t=$ln.Trim(); if ($t -and $t -notmatch '^-+$' -and $t -ne 'User accounts' -and $t -notmatch 'command completed' -and $t -notmatch 'accounts for') { foreach ($w in ($t -split '\s+')) { if ($w -and $w -ne $self -and $w -notmatch '^\\\\') { $acc+=@([pscustomobject]@{Name=$w; Enabled='?'; Type='Account'}) } } } } }; $prof=@(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $self -and $svc -notcontains $_.Name -and ($acc.Name -notcontains $_.Name) } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled='-'; Type='Folder'} }); $all=@($acc)+@($prof); if (-not $all -or $all.Count -eq 0) { 'NO_USERS_FOUND' } else { $sel=$all | Out-GridView -Title 'Delete karne wale users select karo (Ctrl+Click = multiple) - OK dabao' -OutputMode Multiple; if ($sel) { $sel | ForEach-Object { $_.Name } } }" > "%PICKFILE%" 2>nul
set "USERS="
if not exist "%PICKFILE%" goto :manual
findstr /I /C:"NO_USERS_FOUND" "%PICKFILE%" >nul 2>&1
if not errorlevel 1 (
    del /q "%PICKFILE%" 2>nul
    echo.
    echo  [INFO] Delete karne layak koi aur user nahi mila.
    echo.
    pause
    goto menu
)
for /f "usebackq delims=" %%L in ("%PICKFILE%") do (
    if defined USERS (
        set "USERS=!USERS! "%%L""
    ) else (
        set "USERS="%%L""
    )
)
del /q "%PICKFILE%" 2>nul
if not defined USERS goto :manual
goto :confirm

:: ============================================================
::  MANUAL: naam type karo
:: ============================================================
:manual
set "USERS="
set /p "USERS=Kaun-kaunse user delete karne hai? (space ya comma se alag likho, e.g. test1 test2): "

:: Empty input
if not defined USERS (
    echo.
    echo  [ERROR] Koi naam nahi likha. Dobara try karo.
    echo.
    pause
    goto menu
)

:: Replace commas with spaces so FOR loop works
set "USERS=%USERS:,= %"

:confirm

echo.
echo  Aapne ye users likhe: %USERS%
echo.
set "CONFIRM="
set /p "CONFIRM=Pakka delete karna hai? Saara data ud jayega! (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    if /i not "%CONFIRM%"=="YES" (
        echo.
        echo  Cancelled. Kuch delete nahi hua.
        echo.
        pause
        exit /b 0
    )
)

echo.
echo ============================================================
echo  Deleting... please wait.
echo ============================================================
echo.

for %%U in (%USERS%) do call :DeleteOne %%U

echo.
echo ============================================================
echo  Done. Remaining accounts:
echo ============================================================
net user | findstr /V /C:"User accounts" /C:"---" /C:"The command completed"
echo.
pause
exit /b 0

:: ============================================================
::  Subroutine: delete a single user
::  %~1 = username (quotes stripped)
:: ============================================================
:DeleteOne
set "TARGET=%~1"
:: Remove surrounding spaces if any (FOR already trims)
if "%TARGET%"=="" exit /b 0
if "%TARGET%"==" " exit /b 0

echo ----------------------------------------
echo  -^> Processing: "%TARGET%"

:: --- Safety: NEVER delete self (yahi ek admin bachana hai) ---
if /i "%TARGET%"=="%USERNAME%" (
    echo  [SKIP] "%TARGET%" current logged-in user hai. Yahi ek admin bachega, isko delete nahi kar sakte.
    exit /b 0
)

:: --- Safety: sirf Windows service profiles skip (inhe delete karne se Windows toot jayega) ---
:: NOTE: Guest / Administrator (dusra) / Default / Public / DefaultAccount ab DELETE honge - user ki demand par.
for %%P in ("All Users" systemprofile LocalService NetworkService) do (
    if /i "%TARGET%"=="%%~P" (
        echo  [SKIP] "%TARGET%" Windows service profile hai. Isko skip kiya.
        exit /b 0
    )
)

:: --- Extra warning for Default / Public (template profiles) ---
if /i "%TARGET%"=="Default" (
    echo  [WARN] "Default" naye users ka template hai. Delete karne ke baad naye user banane me problem aa sakti hai. Phir bhi delete kar rahe...
)
if /i "%TARGET%"=="Public" (
    echo  [WARN] "Public" shared folder hai. Delete karne ke baad shared data jayega. Phir bhi delete kar rahe...
)

:: --- Info: agar target admin hai to batado (self ke alawa sab admin delete honge) ---
net localgroup Administrators 2>nul | findstr /I /C:"%TARGET%" >nul
if not errorlevel 1 (
    echo  [INFO] "%TARGET%" admin group ka member hai. Self ke alawa sab admin delete honge, isliye ise bhi delete kar rahe...
)

:: --- Check: does the account exist? ---
net user "%TARGET%" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [SKIP] "%TARGET%" naam ka local account nahi mila. Spelling check karo.
    :: Still try profile folder cleanup below in case orphan folder hai
    goto :DeleteProfileFolder
)

:: --- Step 1: delete the account ---
echo  Deleting account "%TARGET%" ...
net user "%TARGET%" /delete
if %errorlevel% neq 0 (
    echo  [FAIL] net user delete fail hua. Error: %errorlevel%
) else (
    echo  [OK] Account "%TARGET%" deleted.
)

:DeleteProfileFolder
:: --- Step 2: delete C:\Users\%TARGET% folder ---
if exist "C:\Users\%TARGET%" (
    echo  Deleting profile folder "C:\Users\%TARGET%" ...
    rmdir /S /Q "C:\Users\%TARGET%" 2>nul
    if exist "C:\Users\%TARGET%" (
        echo  [WARN] Folder locked hai (koi file open hogi). Safe delete ke liye PowerShell se try kar rahe...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq 'C:\Users\%TARGET%' } | Remove-CimInstance -ErrorAction Stop; Write-Host '  [OK] Profile CIM se removed.' } catch { Write-Host ('  [FAIL] Profile remove nahi hua: ' + $_.Exception.Message) }"
        if exist "C:\Users\%TARGET%" (
            echo  [FAIL] "C:\Users\%TARGET%" abhi bhi hai. PC restart karke dobara chalao ya manually delete karo.
        ) else (
            echo  [OK] Profile folder deleted.
        )
    ) else (
        echo  [OK] Profile folder deleted.
    )
) else (
    echo  [INFO] "C:\Users\%TARGET%" folder nahi mila (pehle se साफ ya orphan nahi hai).
)

:: --- Step 2b: Windows XP profile path (Documents and Settings) ---
if exist "C:\Documents and Settings\%TARGET%" (
    echo  Deleting XP profile folder "C:\Documents and Settings\%TARGET%" ...
    rmdir /S /Q "C:\Documents and Settings\%TARGET%" 2>nul
    if exist "C:\Documents and Settings\%TARGET%" (
        echo  [WARN] XP folder delete nahi hua. Manually delete karo.
    ) else (
        echo  [OK] XP profile folder deleted.
    )
)

:: --- Step 3: cleanup orphan registry/CIM profile entry if any ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like '*\%TARGET%' }; if ($p) { $p | Remove-CimInstance; Write-Host '  [OK] Orphan profile entry cleaned.' }" 2>nul

echo  Done: "%TARGET%"
exit /b 0
