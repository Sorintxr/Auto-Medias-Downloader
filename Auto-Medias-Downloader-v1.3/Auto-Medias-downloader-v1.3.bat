@echo off
REM Active le delayed expansion pour permettre l'expansion des variables dans les boucles
setlocal enabledelayedexpansion
REM #### NOTE pour l'ensemble du programme : une variable définie au sein d'un bloc (goto) récupérée dans le fichier config.ini ou dans l'interface de sélection n'est pas accessible en dehors de ce bloc. On doit donc à chaque fois la redéfinir dans une nouvelle variable (ex: savePath, AASavePath, BBsavePath, etc.) pour pouvoir l'utiliser en dehors du bloc. (Oui c'est chiant mais c'est comme ça avec le batch)...
title Audio Medias Downloader (v. 1.3) - GauGoth Corp.

echo Copyright (c) 2025 GauGoth Corp. All rights reserved.
echo Welcome to Auto Medias Downloader for Windows (v. 1.3). Need help? Type 'help'!
powershell -Command "Write-Host '[INFO] To switch between audio and video mode, type ""a"""/"""audio""" or """v"""/"""video""" respectively.' -ForegroundColor Yellow"
echo.

REM Vérifie que la license a été acceptée. Si non, on demande de l'accepter.
REM Crée le dossier amd1.3 s'il n'existe pas
if not exist "%~dp0amd1.3" (
    mkdir "%~dp0amd1.3"
)
REM Crée le dossier sources s'il n'existe pas
if not exist "%~dp0amd1.3\sources" (
    mkdir "%~dp0amd1.3\sources"
)
REM Crée le fichier config.ini s'il n'existe pas, avec les valeurs par défaut
set "configFile=%~dp0amd1.3\config.ini"
if not exist "%configFile%" (
    echo savePathChosen: false>"%configFile%"
    echo savePath: C:\Users\%USERNAME%\Music>>"%configFile%"
    echo installChecked: false>>"%configFile%"
    echo mediaType: audio>>"%configFile%"
    echo licenseAccepted: false>>"%configFile%"
)
for /f "tokens=1* delims=:" %%a in ('findstr /b "licenseAccepted:" "%configFile%"') do (set "licenseAccepted=%%b")
set "licenseAccepted=!licenseAccepted:~1!"
if "!licenseAccepted!"=="false" (
    set "toAccept=true"
    powershell -Command "Write-Host 'Before using this program, you must accept the License terms and Conditions below:' -ForegroundColor Red"
    pause
    goto :LICENSE
)

:CHECK_INSTALL
REM Vérifie que yt-dlp est accessible. Si non, on propose de l'installer.
where yt-dlp >nul 2>&1 || (
    goto :INSTALL
)
REM Vérifie que ffmpeg est accessible
where ffmpeg >nul 2>&1 || (
    goto :INSTALL
)
REM Début du programme si yt-dlp est installé
goto :CHOOSE_SAVEPATH

:INSTALL
powershell -Command "Write-Host 'ERROR: yt-dlp is not installed. It is required for this program. Install it? (y/n)' -ForegroundColor Red"
echo Type 'help' for more information about installation.

set "installChoice="
set /p installChoice=
if not defined installChoice (
    set "installChoice="
) else if "%installChoice%"=="" (
    set "installChoice="
) else (
    for /f "delims=" %%a in ('echo %installChoice%^| powershell -Command "$input.Trim().ToLower()"') do set "installChoice=%%a"
)

REM Redirection selon la commande
if "%installChoice%"=="y" goto :INSTALL_YES
if "%installChoice%"=="n" goto :INSTALL_NO
if "%installChoice%"=="exit" goto :INSTALL_NO
if "%installChoice%"=="help" goto :INSTALL_HELP
echo Invalid choice. Please type 'y' to install, 'n' or 'exit' to exit, 'help' for help.
echo.
goto :INSTALL

:INSTALL_YES
:RESTART_ADMIN
REM Vérifie si on tourne en mode administrateur via PowerShell (exit 0 = admin, exit 1 = pas admin)
powershell -NoProfile -Command "If (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo To install yt-dlp, this program requests administrative privileges.
    pause
    REM Relaunch elevated: relance ce script (avec tous ses arguments) dans une nouvelle fenêtre cmd élevée (UAC)
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\" %*' -Verb RunAs"
    exit /b
)

