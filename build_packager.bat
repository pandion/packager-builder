:: This file is part of Pandion Packager
:: Copyright (c) 2010 Sebastiaan Deckers
:: License: GNU General Public License version 3 or later

:: Build Parameters
:: Specified by Packager to Hudson as HTTP POST parameters.
:: Available during the build as environment variables.

:: [choice] source_type: official, zip, git
:: [string] source_official_tag: the git tag name on the official Pandion repository
:: [file] source_zip_file: Client.zip
:: [string] source_git_url: the url of the git repository

:: [file] custom_brand_xml: brand.xml
:: [file] custom_default_xml: default.xml
:: [file] logo_about: logo_about.png
:: [file] logo_ico: logo_ico.ico
:: [file] logo_png: logo_png.png
:: [file] logo_signin: logo_signin.png

:: [string] version_major: X.y.z
:: [string] version_minor: x.Y.z
:: [string] version_build: x.y.Z
:: [string] name: display name of the brand
:: [string] name_safe: name used for files and directories, cannot include \ / : * ? " < > |
:: [string] homepage_url: the url of the application homepage
:: [string] company: the name of the application owner organization
:: [string] guid: unique identifier used by Windows Installer for upgrades, default for Pandion IM is {9F661F94-F17F-4F5C-B1C8-2955C85C8FE9}
:: [string] support_url: the url of an online support resource like documentation or user training guide
:: [string] info_url: the url of the application homepage

@ECHO OFF

:: Configure utility paths
::SET UNIX="%ProgramFiles(x86)%\Git\bin"
SET GIT=CALL git
SET SEVENZIP=CALL "%ProgramW6432%\7-Zip\7z.exe"

:: Parameter filenames
IF NOT DEFINED WORKSPACE SET WORKSPACE=%CD%
SET source_zip_file="%WORKSPACE%\Client.zip"
SET custom_brand_xml="%WORKSPACE%\brand.xml"
SET custom_default_xml="%WORKSPACE%\default.xml"
SET logo_about="%WORKSPACE%\logo_about.png"
SET logo_ico="%WORKSPACE%\logo.ico"
SET logo_png="%WORKSPACE%\logo.png"
SET logo_signin="%WORKSPACE%\logo_signin.png"

:: Mock the input when debugging
IF /I "%PACKAGER_DEBUG%" EQU "1" CALL mock_input.bat

:: Input checking: strings/options
FOR %%A IN (source_type version_major version_minor version_build ^
            name name_safe company guid homepage_url support_url info_url) ^
DO IF NOT DEFINED %%A ECHO Error: Missing build parameter option "%%A" && EXIT /B 1

:: Input checking: files
::FOR %%A IN (%source_zip_file% %custom_brand_xml% %custom_default_xml% ^
::            %logo_about% %logo_ico% %logo_png% %logo_signin%) ^
::DO IF NOT EXIST %%A ECHO Error: Missing build parameter file %%A && EXIT /B 1

:: Input checking: custom source code method
IF /I %source_type% NEQ official IF /I %source_type% NEQ zip IF /I %source_type% NEQ git ^
ECHO Error: No source code is specified && EXIT /B 1

:: Cleaning old builds
IF EXIST *.msi DEL *.msi /Q
IF EXIST *.msi ECHO Error: Cannot clean old builds && EXIT /B 1

:: Get a fresh copy of the official Pandion IM source code repository
IF EXIST "%WORKSPACE%\Source" RMDIR /S /Q "%WORKSPACE%\Source"
IF EXIST "%WORKSPACE%\Source" ECHO Error: Cannot clean the build environment && EXIT /B 1
ECHO Getting the official source code
%GIT% clone git://github.com/pandion/pandion.git "%WORKSPACE%\Source"
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clone the official source code repository && EXIT /B 1
CD "%WORKSPACE%\Source"

:: Client source code from official Pandion IM repository
IF /I %source_type% NEQ official GOTO skip_official
ECHO Using source code from official Git repository
IF "%source_official_tag%" EQU "" GOTO skip_official
ECHO Switching to branch %source_official_tag%
%GIT% checkout %source_official_tag%
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot find the tag "%source_official_tag%" in the official git repository && EXIT /B 1
:skip_official

