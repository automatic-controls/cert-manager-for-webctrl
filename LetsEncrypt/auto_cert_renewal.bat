@echo off
title WebCTRL Certificate Renewal
setlocal DisableDelayedExpansion

%= Check whether this batch file has been executed with parameter "auto" =%
if "%1" EQU "auto" (
  %= in this case, we automatically renew the WebCTRL certificate without requiring any user intervention =%
  %= all output is redirected to a log file =%
  set /a auto=1
  (
    call :main
  ) >"%~dp0log.txt" 2>&1
  exit
) else (
  set /a auto=0
)

:main
echo.

%= Check if this script has been executed by an administrator =%
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  echo Error - This script must be ran as administrator.
  if %auto%==1 exit
  echo.
  echo Press any key to exit...
  pause >nul
  exit
)

echo Initializing...
echo.

%= Delete the previous log file if it exists =%
del /F "%~dp0log.txt" >nul 2>nul

%= Define variables which specify various file locations =%
set "folder=%~dp0"
cd "%folder%"
set "folder=%cd%"
cd..
cd..
set "WebCTRL=%cd%"
cd "%folder%"
set "keytool=%WebCTRL%\bin\java\jre\bin\keytool.exe"
set "settings=%WebCTRL%\resources\properties\settings.properties"
set "serverConfig=%WebCTRL%\webserver\conf\server.xml"
set "config=config.txt"
set "keystore=certkeys"
set "obfuscate=Obfuscate.js"

%= Attempt to locate the keytool utility =%
if not exist "%keytool%" (
  set "keytool=keytool"
  setlocal EnableDelayedExpansion
    "keytool" --help >nul 2>nul
    if "!ERRORLEVEL!" EQU "9009" (
      echo Unable to locate keytool utility.
      echo Please ensure this script is placed in the appropriate folder.
      echo e.g. %HOMEDRIVE%\WebCTRL8.0\webserver\keystores
      if %auto%==1 exit
      echo.
      echo Press any key to exit...
      pause >nul
      exit
    )
  endlocal
)

%= Attempt to locate the WebCTRL configuration file =%
if not exist "%settings%" (
  echo Unable to locate WebCTRL configuration file.
  echo %settings%
  echo.
  echo Please ensure this script is placed in the appropriate folder.
  echo e.g. %HOMEDRIVE%\WebCTRL8.0\webserver\keystores
  if %auto%==1 exit
  echo.
  echo Press any key to exit...
  pause >nul
  exit
)

%= Verify that certbot has been installed =%
certbot --version >nul 2>nul
if "%ERRORLEVEL%" EQU "9009" (
  echo Please install certbot.
  echo https://dl.eff.org/certbot-beta-installer-win32.exe
  if %auto%==1 exit
  echo.
  echo Press any key to exit...
  pause >nul
  exit
)

%= This variable indicates whether the WebCTRL service should be restarted after the script exits =%
set /a restartWebCTRL=0

%= This for loop checks the status of the WebCTRL service =%
for /f "tokens=3 delims=: " %%i in ('sc query "WebCTRL Service" ^| findstr /L "        STATE" 2^>nul') do (
  if /i "%%i" NEQ "STOPPED" (
    if %auto%==0 (
      %= If the WebCTRL service is not stopped and the "auto" parameter is not given, then notify the user and exit =%
      echo Please stop the WebCTRL service.
      echo.
      echo Press any key to exit...
      pause >nul
      exit
    ) else (
      %= If the WebCTRL service is not stopped and the "auto" parameter is given, then stop the WebCTRL service =%
      set /a restartWebCTRL=1
      sc stop "WebCTRL Service" >nul
      if "%ERRORLEVEL%" NEQ "0" (
        echo Failed to stop WebCTRL service.
        exit
      )
    )
  )
)

%= Wait up to 25 minutes for the WebCTRL service to be stopped =%
setlocal EnableDelayedExpansion
  set /a secondsLeft=1500
  :waitForStopLoop
  if %restartWebCTRL%==1 (
    for /f "tokens=3 delims=: " %%i in ('sc query "WebCTRL Service" ^| findstr /L "        STATE" 2^>nul') do (
      if /i "%%i" NEQ "STOPPED" (
        timeout 1 >nul
        set /a secondsLeft-=1
        if !secondsLeft! LEQ 0 (
          echo WebCTRL service did not stop within the allotted time limit of 25 minutes.
          echo Attempting to restart WebCTRL...
          sc start "WebCTRL Service" >nul
          exit
        )
        goto :waitForStopLoop
      )
    )
  )
