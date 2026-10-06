@echo off
setlocal EnableDelayedExpansion
title Remove User Account + Data / User Account + Data Hatayein
chcp 65001 >nul 2>&1
color 0E

:: ============================================================
::  Remove-User.bat
::  Run as Administrator. Select from popup list which users to
::  delete (or type names manually), then account + C:\Users\<name> data deleted.
::  Administrator ke roop me chalayein. Popup list se chune kaun-se user
::  delete karne hain (ya naam manually likhein), phir account + C:\Users\<name> data delete hoga.
::  Guest / Default / Public / other Admin accounts WILL also be deleted.
::  Guest / Default / Public / dusre Admin accounts BHI delete honge.
::  Only 2 things are safe: (1) your own logged-in user, (2) Windows service profiles.
::  Sirf 2 cheez safe hain: (1) aapka khud ka logged-in user, (2) Windows service profiles.
::  WARNING: Deleted data cannot be recovered.
::  CHETAVNI: Delete hua data wapas nahi milega.
::  Repo: https://github.com/edevsuraj/batch-remove-user-accounts-windows
:: ============================================================

:: ---------- 1. Admin check / Admin jaanch ----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [ERROR] Please RIGHT-CLICK this file and choose "Run as administrator".
    echo  [ERROR] Kripya is file par RIGHT-CLICK karke "Run as administrator" chunein.
    echo  [ERROR] Without Admin rights users cannot be deleted.
    echo  [ERROR] Bina Admin rights ke user delete nahi hoga.
    echo.
    pause
    exit /b 1
)

:menu
cls
echo ============================================================
echo   Windows User Account + Data Remover
echo   Windows User Account + Data Hatane Wala Tool
echo ============================================================
echo.
echo  Current logged-in user / Vartaman login user : %USERNAME%
echo  Computer / Computer                           : %COMPUTERNAME%
echo.
echo  --- Existing local accounts / Mojooda local accounts (net user) ---
net user | findstr /V /C:"User accounts" /C:"---" /C:"The command completed"
echo.
echo  --- Profile folders in C:\Users / C:\Users me profile folders ---
if exist "C:\Users" dir /B "C:\Users"
echo.
echo ------------------------------------------------------------
echo  WARNING / CHETAVNI: Selected users' account + C:\Users\^<name^> ka
echo  WARNING / CHETAVNI: Chune gaye users ka account + C:\Users\^<name^> ka
echo  saara data PERMANENTLY delete ho jayega. / entire data will be PERMANENTLY deleted.
echo  Soch kar aage badhein. / Please proceed carefully.
echo  Guest / Default / Public / other Admins WILL also be deleted.
echo  Guest / Default / Public / dusre Admin BHI delete honge.
echo  Only your own account (%USERNAME%) stays safe. / Sirf tumhara khud ka account (%USERNAME%) safe rahega.
echo ------------------------------------------------------------
echo.
echo  How to select? / Kaise select karna hai?
echo   [1] Select from popup list (Recommended - highlight from list + OK)
echo   [1] Popup list se select karo (Recommended - list me se highlight + OK)
echo   [2] Type names manually / Naam manually type karo
echo   [2] Naam haath se likho / Naam manually type karo
echo.
set "MODE="
set /p "MODE=Choice / Vikalp (1/2, Enter=1): "
if "%MODE%"=="2" goto :manual
goto :popup