:: Client source code from ZIP archive
IF /I %source_type% NEQ zip GOTO skip_zip
ECHO Using source code from custom ZIP archive
IF NOT EXIST %source_zip_file% ECHO Error: Missing source code ZIP archive && EXIT /B 1
IF EXIST Client RMDIR /S /Q Client
IF EXIST Client ECHO Error: Cannot remove the official Client source code && EXIT /B 1
ECHO Extracting custom Client.zip
%SEVENZIP% x -y -oClient %source_zip_file% > NUL
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot extract source code ZIP archive && EXIT /B 1
IF NOT EXIST Client\src\main.html IF EXIST Client\Client ROBOCOPY Client\Client Client /E /NJH /NJS /NS /NC /NFL /NDL /MOVE
IF NOT EXIST Client\src\main.html ECHO Error: Invalid source code ZIP archive && EXIT /B 1
:skip_zip

:: Client source code from custom Git repository
IF /I %source_type% NEQ git GOTO skip_git
ECHO Using source code from custom Git repository
IF EXIST Client RMDIR /S /Q Client
IF EXIST Client ECHO Error: Cannot clean the Client subdirectory && EXIT /B 1
IF EXIST ExternalRepository RMDIR /S /Q ExternalRepository
IF EXIST ExternalRepository ECHO Error: Cannot clean the ExternalRepository subdirectory && EXIT /B 1
%GIT% clone %source_git_url% ExternalRepository
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clone the repository "%source_git_url%" && EXIT /B 1
ROBOCOPY ExternalRepository\Client Client /E /NJH /NJS /NS /NC /NFL /NDL /MOVE
IF NOT EXIST Client\src\main.html ECHO Error: The git repository is missing Client files && EXIT /B 1
:skip_git

:: Replace default settings with custom settings
ECHO Customizing settings
IF EXIST %custom_brand_xml% COPY /Y %custom_brand_xml% Client\settings\brand.xml
IF EXIST %custom_default_xml% COPY /Y %custom_default_xml% Client\settings\default.xml

:: Replace default images with custom images
ECHO Customizing images
IF EXIST %logo_about% COPY /Y %logo_about% Client\images\about\logo.png
IF EXIST %logo_ico% COPY /Y %logo_ico% Client\images\brand\default.ico
IF EXIST %logo_ico% COPY /Y %logo_ico% Host\Source\default.ico
IF EXIST %logo_png% COPY /Y %logo_png% Client\images\main\logo.png
IF EXIST %logo_signin% COPY /Y %logo_signin% Client\images\sign-in\logo-shiny-hover.png

:: TODO: Add the needed Extras
:: ...

:: Prepare the version number
SET VERSION_MAJOR=%version_major%
SET VERSION_MINOR=%version_minor%
SET VERSION_BUILD=%version_build%

:: Set meta information for the build
SET JOB_NAME=%name%
SET JOB_NAME_SAFE=%name_safe%
SET HOST_COMMENTS=%homepage_url%
SET HOST_COMPANY=%company%
SET MSI_GUID=%guid%
SET MSI_HELP_URL=%support_url%
SET MSI_INFO_URL=%info_url%

:: Prepare default build settings
CALL "build_config.bat"

:: Compile Host
ECHO Compiling Host...
CD ".\Host"
CALL "build_host.bat"
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot compile Host && EXIT /B 1
CD ..

:: Build MSI package
ECHO Building MSI package...
CD ".\Installer\WiX"
DEL "*.msi" /Q
CALL "build_msi.bat"
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot build MSI package && EXIT /B 1
CD "..\.."

:: Clean up the file parameters
ECHO Cleaning up file parameters
DEL %source_zip_file% %custom_brand_xml% %custom_default_xml% %logo_about% %logo_ico% %logo_png% %logo_signin% /Q
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clean up file parameters && EXIT /B 1

:: Present the setup artifact to Hudson and report the correct exit code
CD ..
ECHO Locating artifact
ROBOCOPY .\Source\Installer\WiX . *.msi /MOV /NJH /NJS /NS /NC /NFL /NDL
IF %ERRORLEVEL% NEQ 1 ECHO Error: Failed to locate artifact && EXIT /B 1
IF %ERRORLEVEL% EQU 1 SET ERRORLEVEL=0