REM Si l'on arrive ici, on est déjà en admin
REM echo Running with administrative privileges.

    set "folder=C:\Program Files\yt-dlp"

    if not exist "%folder%" (
        REM Crée le dossier
        echo Creating directory %folder%...
        mkdir "%folder%" || (
            powershell -Command "Write-Host 'ERROR: Unable to create directory %folder%. Please run this program as Administrator.' -ForegroundColor Red"
            echo.
            goto :INSTALL
        )
    )

    if not exist "%~dp0amd1.3\sources\yt-dlp.exe" (
        powershell -Command "Write-Host 'ERROR: yt-dlp.exe is missing in the script directory. Please place it in the folder amd1.3\sources. If needed, you can still download the software manually: type help.' -ForegroundColor Red"
        echo.
        goto :INSTALL

    )

    REM Copie les fichiers nécessaires
    if not exist "%folder%\yt-dlp.exe" (
        echo Copying yt-dlp to %folder%...
        copy "%~dp0amd1.3\sources\yt-dlp.exe" "%folder%\" >nul || (
            powershell -Command "Write-Host 'ERROR: Unable to copy yt-dlp.exe to %folder%. Please run this program as Administrator.' -ForegroundColor Red"
            echo.
            goto :INSTALL
        )
    )

    if not exist "%~dp0amd1.3\sources\ffmpeg.exe" (
        powershell -Command "Write-Host 'ERROR: ffmpeg.exe is missing in the script directory. Please place it in the folder amd1.3\sources. If needed, you can still download the software manually: type help.' -ForegroundColor Red"
        echo.
        goto :INSTALL

    )
    
    if not exist "%folder%\ffmpeg.exe" (
        echo Copying ffmpeg to %folder%...
        copy "%~dp0amd1.3\sources\ffmpeg.exe" "%folder%\" >nul || (
            powershell -Command "Write-Host 'ERROR: Unable to copy ffmpeg.exe to %folder%. Please run this program as Administrator.' -ForegroundColor Red"
            echo.
            goto :INSTALL
        )
    )
    REM Interroge le registre pour récupérer le PATH système
    reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path | findstr /I /C:"%folder%" >nul

    if errorlevel 1 (
        REM On ajoute le dossier au PATH système
        echo Adding %folder% to system PATH...
        setx path "%PATH%;%folder%" /M || (
            powershell -Command "Write-Host 'ERROR: Unable to set PATH variable for %folder%. Please run this program as Administrator.' -ForegroundColor Red"
            echo.
            goto :INSTALL
        )
    )

    REM Crée un raccourci sur le bureau pour relancer ce script facilement
    set "shortcutPath=%USERPROFILE%\Desktop\Auto Medias Downloader.lnk"
    if not exist "%shortcutPath%" (
        echo Creating shortcut on Desktop...
        powershell -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%shortcutPath%');$s.TargetPath='%~f0';$s.WorkingDirectory='%~dp0';$s.WindowStyle=1;$s.IconLocation='%~dp0amd1.3\sources\amd-icon.ico';$s.Save()"
    )

    REM réecriture du fichier config.ini avec les valeurs par défaut
    set "configFile=%~dp0amd1.3\config.ini"
    if exist "%configFile%" (
        del "%configFile%" >nul 2>&1
    )
    echo savePathChosen: false>"%configFile%"
    echo savePath: C:\Users\%USERNAME%\Music>>"%configFile%"
    echo installChecked: false>>"%configFile%"
    echo mediaType: audio>>"%configFile%"
    REM On considère que l'utilisateur a accepté la license en installant le programme (on peut pas installer sans accepter la license)
    REM Sinon on demanderait deux fois l'acceptation de la license, ce qui serait bête.
    echo licenseAccepted: true>>"%configFile%"
    echo.>>"%configFile%"
    echo Configuration file created at %configFile%.
    echo.
    REM Fin de l'installation
    powershell -Command "Write-Host 'yt-dlp has been installed. This program will now restart to check if everything is working correctly.' -ForegroundColor Green"
    pause
    REM Redémarre le script pour prendre en compte les changements (sans les droits admin, et prenant bien en compte le nouveau PATH)
    start "" "%windir%\explorer.exe" "%~f0"
    exit


:INSTALL_NO
    echo yt-dlp is required for this program to work. Exiting...
    echo.
    pause
    exit
:INSTALL_HELP
    set "installError=true"
    goto :HELP


REM Début du programme si yt-dlp est installé

