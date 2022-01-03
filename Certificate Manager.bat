
:: Contributors:
::   Cameron Vogt (@cvogt729)

:: BSD 3-Clause License
:: 
:: Copyright (c) 2022, Automatic Controls Equipment Systems, Inc.
:: All rights reserved.
:: 
:: Redistribution and use in source and binary forms, with or without
:: modification, are permitted provided that the following conditions are met:
:: 
:: 1. Redistributions of source code must retain the above copyright notice, this
::    list of conditions and the following disclaimer.
:: 
:: 2. Redistributions in binary form must reproduce the above copyright notice,
::    this list of conditions and the following disclaimer in the documentation
::    and/or other materials provided with the distribution.
:: 
:: 3. Neither the name of the copyright holder nor the names of its
::    contributors may be used to endorse or promote products derived from
::    this software without specific prior written permission.
:: 
:: THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
:: AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
:: IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
:: DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
:: FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
:: DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
:: SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
:: CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
:: OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
:: OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@echo off
title WebCTRL Certificate Manager
setlocal EnableDelayedExpansion

cd "%~dp0"
set "keystore=%~dp0certkeys"
set "obfuscate=%~dp0Obfuscate.js"
call :normalizePath WebCTRL "%~dp0..\.."
set "keytool=%WebCTRL%\bin\java\jre\bin\keytool.exe"
set "settings=%WebCTRL%\resources\properties\settings.properties"
set "config=%WebCTRL%\webserver\conf\server.xml"
set aliasExists=0

%= Locate keytool utility =%
if not exist "%keytool%" (
  echo.
  echo Error - Unable to locate necessary files.
  echo Please ensure this script is placed in the appropriate folder.
  echo e.g. %HOMEDRIVE%\WebCTRL8.0\webserver\keystores
  echo.
  echo Press any key to exit...
  pause >nul
  exit
)

if exist "%keystore%" (
  echo Recovering password...
  call :recoverPassword
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -list >nul 2>nul
  if %ERRORLEVEL% NEQ 0 (
    call :passwordPrompt
  )
  echo Cleaning keystore...
  call :clear
) else (
  echo Enter a password for the new keystore.
  echo DO NOT USE SPECIAL CHARACTERS ^"^&^^!%%;^?
  set /p "password=>"
  cls
  call :save
)

%= Define various commands =%
set "commands[1]=help"
set "commands[2]=generate"
set "commands[3]=request"
set "commands[4]=import"
set "commands[5]=export"
set "commands=5"

%= Primary command loop =%
:main
  cls
  echo.
  echo WebCTRL Certificate Manager
  echo.
  echo Type 'help' for a list of commands.
  echo.
  :loop
    set "cmd="
    set /p "cmd=>"
    for /f "tokens=1,* delims= " %%a in ("!cmd!") do (
      if /i "%%a" EQU "cls" (
        if "%%b" EQU "" (
          goto :main
        ) else (
          echo Unexpected parameter.
        )
      ) else (
        set "exists=0"
        for /l %%i in (1,1,%commands%) do (
          if /i "!commands[%%i]!" EQU "%%a" set "exists=1"
        )
        if "!exists!" EQU "1" (
          call :!cmd!
        ) else (
          "%keytool%" -keystore "%keystore%" -storepass "!password!" !cmd!
        )
      )
    )
  goto loop

:help
  if "%*" NEQ "" (
    echo Unexpected parameter.
    exit /b
  )
  echo.
  echo Online documentation can be found at
  echo https://github.com/automatic-controls/webctrl-cert-manager/blob/main/README.md
  echo.
  echo CLS               Clear the terminal.
  echo HELP              Display this message.
  echo GENERATE          Generate a new 2048bit RSA key-pair.
  echo REQUEST           Create a certificate signing request.
  echo IMPORT [file]     Import the full certificate reply chain.
  echo EXPORT            Export the primary certificate for inspection.
  echo.
  echo All other commands are passed to keytool.
  echo Type '--help' for a list of valid keytool switches.
  echo Note the '-keystore' and '-storepass' switches are auto-populated.
  echo.