endlocal

%= Determine whether there exists a task which periodically executes this script =%
schtasks /Query /TN "WebCTRL Certificate Renewal" >nul 2>nul
if %ERRORLEVEL%==0 (
  set /a taskExists=1
) else (
  set /a taskExists=0
)

%= Generate a JavaScript file which is used to obfuscate the keystore password =%
if not exist "%obfuscate%" (
  echo var x = WScript.Arguments^(0^)
  echo var y = ^"^"
  echo for ^(var i=x.length-1;i^>=0;--i^){
  echo     y = y.concat^(String.fromCharCode^(x.charCodeAt^(i^)^^4^)^)
  echo }
  echo WScript.Echo^(y^)
) > "%obfuscate%"

%= Load the configuration file if is exists =%
if exist "%config%" (
  call :load
  set "loaded=true"
) else if %auto%==1 (
  echo Unable to locate configuration file.
  echo %config%
  exit
)

cls
setlocal EnableDelayedExpansion
  if %auto%==0 (
    %= Ask the user whether they want to continue =%
    echo Are you sure you want to renew WebCTRL's certificate? ^(YES/NO^)
    set /p "ret=>"
    if /i "!ret!" EQU "Y" (
      set "ret=YES"
    )
    if /i "!ret!" NEQ "YES" (
      echo.
      echo Certificate generation aborted^^!
      echo.
      goto :scheduleQuestions
    )
    cls
  )
endlocal

%= Ensure all variables are properly defined and stored =%
if "%loaded%" EQU "true" (
  call :save
) else (
  call :promptForParameters
)

%= Delete the previous keystore if it exists =%
if exist "%keystore%" (
  echo Clearing existing certificates...
  del /F "%keystore%" >nul 2>nul
)

%= Delete previous certificates if they exist =%
if exist "%folder%\WebCTRL.cer" (
  del /F "%folder%\WebCTRL.cer" >nul 2>nul
)
del /F "%folder%\*.pem" >nul 2>nul

echo Generating 2048bit RSA private key-pair...
"%keytool%" -keystore "%keystore%" -storepass "%password%" -genkeypair -alias webctrl -keyalg RSA -sigalg SHA256withRSA -keysize 2048 -keypass "%password%" -validity 3650 -ext "san=dns:%CN%" -dname "CN=%CN%, OU=%OU%, O=%O%, L=%L%, ST=%ST%, C=%C%" >nul
if "%ERRORLEVEL%" NEQ "0" goto :error

echo Generating certificate request...
"%keytool%" -keystore "%keystore%" -storepass "%password%" -alias webctrl -certreq -file "%folder%\request.csr" >nul
if "%ERRORLEVEL%" NEQ "0" goto :error

echo Retrieving the certificate request reply from LetsEncrypt using certbot...
echo.
mkdir "%folder%\logs" >nul 2>nul

%= Add the flag '--test-cert' to the following command if you want to use the script for testing purposes =%
certbot certonly --standalone --csr "%folder%\request.csr" --logs-dir "%folder%\logs"
if "%ERRORLEVEL%" NEQ "0" goto :error

echo.
echo Importing the certificate request reply...
setlocal EnableDelayedExpansion
  %= Find the certificates retrieved from LetsEncrypt =%
  set /a len=0
  for /f "tokens=* delims=" %%i in ('dir /b "%folder%\*_chain.pem" 2^>nul') do (
    set /a len+=1
    set "arr[!len!]=%%i"
  )
  if "%len%" EQU "0" (
    echo.
    echo Could not locate any files of the form:
    echo %folder%\*_chain.pem
    goto :error
  )

  %= Import all intermediate certificates into the keystore =%
  set /a len-=1
  for /l %%i in (1,1,%len%) do (
    "%keytool%" -keystore "%keystore%" -storepass "!password!" -alias inter%%i -importcert -file "%folder%\!arr[%%i]!" -noprompt >nul
    if "%ERRORLEVEL%" NEQ "0" goto :error
  )

  %= Import the primary certificate into the keystore =%
  set /a len+=1
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -alias webctrl -importcert -file "%folder%\!arr[%len%]!" -noprompt >nul
  if "%ERRORLEVEL%" NEQ "0" goto :error

  %= Remove all intermediate certificates from the keystore =%
  set /a len-=1
  for /l %%i in (1,1,%len%) do (
    "%keytool%" -keystore "%keystore%" -storepass "!password!" -alias inter%%i -delete >nul
    if "%ERRORLEVEL%" NEQ "0" goto :error
  )

  %= Export the primary certificate =%
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -alias webctrl -exportcert -file "%folder%\WebCTRL.cer" >nul
  if "%ERRORLEVEL%" NEQ "0" goto :error