:CHOOSE_SAVEPATH
REM On demande à l'utilisateur de choisir le dossier de sauvegarde (défini dans le fichier config.ini)
REM Par défaut, c'est "C:\Users\%USERNAME%\Music"
REM Les valeurs possibles dans le fichier config.ini sont:
REM savePathChosen: true/false
REM savePath: C:\Users\%USERNAME%\Music (ou autre dossier choisi par l'utilisateur)
set "configFile=%~dp0amd1.3\config.ini"

REM Si savePathChosen est false, on demande à l'utilisateur de choisir le dossier
REM On lit les valeurs dans le fichier config.ini
for /f "tokens=1* delims=:" %%a in ('findstr /b "savePathChosen:" "%configFile%"') do set "savePathChosen=%%b"
for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%configFile%"') do set "savePath=%%b"
REM Supprime les espaces au début (car il y a un espace après les deux points dans le fichier ini)
set "savePathChosen=!savePathChosen:~1!"
set "savePath=!savePath:~1!"

REM Si savePathChosen est false, on demande à l'utilisateur s'il veut changer le dossier
if "!savePathChosen!"=="false" goto :SAVEPATHCHOSEN_FALSE
if "!savePathChosen!"=="true" goto :MAIN
powershell -Command "Write-Host 'Invalid value for savePathChosen in config.ini. It should be true or false. Please modify the config file or consider re-installing the program. Type help for more information.' -ForegroundColor Red"
echo Here is the current content of config.ini:
type "%configFile%"
echo.
goto :MAIN

:SAVEPATHCHOSEN_FALSE
    set "AAconfigFile=%~dp0amd1.3\config.ini"
    for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%AAconfigFile%"') do set "AAsavePath=%%b"
    set "AAsavePath=!AAsavePath:~1!"

    echo Current backup folder is: !AAsavePath!
    echo Do you want to change it? (y/n^)

    set "changePathChoice="
    set /p changePathChoice=
    if not defined changePathChoice (
        set "changePathChoice="
    ) else if "%changePathChoice%"=="" (
        set "changePathChoice="
    ) else (
        for /f "delims=" %%a in ('echo %changePathChoice%^| powershell -Command "$input.Trim().ToLower()"') do set "changePathChoice=%%a"
    )

    if "%changePathChoice%"=="y" goto :CHANGE_SAVEPATH
    if "%changePathChoice%"=="n" goto :KEEP_SAVEPATH
    if "%changePathChoice%"=="exit" goto :EXIT
    if "%changePathChoice%"=="help" goto :HELP
    echo Invalid choice. Please type 'y' to change, 'n' to keep current path, 'exit' to exit, 'help' for help.
    echo.
    goto :SAVEPATHCHOSEN_FALSE


:CHANGE_SAVEPATH
    echo Please choose a new backup folder in the dialog that will open. Click OK to confirm your choice.
    echo.
    REM Ouvre une boîte de dialogue via PowerShell pour choisir le dossier
    REM On utilise setlocal pour éviter que la variable savePath ne soit visible en dehors de ce bloc

    REM Ouvre une boîte de dialogue "Sélectionner un dossier"
    REM ATTENTION : pour récupérer newSavePath, on doit l'écrire entre "!" après l'avoir définie, car on est en delayed expansion
    REM Sinon, elle sera vide car définie dans une boucle for
    set "BBnewSavePath="
    for /f "usebackq tokens=* delims=" %%i in (`powershell -STA -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Choose a backup folder'; if ($f.ShowDialog() -eq 'OK') { [Console]::WriteLine($f.SelectedPath) }"`) do (
        set "BBnewSavePath=%%i"
    )

    set "BBconfigFile=%~dp0amd1.3\config.ini"

    REM Nettoyage (évite que la variable contienne juste un espace)
    if defined BBnewSavePath (
        set "BBsavePath=!BBnewSavePath:~0!"
        echo New backup folder chosen: "!BBnewSavePath!"
    )

    if not defined BBnewSavePath (
        for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%BBconfigFile%"') do set "BBBsavePath=%%b"
        set "BBBsavePath=!BBBsavePath:~1!" 

        powershell -Command "Write-Host 'No folder selected. Keeping current backup folder: !BBBsavePath!' -ForegroundColor Yellow"
        echo Please note: you can still change it typing the command 'saveto'.
        echo.
        goto :MAIN
    )


    REM Met à jour le fichier config.ini
    powershell -Command "(Get-Content '%BBconfigFile%') -replace 'savePathChosen: false', 'savePathChosen: true' | Set-Content '%BBconfigFile%'"
    
    powershell -Command "(Get-Content '%BBconfigFile%') -replace 'savePath: .*', 'savePath: !BBsavePath!' | Set-Content '%BBconfigFile%'"
    powershell -Command "Write-Host 'backup folder updated to: !BBsavePath!' -ForegroundColor Green"
    echo.

    goto :MAIN

:KEEP_SAVEPATH
    set "CCconfigFile=%~dp0amd1.3\config.ini"

        for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%CCconfigFile%"') do set "CCsavePath=%%b"
        set "CCsavePath=!CCsavePath:~1!" 
        powershell -Command "Write-Host 'Keeping current backup folder: !CCsavePath!' -ForegroundColor Yellow"
        REM si la commande ne trouve pas "savePathChosen: false", c'est qu'on a déjà choisi un dossier avant. N'écrit donc rien.
        powershell -Command "(Get-Content '%CCconfigFile%') -replace 'savePathChosen: false', 'savePathChosen: true' | Set-Content '%CCconfigFile%'"
        echo.
        goto :MAIN

REM Boucle infinie jusqu'à ce que l'utilisateur tape "exit"
:MAIN
set "configFile=%~dp0amd1.3\config.ini"
REM On lit les valeurs dans le fichier config.ini
for /f "tokens=1* delims=:" %%a in ('findstr /b "installChecked:" "%configFile%"') do set "installChecked=%%b"
REM Supprime les espaces au début (car il y a un espace après les deux points dans le fichier ini)
set "installChecked=!installChecked:~1!"

if "!installChecked!" == "false" goto :UPDATES_CHECK


set "installError=false"
REM IMPORTANT: Vider la variable AVANT set /p pour éviter qu'elle garde l'ancienne valeur
set "commandAsIs="

for /f "tokens=1* delims=:" %%a in ('findstr /b "mediaType:" "%configFile%"') do (set "ActualmediaType=%%b")
set "ActualmediaType=!ActualmediaType:~1!"

if "!ActualmediaType!"=="audio" (
    set /p commandAsIs=[AUDIO] Enter the music or playlist URL/ID you want to download: 
) else if "!ActualmediaType!"=="video" (
    set /p commandAsIs=[VIDEO] Enter the video or playlist URL/ID you want to download: 
) else (
    powershell -Command "Write-Host 'ERROR: Invalid value for mediaType in config.ini. It should be audio or video. This program will now re-install itself to fix this issue. Read the README.txt file for more information.' -ForegroundColor Red"
    echo.
    echo Here is the current content of config.ini:
    type "%configFile%"
    echo.
    echo.
    goto :INSTALL_YES
)

REM Vérifier directement si l'utilisateur n'a rien tapé
if not defined commandAsIs (
    set "command="
) else if "%commandAsIs%"=="" (
    set "command="
) else (
    REM Conversion en minuscules via PowerShell avec nettoyage des espaces
    for /f "delims=" %%a in ('echo %commandAsIs%^| powershell -Command "$input.Trim().ToLower()"') do set "command=%%a"
)

REM Redirection selon la commande
if "%command%"=="exit" goto :EXIT
if "%command%"=="help" goto :HELP
if "%command%"=="install" goto :INSTALL_YES
if "%command%"=="uninstall" goto :UNINSTALL
if "%command%"=="update" goto :UPDATES_CHECK
if "%command%"=="saveto" goto :SAVEPATHCHOSEN_FALSE
if "%command%"=="cls" goto :CLS
if "%command%"=="license" goto :LICENSE
if "%command%"=="a" goto :SET_AUDIO
if "%command%"=="audio" goto :SET_AUDIO
if "%command%"=="v" goto :SET_VIDEO
if "%command%"=="video" goto :SET_VIDEO
if "%command%"=="" goto :EMPTY
goto :DOWNLOAD

REM pour help
:HELP
powershell -Command "Write-Host '#### HELP ####' -ForegroundColor Cyan"
echo Auto Medias Downloader is a powerful medias downloading tool. You found a music or a video on Youtube? This tool helps you easily to download it in the best quality possible. It can even download entire playlists.
echo It uses yt-dlp, a command-line software which downloads medias from YouTube and other video sites.
echo Please note: this program works only on Windows 10 and 11.
echo.
echo For information about the license and terms of use, type "license".
echo.
powershell -Command "Write-Host '### HOW TO USE ###' -ForegroundColor Cyan"
powershell -Command "Write-Host '- To switch between audio and video mode, type ""a"""/""audio""" or """v"""/"""video""" respectively.' -ForegroundColor Yellow"
powershell -Command "Write-Host '- To download a media, copy its URL then press Enter (for example from YouTube) (format: https://www.youtube.com/watch?v=dQw4w9WgXcQ) or ID (format: dQw4w9WgXcQ)' -ForegroundColor Yellow"
echo - To download an entire playlist, copy its URL then press Enter (format: https://www.youtube.com/playlist?list=PLK2OhNxdYXeAYLV1BpNXLwlHkZXSwfG0t) or ID (format: PLK2OhNxdYXeAYLV1BpNXLwlHkZXSwfG0t).
echo.
powershell -Command "Write-Host '## WARNING: keep in the URL **only the part before the ''ampersand'' character**, if any. Otherwise, the program may subreptitiously close without warning.' -ForegroundColor Yellow"
echo.
echo - To exit the program and go to the save folder, type "exit".
echo - To update yt-dlp, type "update".
echo - To read the license, type "license".
echo - To clean the screen, type "cls".
echo - To (re)install this program, type "install".
echo - To uninstall this program and yt-dlp, type "uninstall".
echo - To get this help, type "help".
echo.
powershell -Command "Write-Host '- To change the saving folder path, type ""saveto""".' -ForegroundColor Yellow"
echo - The default saving folder is "C:\Users\%USERNAME%\Music".
REM On affiche le dossier de sauvegarde actuel
set "DDconfigFile=%~dp0amd1.3\config.ini"

for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%DDconfigFile%"') do set "DDsavePath=%%b"
set "DDsavePath=!DDsavePath:~1!" 
echo - The downloaded files will be saved in !DDsavePath!
echo.
powershell -Command "Write-Host '### INFORMATION ABOUT SAVE FORMATS ###' -ForegroundColor Cyan"
echo - Audio mode: MP3 format
echo - Video mode: MP4 format
echo - Both formats are downloaded in the best quality possible, with metadata and cover art (if available).
echo --------------------------------------------------------------------------------------------------------
echo.
powershell -Command "Write-Host '### HOW TO INSTALL yt-dlp ###' -ForegroundColor Cyan"
echo This program can install yt-dlp and ffmpeg automatically for you, if you have administrative privileges.
echo.
powershell -Command "Write-Host '### HOW TO INSTALL yt-dlp manually ###' -ForegroundColor Cyan"
echo If you prefer to install yt-dlp manually, follow these steps:
echo    1.  Download yt-dlp for Windows (latest release): https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe
echo    2.  Create a directory called: C:\Program Files\yt-dlp
echo    3.  Put yt-dlp.exe in that directory.
echo    4.  Download yt-dlp's custom ffmpeg build. Download the win64-gpl variant: https://github.com/yt-dlp/FFmpeg-Builds/wiki/Latest
echo    5.  Extract the ffmpeg.exe file from the zip to c:\Program Files\yt-dlp. The other files in the ZIP are not needed.
echo    6.  Click START (Windows logo) button ^> type "envir" ^> Click "Edit the system environment variables"
echo    7.  Click ENVIRONMENT VARIABLES (button at bottom right)
echo    8.  Double click PATH in the top white section
echo    9.  In the window that opens up, add this line: 'C:\Program Files\yt-dlp'
echo    10. Click OK, OK, OK (close all 3 windows) 
echo    11. yt-dlp is now installed.
echo.
powershell -Command "Write-Host '## NOTE: ##' -ForegroundColor Cyan"
echo For more information about installation and yt-dlp, read the following Reddit post: https://www.reddit.com/r/youtubedl/comments/qzqzaz/can_someone_please_post_a_simple_guide_on_making/
echo and the official yt-dlp documentation: https://github.com/yt-dlp/yt-dlp#installation
echo ------------------------------------------------------------------
echo.
echo Copyright (c) 2025 GauGoth Corp. All rights reserved.
echo Visit our website to see our projects: http://gaugoth.corp.free.fr/
echo If you have any questions or feedback, feel free to contact us. We are always happy to answer. http://gaugoth.corp.free.fr/en/credits/contact/
echo.
if "%installError%"=="true" (
    echo ----------------------------------------------------------------------
    echo Note: yt-dlp software is not installed. To install it, please ensure you run this program as Administrator.
    echo.
    goto :INSTALL
)
goto :MAIN

REM pour une URL vide
:EMPTY
echo Please enter a valid URL or command. Type help for more information.
echo.
goto :MAIN

:SET_AUDIO
set "configFile=%~dp0amd1.3\config.ini"
REM Met à jour le fichier config.ini
powershell -Command "(Get-Content '%configFile%') -replace 'mediaType: .*', 'mediaType: audio' | Set-Content '%configFile%'"
powershell -Command "Write-Host 'Switched to audio mode. To switch back to video mode, type ""v""" or """video""".' -ForegroundColor Green"
echo.
goto :MAIN

:SET_VIDEO
set "configFile=%~dp0amd1.3\config.ini"
REM Met à jour le fichier config.ini
powershell -Command "(Get-Content '%configFile%') -replace 'mediaType: .*', 'mediaType: video' | Set-Content '%configFile%'"
powershell -Command "Write-Host 'Switched to video mode. To switch back to audio mode, type ""a""" or """audio""".' -ForegroundColor Green"
echo.
goto :MAIN


:DOWNLOAD
set "configFile=%~dp0amd1.3\config.ini"
for /f "tokens=1* delims=:" %%a in ('findstr /b "mediaType:" "%configFile%"') do (set "ActualmediaType=%%b")
set "ActualmediaType=!ActualmediaType:~1!"

if "!ActualmediaType!"=="audio" (
    goto :DOWNLOAD_AUDIO
) else if "!ActualmediaType!"=="video" (
    goto :DOWNLOAD_VIDEO
) else (
    powershell -Command "Write-Host 'ERROR: Invalid value for mediaType in config.ini. It should be audio or video. To solve this issue, type install to re-install the program. Type help for more information.' -ForegroundColor Red"
    echo.
    echo Here is the current content of config.ini:
    type "%configFile%"
    echo.
    echo.
    goto :MAIN
)


REM on télécharge en format MP3, tout en renommant le fichier avec le titre de la vidéo et récupérant les métadonnées et la jaquette
:DOWNLOAD_AUDIO
REM Vérifie que le dossier de sauvegarde existe

set "configFile=%~dp0amd1.3\config.ini"
for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%configFile%"') do (set "ActualsavePath=%%b")
REM Supprime les espaces au début (car il y a un espace après les deux points dans le fichier ini)
set "ActualsavePath=!ActualsavePath:~1!"

if not exist "!ActualsavePath!" (
    powershell -Command "Write-Host 'backup folder \"!ActualsavePath!\" does not exist. Select a new one.' -ForegroundColor Red"
    echo.
    goto :SAVEPATHCHOSEN_FALSE

)
powershell -Command "Write-Host 'Downloading audio(s)...' -ForegroundColor Yellow"
yt-dlp -f bestaudio -x --audio-format mp3 ^
 --add-metadata ^
 --embed-thumbnail ^
 -o "!ActualsavePath!\%%(title)s.%%(ext)s" "%commandAsIs%"
if errorlevel 1 (
    powershell -Command "Write-Host 'ERROR: Download failed. Please check the URL and your in:DOWNternet connection. Type help for more information.' -ForegroundColor Red"
    echo.
    goto :MAIN
)
powershell -Command "Write-Host 'Audio(s) saved to !ActualsavePath!.' -ForegroundColor Green"

echo.
REM Retour au début de la boucle
goto :MAIN


:DOWNLOAD_VIDEO
REM Vérifie que le dossier de sauvegarde existe

set "configFile=%~dp0amd1.3\config.ini"
for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%configFile%"') do (set "ActualsavePath=%%b")
REM Supprime les espaces au début (car il y a un espace après les deux points dans le fichier ini)
set "ActualsavePath=!ActualsavePath:~1!"

if not exist "!ActualsavePath!" (
    powershell -Command "Write-Host 'backup folder \"!ActualsavePath!\" does not exist. Select a new one.' -ForegroundColor Red"
    echo.
    goto :SAVEPATHCHOSEN_FALSE

)
powershell -Command "Write-Host 'Downloading video(s)...' -ForegroundColor Yellow"
yt-dlp -f "bestvideo[ext=mp4]+bestaudio/bestvideo+bestaudio/best[ext=mp4]/best" --merge-output-format mp4 --add-metadata --embed-thumbnail -S ext:mp4:m4a -o "!ActualsavePath!\%%(title)s.%%(ext)s" "%commandAsIs%"
if errorlevel 1 (
    powershell -Command "Write-Host 'ERROR: Download failed. Please check the URL and your internet connection. Type help for more information.' -ForegroundColor Red"
    echo.
    goto :MAIN
)
powershell -Command "Write-Host 'Video(s) saved to !ActualsavePath!.' -ForegroundColor Green"

echo.
goto :MAIN

REM on vérifie les updates (très important sinon parfois yt-dlp ne fonctionne plus) echo Checking for updates...
:UPDATES_CHECK
REM Si on est déjà passé par l'installation, on ne le refait pas automatiquement (on met à jour donc le fichier config.ini)
REM En effet, trop de requêtes "yt-dlp -U" génèrent une erreur 403 de la part du serveur de yt-dlp
REM ERROR: Unable to obtain version info (HTTP Error 403: rate limit exceeded); Please try again later or visit  https://github.com/yt-dlp/yt-dlp/releases/latest
powershell -Command "(Get-Content '%configFile%') -replace 'installChecked: false', 'installChecked: true' | Set-Content '%configFile%'"

powershell -Command "Write-Host 'Checking for updates...' -ForegroundColor Green"
yt-dlp -U
echo.
goto :MAIN

REM pour exit
:EXIT
REM Vérifie que le dossier de sauvegarde existe
setlocal

set "configFile=%~dp0amd1.3\config.ini"
for /f "tokens=1* delims=:" %%a in ('findstr /b "savePath:" "%configFile%"') do set "ActualsavePath=%%b"
REM Supprime les espaces au début (car il y a un espace après les deux points dans le fichier ini)
set "ActualsavePath=!ActualsavePath:~1!"
if not exist "!ActualsavePath!" exit

start "" "!ActualsavePath!"
endlocal
exit

REM pour afficher la license
:LICENSE
    REM Recherche le fichier LICENSE.txt dans le dossier courant (même niveau que le script)
    set "licenseFile=%~dp0LICENSE.txt"

    if exist "%licenseFile%" (
        echo.
        echo ####################### LICENSE.txt #######################
        type "%licenseFile%"
    ) else (
        powershell -Command "Write-Host 'ERROR: LICENSE.txt file does not exist. Please check the file location in Explorer.' -ForegroundColor Red"
    )
    echo.
    echo.
    if not defined toAccept goto :MAIN

:LICENSE_ASK
    REM Si toAccept est défini, c'est qu'on doit accepter la license pour continuer
    set "toAccept=false"
    powershell -Command "Write-Host 'Do you accept these License terms and Conditions? (y/n)' -ForegroundColor Yellow"

    set "licenseChoice="
    set /p licenseChoice=
    if not defined licenseChoice (
        set "licenseChoice="
    ) else if "%licenseChoice%"=="" (
        set "licenseChoice="
    ) else (
        for /f "delims=" %%a in ('echo %licenseChoice%^| powershell -Command "$input.Trim().ToLower()"') do set "licenseChoice=%%a"
    )

    if "!licenseChoice!"=="y" goto :LICENSE_YES
    if "!licenseChoice!"=="n" goto :LICENSE_NO
    if "!licenseChoice!"=="exit" goto :LICENSE_NO
    if "!licenseChoice!"=="help" goto :LICENSE_HELP
    powershell -Command "Write-Host 'Invalid choice. Please type ''y'' to accept, ''n'' or ''exit'' to exit the program, ''help'' for help.' -ForegroundColor Red"
    echo.
    goto :LICENSE_ASK

:LICENSE_YES
    set "toAccept=false"
    set "configFile=%~dp0amd1.3\config.ini"
    REM Met à jour le fichier config.ini
    powershell -Command "(Get-Content '%configFile%') -replace 'licenseAccepted: false', 'licenseAccepted: true' | Set-Content '%configFile%'"
    powershell -Command "Write-Host 'Thank you for accepting the license terms and conditions. You can now use Auto Medias Downloader.' -ForegroundColor Green"
    echo.
    goto :CHECK_INSTALL

:LICENSE_NO
    powershell -Command "Write-Host 'You must accept the license terms and conditions to use this program. Exiting...' -ForegroundColor Red"
    echo.
    pause
    exit

:LICENSE_HELP
    echo To accept the license terms and conditions, type 'y'. To exit the program, type 'n' or 'exit'. For help, type 'help'.
    echo.
    goto :LICENSE_ASK

REM pour effacer l'écran
:CLS
cls
goto :MAIN

REM pour désinstaller ce programme et toutes ses dépendances
:UNINSTALL
powershell -Command "Write-Host 'WARNING: This will uninstall Auto Medias Downloader and yt-dlp from your system. Are you sure? (y/n)' -ForegroundColor Red"

set "uninstallChoice="
set /p uninstallChoice=
if not defined uninstallChoice (
    set "uninstallChoice="
) else if "%uninstallChoice%"=="" (
    set "uninstallChoice="
) else (
    for /f "delims=" %%a in ('echo %uninstallChoice%^| powershell -Command "$input.Trim().ToLower()"') do set "uninstallChoice=%%a"
)
if "%uninstallChoice%"=="y" goto :UNINSTALL_YES
if "%uninstallChoice%"=="n" goto :UNINSTALL_NO
if "%uninstallChoice%"=="exit" goto :UNINSTALL_NO
if "%uninstallChoice%"=="help" goto :UNINSTALL_HELP
echo Invalid choice. Please type 'y' to uninstall, 'n' or 'exit' to cancel, 'help' for help.
echo.
goto :UNINSTALL

:UNINSTALL_YES
    :RESTART_ADMIN
    REM Vérifie si on tourne en mode administrateur via PowerShell (exit 0 = admin, exit 1 = pas admin)
    powershell -NoProfile -Command "If (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
    if errorlevel 1 (
        echo To uninstall yt-dlp, this program requests administrative privileges.
        pause
        REM Relaunch elevated: relance ce script (avec tous ses arguments) dans une nouvelle fenêtre cmd élevée (UAC)
        powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\" %*' -Verb RunAs"
        exit /b
    )

    REM Si l'on arrive ici, on est déjà en admin
    REM echo Running with administrative privileges.

    echo Uninstalling...
    REM Supprime yt-dlp et ffmpeg
    set "folder=C:\Program Files\yt-dlp"
    if exist "%folder%\yt-dlp.exe" (
        del "%folder%\yt-dlp.exe" >nul 2>&1
    )
    if exist "%folder%\ffmpeg.exe" (
        del "%folder%\ffmpeg.exe" >nul 2>&1
    )
    REM Supprime le dossier si vide
    if exist "%folder%" (
        rd "%folder%" >nul 2>&1
    )
    REM Euh en fait on va éviter de supprimer dans le Path système, car trop violent et risqué
    REM On vérifie si le dossier existe toujours "%folder%"
    if exist "%folder%" (
        powershell -Command "Write-Host 'Note: The folder %folder% could not be deleted, probably because it is not empty. You may delete it manually if you want.' -ForegroundColor Yellow"
        echo.
    )

    REM Supprime le raccourci sur le bureau
    set "shortcutPath=%USERPROFILE%\Desktop\Auto Medias Downloader.lnk"
    if exist "%shortcutPath%" (
        del "%shortcutPath%" >nul 2>&1
    )
    REM Fin de la désinstallation
    powershell -Command "Write-Host 'Auto Medias Downloader and yt-dlp have been successfully uninstalled. Bye!' -ForegroundColor Green"
    echo.
    pause
    start "" "http://gaugoth.corp.free.fr/en/credits/contact/?subject=Uninstallation%%20of%%20Auto%%20Medias%%20Downloader.%%20I%%20just%%20uninstalled%%20Auto%%20Medias%%20Downloader.%%20I%%20would%%20like%%20to%%20give%%20you%%20the%%20following%%20feedback:"

    REM Suppression du dossier Auto-Medias-Downloader et de son contenu (obligé de le faire à la fin, car sinon le script s'arrête quand le script lui-même est supprimé)
    REM Le script est maintenant dans Auto-Medias-Downloader-v1.3/, on doit supprimer ce dossier entier
    
    REM Récupère le chemin du dossier à supprimer (Auto-Medias-Downloader-v1.3)
    set "folder=%~dp0"
    REM Supprime le dernier \ si présent
    if "%folder:~-1%"=="\" set "folder=%folder:~0,-1%"

    REM Se positionne dans le dossier parent (Batch) pour pouvoir supprimer Auto-Medias-Downloader-v1.3
    cd /d "%folder%\.."
    REM Supprime uniquement le dossier Auto-Medias-Downloader-v1.3
    rd /s /q "%folder%" >nul 2>&1
    REM Si le dossier n'a pas pu être supprimé, on affiche un message
    if exist "%folder%" (
        powershell -Command "Write-Host 'Note: The folder Auto-Medias-Downloader could not be deleted. You may delete it manually if you want.' -ForegroundColor Yellow"
        echo.
        pause
    )
    exit


:UNINSTALL_NO
    echo Uninstallation cancelled.
    echo.
    goto :MAIN

:UNINSTALL_HELP
    echo To uninstall, type 'y' to confirm, 'n' or 'exit' to cancel.
    echo.
    goto :UNINSTALL