exit /b

:import
  setlocal
  if "%~1" EQU "" (
    call :normalizePath file "%~dp0."
  ) else (
    call :normalizePath file "%~dp0%~1"
  )
  if not exist "%file%" (
    if exist "%~1" (
      set "file=%~1"
    ) else (
      echo The specified file does not exist.
      exit /b
    )
  )
  if exist "%file%\*" (
    set /a cert=0
    for /r "%file%" %%i in (*.*) do (
      set /a cert+=1
      "%keytool%" -keystore "%keystore%" -storepass "!password!" -importcert -alias tmp!cert! -file "%%i" -noprompt >nul 2>nul
    )
    set success=0
    for /r "%file%" %%i in (*.*) do (
      if !success! EQU 0 (
        "%keytool%" -keystore "%keystore%" -storepass "!password!" -importcert -alias webctrl -file "%%i" -noprompt >nul 2>nul
        if !ERRORLEVEL! EQU 0 set success=1
      )
    )
    call :clear
    if !success! EQU 0 (
      echo An error has occurred.
    ) else (
      echo Certificate reply imported successfully.
    )
  ) else (
    "%keytool%" -keystore "%keystore%" -storepass "!password!" -importcert -alias webctrl -file "%file%" -noprompt
    if %ERRORLEVEL% NEQ 0 echo An error has occurred.
  )
exit /b

:generate
  if "%*" NEQ "" (
    echo Unexpected parameter.
    exit /b
  )
  if %aliasExists% EQU 1 (
    "%keytool%" -keystore "%keystore%" -storepass "!password!" -delete -alias webctrl >nul 2>nul
    if !ERRORLEVEL! EQU 0 set aliasExists=0
  )
  setlocal
    echo.
    echo Example: www.somename.net
    echo Common Name ^(CN^):
    set /p "CN=>"
    echo.
    echo Example: IT
    echo Organizational Unit ^(OU^):
    set /p "OU=>"
    echo.
    echo Example: Automatic Controls Equipment Systems
    echo Organization ^(O^):
    set /p "O=>"
    echo.
    echo Example: Fenton
    echo Locality ^(L^):
    set /p "L=>"
    echo.
    echo Example: MO
    echo State or Province (ST):
    set /p "ST=>"
    echo.
    echo Example: US
    echo Country ^(C^):
    set /p "C=>"
    echo.
    echo Example:
    echo   dns:www.somename.net,ip:1.1.1.1
    echo If left blank, SAN will default to:
    echo   dns:!CN!
    echo Subject Alternative Name ^(SAN^):
    set /p "SAN=>"
    echo.
    if "!SAN!" EQU "" set "SAN=dns:!CN!"
    "%keytool%" -keystore "%keystore%" -storepass "!password!" -genkeypair -alias webctrl -keyalg RSA -sigalg SHA256withRSA -keysize 2048 -keypass "!password!" -validity 3650 -ext "san=!SAN!" -dname "CN=!CN!, OU=!OU!, O=!O!, L=!L!, ST=!ST!, C=!C!" >nul
    if %ERRORLEVEL% EQU 0 (
      set aliasExists=1
      echo Key-pair generated successfully.
    ) else (
      echo An error has occurred.
    )
    echo.
  endlocal
exit /b

:request
  if "%*" NEQ "" (
    echo Unexpected parameter.
    exit /b
  )
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -alias webctrl -certreq -file "%~dp0request.csr" >nul 2>nul
  if %ERRORLEVEL% EQU 0 (
    echo %~dp0request.csr
  ) else (
    echo An error has occurred.
  )
exit /b

:export
  if "%*" NEQ "" (
    echo Unexpected parameter.
    exit /b
  )
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -exportcert -alias webctrl -file "%~dp0WebCTRL.cer" >nul 2>nul
  if %ERRORLEVEL% EQU 0 (
    echo %~dp0WebCTRL.cer
  ) else (
    echo An error has occurred.
  )