endlocal

echo.
echo Certificate renewal complete!
echo.

:scheduleQuestions
setlocal EnableDelayedExpansion
  if %auto%==0 (
    if %taskExists%==1 (
      echo There exists a scheduled task "WebCTRL Certificate Renewal" that executes this script every 80 days.
      echo So you shouldn't have to run this script manually.
      echo.
      echo Would you like to delete this task? ^(YES/NO^)
      set /p "ret=>"
      if /i "!ret!" EQU "Y" (
        set "ret=YES"
      )
      if /i "!ret!" EQU "YES" (
        %= Delete the scheduled task =%
        schtasks /Delete /F /TN "WebCTRL Certificate Renewal"
        echo.
      ) else (
        goto :gracefulExit
      )
    )
    echo Would you like to schedule a new task to automatically run this script and renew WebCTRL's certificate every 80 days? ^(YES/NO^)
    echo Warning - This script will automatically restart the WebCTRL service if you choose to run it automatically.
    set /p "ret=>"
    if /i "!ret!" EQU "Y" (
      set "ret=YES"
    )
    if /i "!ret!" EQU "YES" (
      call :scheduleTask
    ) else (
      echo.
      echo Please run this script again when your certificate expires ^(which should occur in approximately 90 days^).
    )
  )
endlocal
goto :gracefulExit

:scheduleTask
  echo What time of day should this script be scheduled to run at? ^(using military time format^)
  echo e.g. 03:00 - the task will run at 3:00AM every 80 days. ^(the leading zero is important^)
  echo e.g. 15:00 - the task will run at 3:00PM every 80 days.
  set /p "ret=>"
  %= Create a scheduled certificate renewal task =%
  schtasks /Create /RU SYSTEM /SC DAILY /MO 80 /TN "WebCTRL Certificate Renewal" /TR "'%~dpnx0' auto" /ST !ret! /NP /F /RL HIGHEST
  if "%ERRORLEVEL%" NEQ "0" (
    echo An error was encountered. Would you like to try again? ^(YES/NO^)
    set /p "ret=>"
    if /i "!ret!" EQU "Y" (
      set "ret=YES"
    )
    if /i "!ret!" EQU "YES" (
      goto :scheduleTask
    )
  )
exit /b

:promptForParameters
  echo DO NOT USE THE SPECIAL CHARACTERS: ^&^"{
  echo Keystore password:
  set /p "password=>"
  cls
  set "passwordEsc=%password:^=^^%"
  set "passwordEsc=%passwordEsc:<=^<%"
  set "passwordEsc=%passwordEsc:>=^>%"
  set "passwordEsc=%passwordEsc:|=^|%"
  set "passwordEsc=%passwordEsc:)=^)%"
  set "passwordEsc=%passwordEsc:(=^(%"
  call :obfuscate
  echo The following parameter must match the URL used to access your server ^(e.g. www.somename.net^).
  echo DNS Name:
  set /p "CN=>"
  for /f "usebackq" %%i in (`PowerShell -Command '%CN%' -match '^^^(?:\d+\.^)*\d+$'`) do (
    if /i "%%i" EQU "True" (
      echo ERROR - Raw IPs are not supported.
      echo Please register your IP address to a domain ^(e.g. www.somename.net^) and try again later.
      goto :gracefulExit
    )
  )
  echo Department:
  set /p "OU=>"
  echo Organization:
  set /p "O=>"
  echo City or Locality:
  set /p "L=>"
  echo State or Province:
  set /p "ST=>"
  echo Two-letter Country Code:
  set /p "C=>"
  cls
  call :save
  exit /b

:error
  echo.
  echo An error has occurred.
  goto :gracefulExit