:: ============================================================
::  POPUP: Multi-select via PowerShell Out-GridView
::  POPUP: PowerShell Out-GridView se multi-select
:: ============================================================
:popup
set "PICKFILE=%TEMP%\picked_users.txt"
if exist "%PICKFILE%" del /q "%PICKFILE%" 2>nul
echo.
echo  Popup is opening... Select users to delete, then press OK.
echo  Popup khul raha hai... delete karne wale users SELECT karo, phir OK dabao.
echo  (Ctrl+click = multiple select. Cancel = manual typing.)
echo  (Ctrl key ke saath click = multiple select. Cancel = manual typing.)
echo.
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "$self=$env:USERNAME; $svc=@('All Users','systemprofile','LocalService','NetworkService'); $acc=@(); try { $acc=@(Get-LocalUser -ErrorAction Stop | Where-Object { $_.Name -ne $self } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled=([string]$_.Enabled); Type='Account'} }) } catch { $raw=net user; foreach ($ln in $raw) { $t=$ln.Trim(); if ($t -and $t -notmatch '^-+$' -and $t -ne 'User accounts' -and $t -notmatch 'command completed' -and $t -notmatch 'accounts for') { foreach ($w in ($t -split '\s+')) { if ($w -and $w -ne $self -and $w -notmatch '^\\\\') { $acc+=@([pscustomobject]@{Name=$w; Enabled='?'; Type='Account'}) } } } } }; $prof=@(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $self -and $svc -notcontains $_.Name -and ($acc.Name -notcontains $_.Name) } | ForEach-Object { [pscustomobject]@{Name=$_.Name; Enabled='-'; Type='Folder'} }); $all=@($acc)+@($prof); if (-not $all -or $all.Count -eq 0) { 'NO_USERS_FOUND' } else { $sel=$all | Out-GridView -Title 'Select users to DELETE (Ctrl+Click = multiple) - Press OK / Delete karne wale users select karo (Ctrl+Click = multiple) - OK dabao' -OutputMode Multiple; if ($sel) { $sel | ForEach-Object { $_.Name } } }" > "%PICKFILE%" 2>nul
set "USERS="
if not exist "%PICKFILE%" goto :manual
findstr /I /C:"NO_USERS_FOUND" "%PICKFILE%" >nul 2>&1
if not errorlevel 1 (
    del /q "%PICKFILE%" 2>nul
    echo.
    echo  [INFO] No other deletable user found.
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
::  MANUAL: Type names / MANUAL: naam type karo
:: ============================================================
:manual
set "USERS="
set /p "USERS=Which users to delete? (separate by space or comma, e.g. test1 test2) / Kaun-kaunse user delete karne hain? (space ya comma se alag likho, e.g. test1 test2): "

:: Empty input / Khali input
if not defined USERS (
    echo.
    echo  [ERROR] No name entered. Please try again.
    echo  [ERROR] Koi naam nahi likha. Dobara try karo.
    echo.
    pause
    goto menu
)

:: Replace commas with spaces so FOR loop works
:: FOR loop ke liye comma ko space se badlein
set "USERS=%USERS:,= %"

:confirm

echo.
echo  You entered these users: / Aapne ye users likhe: %USERS%
echo.
set "CONFIRM="
set /p "CONFIRM=Really delete? All data will be erased! (Y/N) / Pakka delete karna hai? Saara data ud jayega! (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    if /i not "%CONFIRM%"=="YES" (
        echo.
        echo  Cancelled. Nothing was deleted. / Cancel ho gaya. Kuch delete nahi hua.
        echo.
        pause
        exit /b 0
    )
)

echo.
echo ============================================================
echo  Deleting... please wait. / Delete ho raha hai... kripya rukein.
echo ============================================================
echo.

for %%U in (%USERS%) do call :DeleteOne %%U

echo.
echo ============================================================
echo  Done. Remaining accounts: / Ho gaya. Bache hue accounts:
echo ============================================================
net user | findstr /V /C:"User accounts" /C:"---" /C:"The command completed"
echo.
echo  Opening our apps page in your browser...
echo  Hamare apps ka page aapke browser me khul raha hai...
start "" "https://edevsuraj.github.io/explore-our-apps-and-extensions/"
echo.
pause
exit /b 0

:: ============================================================
::  Subroutine: delete a single user / Ek user delete karne ki prakriya
::  %~1 = username (quotes stripped / bina quotes ke)
:: ============================================================
:DeleteOne
set "TARGET=%~1"
:: Remove surrounding spaces if any (FOR already trims)
:: Aas-paas ke space hatayein (FOR pehle hi trim karta hai)
if "%TARGET%"=="" exit /b 0
if "%TARGET%"==" " exit /b 0

echo ----------------------------------------
echo  -^> Processing / Prakriya me: "%TARGET%"

:: --- Safety: NEVER delete self (this one admin must survive) ---
:: --- Suraksha: Khud ko KABHI delete na karein (yahi ek admin bachega) ---
if /i "%TARGET%"=="%USERNAME%" (
    echo  [SKIP] "%TARGET%" is the current logged-in user. It must survive as the admin, cannot delete it.
    echo  [SKIP] "%TARGET%" current logged-in user hai. Yahi ek admin bachega, isko delete nahi kar sakte.
    exit /b 0
)

:: --- Safety: skip only Windows service profiles (deleting them breaks Windows) ---
:: --- Suraksha: sirf Windows service profiles skip karein (inhe delete karne se Windows toot jayega) ---
:: NOTE: Guest / other Administrator / Default / Public / DefaultAccount WILL now be DELETED on user demand.
:: NOTE: Guest / dusra Administrator / Default / Public / DefaultAccount ab DELETE honge - user ki demand par.
for %%P in ("All Users" systemprofile LocalService NetworkService) do (
    if /i "%TARGET%"=="%%~P" (
        echo  [SKIP] "%TARGET%" is a Windows service profile. Skipped.
        echo  [SKIP] "%TARGET%" Windows service profile hai. Isko skip kiya.
        exit /b 0
    )
)