exit /b

%= Delete extraneous aliases =%
:clear
  set aliasExists=0
  for /f "tokens=2,* delims= " %%i in ('""%keytool%" -keystore "%keystore%" -storepass "!password!" -list -rfc ^| findstr /C:"Alias name: ""') do (
    if "%%j" EQU "webctrl" (
      set aliasExists=1
    ) else (
      "%keytool%" -keystore "%keystore%" -storepass "!password!" -delete -alias "%%j" >nul 2>nul
    )
  )
exit /b

%= Resolves relative paths to fully qualified path names. =%
:normalizePath
  set "%~1=%~f2"
exit /b

%= Prompt the user for the keystore password =%
:passwordPrompt
  echo.
  echo Enter the keystore password.
  echo DO NOT USE SPECIAL CHARACTERS ^"^&^^!%%;^?
  set /p "password=>"
  cls
  echo Checking password...
  "%keytool%" -keystore "%keystore%" -storepass "!password!" -list >nul 2>nul
  if %ERRORLEVEL% NEQ 0 (
    cls
    echo Incorrect password.
    goto :passwordPrompt
  )
  call :save
exit /b

%= Obfuscates text =%
%= First parameter - name of variable to store result =%
%= Second parameter - name of variable which has text to obfuscate =%
:obfuscate
  (
    echo var x = WScript.Arguments^(0^)
    echo var y = ^"^"
    echo for ^(var i=x.length-1;i^>=0;--i^){
    echo     y+=String.fromCharCode^(x.charCodeAt^(i^)^^4^)
    echo }
    echo WScript.Echo^(y^)
  ) > "%obfuscate%"
  for /f "tokens=* delims=" %%i in ('cscript //nologo //E:jscript "%obfuscate%" "!%~2!"') do (
    setlocal DisableDelayedExpansion
    set "tmpVar=%%i"
  )
  (
    endlocal
    set "%~1=%tmpVar%"
  )
  del /F "%obfuscate%" >nul 2>nul
exit /b

:save
  echo Configuring WebCTRL...
  setlocal
    call :obfuscate ob password
    set "password=!password:`=``!"
    set "password=!password:$=`$!"
    set "ob=!ob:`=``!"
    set "ob=!ob:$=`$!"
    call :echoPS > "%~dp0Utility.ps1"
    PowerShell -File "%~dp0Utility.ps1"
    del /F "%~dp0Utility.ps1" >nul 2>nul
  endlocal
exit /b

:echoPS
  echo $Data = (Get-Content "%config%") -replace '(?^<=keystorePass\=").*?(?=")', "!password!" -replace '(?^<=sslEnabledProtocols\=").*?(?=")', 'TLSv1.3' -replace '(?^<=ciphers\=").*?(?=")', 'TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256' -replace 'Disabled_Connector', 'Connector'
  echo [IO.File]::WriteAllLines('%config%', $Data)
  echo $Data = (Get-Content "%settings%") -replace '(?^<=\.keystorepassword\= ).*', "!ob!" -replace '(?^<=\.sslmode\= ).*', 'both' -replace '(?^<=\.tls_mode\= ).*', 'TLSv1_3' -replace '(?^<=\.sslredirect\= ).*', 'true'
  echo [IO.File]::WriteAllLines('%settings%', $Data)
exit /b

:recoverPassword
  call :echoPassPS > "%~dp0Utility.ps1"
  setlocal DisableDelayedExpansion
  for /f "tokens=* delims=" %%i in ('PowerShell -File "%~dp0Utility.ps1"') do (
    set "pass=%%i"
  )
  (
    endlocal
    set "password=%pass%"
  )
  del /F "%~dp0Utility.ps1" >nul 2>nul
exit /b

:echoPassPS
  echo echo([Regex]::Match((Get-Content "%config%"), '(?^<=keystorePass=").*?(?=")').Value)
exit /b