:gracefulExit
  if %restartWebCTRL%==1 (
    %= Restart the WebCTRL service =%
    sc start "WebCTRL Service" >nul
  )

  %= Clean up the file tree by deleting unnecessary items =%
  del /F "%obfuscate%" >nul 2>nul
  del /F "%folder%\*.pem" >nul 2>nul
  del /F "%folder%\*.csr" >nul 2>nul
  rmdir /S /Q "%folder%\logs" >nul 2>nul

  if %auto%==1 exit
  echo.
  echo Press any key to exit...
  pause >nul
  exit

%= Use the generated JavaScript file to obfuscate the keystore password =%
:obfuscate
  for /f "delims=" %%i in ('cscript //nologo //E:jscript "%obfuscate%" "%password%"') do set "ObfuscatedPassword=%%i"
  set "ObfuscatedPasswordEsc=%ObfuscatedPassword:^=^^%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:<=^<%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:>=^>%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:|=^|%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:)=^)%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:(=^(%"
exit /b

:load
  %= Retrieve data from the configuration file =%
  for /f "usebackq tokens=1,* delims==" %%i in ("%config%") do (
    if /i "%%i" EQU "Password" (
      set "ObfuscatedPassword=%%j"
    ) else if /i "%%i" EQU "CN" (
      set "CN=%%j"
    ) else if /i "%%i" EQU "OU" (
      set "OU=%%j"
    ) else if /i "%%i" EQU "O" (
      set "O=%%j"
    ) else if /i "%%i" EQU "L" (
      set "L=%%j"
    ) else if /i "%%i" EQU "ST" (
      set "ST=%%j"
    ) else if /i "%%i" EQU "C" (
      set "C=%%j"
    )
  )
  set "ObfuscatedPasswordEsc=%ObfuscatedPassword:^=^^%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:<=^<%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:>=^>%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:|=^|%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:)=^)%"
  set "ObfuscatedPasswordEsc=%ObfuscatedPasswordEsc:(=^(%"

  %= Use the generated JavaScript file to retrieve the keystore password =%
  for /f "delims=" %%i in ('cscript //nologo //E:jscript "%obfuscate%" "%ObfuscatedPassword%"') do set "password=%%i"
  set "passwordEsc=%password:^=^^%"
  set "passwordEsc=%passwordEsc:<=^<%"
  set "passwordEsc=%passwordEsc:>=^>%"
  set "passwordEsc=%passwordEsc:|=^|%"
  set "passwordEsc=%passwordEsc:)=^)%"
  set "passwordEsc=%passwordEsc:(=^(%"
exit /b

:save
  echo Configuring files...
  setlocal DisableDelayedExpansion

    %= Store data to the main configuration file =%
    (
      echo Password=%ObfuscatedPasswordEsc%
      echo CN=%CN%
      echo OU=%OU%
      echo O=%O%
      echo L=%L%
      echo ST=%ST%
      echo C=%C%
    ) > "%config%"

    %= Modify the WebCTRL configuration files using PowerShell regular expressions =%
    set "psScript=%cd%\Utility.ps1"
    call :generatePSScript > "%psScript%"
    PowerShell -File "%psScript%"
    del /F "%psScript%" >nul 2>nul
  
  endlocal
exit /b

:generatePSScript
  set "passTMP=%password:`=``%"
  set "passTMP=%passTMP:$=`$%"
  echo $Data = (Get-Content "%serverConfig%") -replace '(?^<=keystorePass\=").*?(?=")', "%passTMP%" -replace '(?^<=sslEnabledProtocols\=").*?(?=")', 'TLSv1.3' -replace '(?^<=ciphers\=").*?(?=")', 'TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256' -replace 'Disabled_Connector', 'Connector'
  echo [IO.File]::WriteAllLines('%serverConfig%', $Data)
  set "passTMP=%ObfuscatedPassword:`=``%"
  set "passTMP=%passTMP:$=`$%"
  echo $Data = (Get-Content "%settings%") -replace '(?^<=\.keystorepassword\= ).*', "%passTMP%" -replace '(?^<=\.sslmode\= ).*', 'both' -replace '(?^<=\.tls_mode\= ).*', 'TLSv1_3' -replace '(?^<=\.sslredirect\= ).*', 'true'
  echo [IO.File]::WriteAllLines('%settings%', $Data)
exit /b