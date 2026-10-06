@echo off
setlocal EnableDelayedExpansion
title Remove User Account + Data
chcp 65001 >nul 2>&1
color 0E

:: ============================================================
::  Remove-User.bat
::  Run as Administrator. Asks which user(s) to delete,
::  then deletes the account + profile data (C:\Users\<name>).
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
echo ------------------------------------------------------------
echo.
set "USERS="
set /p "USERS=Kaun-kaunse user delete karne hai? (space ya comma se alag likho, e.g. test1 test2): "

:: Trim check - empty input
if not defined USERS (
    echo.
    echo  [ERROR] Koi naam nahi likha. Dobara try karo.
    echo.
    pause
    goto menu
)

:: Replace commas with spaces so FOR loop works
set "USERS=%USERS:,= %"

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

for %%U in (%USERS%) do call :DeleteOne "%%U"

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

:: --- Safety: never delete self ---
if /i "%TARGET%"=="%USERNAME%" (
    echo  [SKIP] "%TARGET%" current logged-in user hai. Khud ko delete nahi kar sakte.
    exit /b 0
)

:: --- Safety: protected system accounts / profiles ---
for %%P in (Administrator Administrateur DefaultAccount Guest WDAGUtilityAccount Default Public "All Users" DefaultUser0 systemprofile LocalService NetworkService) do (
    if /i "%TARGET%"=="%%~P" (
        echo  [SKIP] "%TARGET%" system/protected account hai. Skip kiya.
        exit /b 0
    )
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
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-CimInstance Win32_UserProfile ^| Where-Object { $_.LocalPath -eq 'C:\Users\%TARGET%' } ^| Remove-CimInstance -ErrorAction Stop; Write-Host '  [OK] Profile CIM se removed.' } catch { Write-Host ('  [FAIL] Profile remove nahi hua: ' + $_.Exception.Message) }"
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

:: --- Step 3: cleanup orphan registry/CIM profile entry if any ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like '*\%TARGET%' }; if ($p) { $p | Remove-CimInstance; Write-Host '  [OK] Orphan profile entry cleaned.' }" 2>nul

echo  Done: "%TARGET%"
exit /b 0