:: --- Extra warning for Default / Public (template profiles) ---
:: --- Default / Public ke liye extra chetavni (template profiles) ---
if /i "%TARGET%"=="Default" (
    echo  [WARN] "Default" is the template for new users. Deleting it may cause problems creating new users. Still deleting...
    echo  [WARN] "Default" naye users ka template hai. Delete karne ke baad naye user banane me problem aa sakti hai. Phir bhi delete kar rahe...
)
if /i "%TARGET%"=="Public" (
    echo  [WARN] "Public" is a shared folder. Shared data will be lost after deletion. Still deleting...
    echo  [WARN] "Public" shared folder hai. Delete karne ke baad shared data jayega. Phir bhi delete kar rahe...
)

:: --- Info: tell if target is admin (all admins except self will be deleted) ---
:: --- Jankari: agar target admin hai to batayein (self ke alawa sab admin delete honge) ---
net localgroup Administrators 2>nul | findstr /I /C:"%TARGET%" >nul
if not errorlevel 1 (
    echo  [INFO] "%TARGET%" is a member of the admin group. All admins except self will be deleted, so deleting it too...
    echo  [INFO] "%TARGET%" admin group ka member hai. Self ke alawa sab admin delete honge, isliye ise bhi delete kar rahe...
)

:: --- Check: does the account exist? / Jaanch: kya account maujood hai? ---
net user "%TARGET%" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [SKIP] Local account named "%TARGET%" not found. Please check spelling.
    echo  [SKIP] "%TARGET%" naam ka local account nahi mila. Spelling check karo.
    :: Still try profile folder cleanup below in case it is an orphan folder
    :: Phir bhi neeche profile folder saaf karne ki koshish karein, orphan folder ho sakta hai
    goto :DeleteProfileFolder
)

:: --- Step 1: delete the account / Step 1: account delete karein ---
echo  Deleting account "%TARGET%" ... / Account "%TARGET%" delete ho raha hai ...
net user "%TARGET%" /delete
if %errorlevel% neq 0 (
    echo  [FAIL] net user delete failed. Error: %errorlevel% / net user delete fail hua. Error: %errorlevel%
) else (
    echo  [OK] Account "%TARGET%" deleted. / Account "%TARGET%" delete ho gaya.
)

:DeleteProfileFolder
:: --- Step 2: delete C:\Users\%TARGET% folder / Step 2: C:\Users\%TARGET% folder delete karein ---
if exist "C:\Users\%TARGET%" (
    echo  Deleting profile folder "C:\Users\%TARGET%" ... / Profile folder "C:\Users\%TARGET%" delete ho raha hai ...
    rmdir /S /Q "C:\Users\%TARGET%" 2>nul
    if exist "C:\Users\%TARGET%" (
        echo  [WARN] Folder is locked (some file must be open). Trying safe delete via PowerShell...
        echo  [WARN] Folder locked hai (koi file open hogi). Safe delete ke liye PowerShell se try kar rahe...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq 'C:\Users\%TARGET%' } | Remove-CimInstance -ErrorAction Stop; Write-Host '  [OK] Profile removed via CIM. / Profile CIM se removed.' } catch { Write-Host ('  [FAIL] Profile could not be removed / Profile remove nahi hua: ' + $_.Exception.Message) }"
        if exist "C:\Users\%TARGET%" (
            echo  [FAIL] "C:\Users\%TARGET%" still exists. Restart PC and run again or delete manually.
            echo  [FAIL] "C:\Users\%TARGET%" abhi bhi hai. PC restart karke dobara chalao ya manually delete karo.
        ) else (
            echo  [OK] Profile folder deleted. / Profile folder delete ho gaya.
        )
    ) else (
        echo  [OK] Profile folder deleted. / Profile folder delete ho gaya.
    )
) else (
    echo  [INFO] "C:\Users\%TARGET%" folder not found (already clean or no orphan). / folder nahi mila (pehle se saaf ya orphan nahi hai).
)

:: --- Step 2b: Windows XP profile path (Documents and Settings) ---
:: --- Step 2b: Windows XP profile path (Documents and Settings) ---
if exist "C:\Documents and Settings\%TARGET%" (
    echo  Deleting XP profile folder "C:\Documents and Settings\%TARGET%" ... / XP profile folder "C:\Documents and Settings\%TARGET%" delete ho raha hai ...
    rmdir /S /Q "C:\Documents and Settings\%TARGET%" 2>nul
    if exist "C:\Documents and Settings\%TARGET%" (
        echo  [WARN] XP folder could not be deleted. Please delete manually. / XP folder delete nahi hua. Manually delete karo.
    ) else (
        echo  [OK] XP profile folder deleted. / XP profile folder delete ho gaya.
    )
)

:: --- Step 3: cleanup orphan registry/CIM profile entry if any ---
:: --- Step 3: agar orphan registry/CIM profile entry ho to saaf karein ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like '*\%TARGET%' }; if ($p) { $p | Remove-CimInstance; Write-Host '  [OK] Orphan profile entry cleaned. / Orphan profile entry saaf ho gayi.' }" 2>nul

echo  Done: "%TARGET%" / Ho gaya: "%TARGET%"
exit /b 0
