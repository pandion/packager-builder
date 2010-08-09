:: This file is part of Pandion Packager
:: Copyright (c) 2010 Sebastiaan Deckers
:: License: GNU General Public License version 3 or later

:: Build Parameters
:: Specified by Packager to Hudson as HTTP POST parameters.
:: Available during the build as environment variables.

:: [string] source_type: official, zip, git
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

:: Parameter filenames
SET custom_brand_xml="brand.xml"
SET custom_default_xml="default.xml"
SET logo_about="logo_about.png"
SET logo_ico="logo.ico"
SET logo_png="logo.png"
SET logo_signin="logo_signin.png"

:: Configure utility paths
::SET UNIX=C:\Program Files (x86)\Git\bin
SET GIT="git.exe"
SET 7ZIP="C:\Program Files\7-Zip\7z.exe"

:: Get a fresh copy of the official Pandion IM source code repository
IF NOT DEFINED WORKSPACE SET WORKSPACE=.
RMDIR /S /Q "%WORKSPACE%/PandionIM"
IF EXIST "%WORKSPACE%/PandionIM" ECHO Error: Cannot clean the build environment && EXIT /B 1
%GIT% clone git://github.com/pandion/pandion.git "%WORKSPACE%/PandionIM"
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clone the official source code repository && EXIT /B 1
CD "%WORKSPACE%/PandionIM"

:: Check for Client source code origin
IF /I %source_type% NEQ official IF /I %source_type% NEQ zip IF /I %source_type% NEQ git ^
	ECHO Error: No source code is specified && EXIT /B 1

:: Client source code from official Pandion IM repository
IF /I %source_type% NEQ official GOTO skip_official
IF %source_official_tag%x EQU x GOTO skip_official
%GIT% checkout %source_official_tag%
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot find the tag "%source_official_tag%" in the official git repository && EXIT /B 1
:skip_official

:: Client source code from ZIP archive
IF /I %source_type% NEQ zip GOTO skip_zip
IF NOT EXIST Client.zip ECHO Error: Missing source code ZIP archive && EXIT /B 1
RMDIR /S /Q "./Client"
IF EXIST "./Client" ECHO Error: Cannot remove the official Client source code && EXIT /B 1
%7ZIP% x -y -oClient Client.zip
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot extract source code ZIP archive && EXIT /B 1
IF NOT EXIST Client\src\main.html IF EXIST Client\Client ROBOCOPY Client\Client Client /E /NJH /NJS /NS /NC /NFL /NDL /MOVE
IF NOT EXIST Client\src\main.html ECHO Error: Invalid source code ZIP archive && EXIT /B 1
:skip_zip

:: Client source code from custom Git repository
IF /I %source_type% NEQ git GOTO skip_git
RMDIR /S /Q "./Client"
IF EXIST "./Client" ECHO Error: Cannot clean the Client subdirectory && EXIT /B 1
RMDIR /S /Q "./ExternalRepository"
IF EXIST "./ExternalRepository" ECHO Error: Cannot clean the ExternalRepository subdirectory && EXIT /B 1
%GIT% clone %source_git_url% ExternalRepository
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clone the repository "%source_git_url%" && EXIT /B 1
ROBOCOPY ExternalRepository\Client Client /E /NJH /NJS /NS /NC /NFL /NDL /MOVE
IF NOT EXIST Client\src\main.html ECHO Error: The git repository is missing Client files && EXIT /B 1
:skip_git

:: Check all file parameters
IF EXIST %custom_brand_xml% IF EXIST %custom_default_xml% IF EXIST %logo_about% IF EXIST %logo_ico% IF EXIST %logo_png% IF EXIST %logo_signin% ^
	GOTO files_exist
ECHO Error: No source code is specified && EXIT /B 1
:files_exist

:: Replace default settings with custom settings
IF EXIST %custom_brand_xml% COPY /Y %custom_brand_xml% Client\settings\brand.xml
IF EXIST %custom_default_xml% COPY /Y %custom_default_xml% Client\settings\default.xml

:: Replace default images with custom images
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
IF NOT DEFINED BUILD_CONFIG CALL "build_config.bat"

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
DEL %custom_brand_xml% %custom_default_xml% %logo_about% %logo_ico% %logo_png% %logo_signin% /Q
IF %ERRORLEVEL% NEQ 0 ECHO Error: Cannot clean up file parameters && EXIT /B 1
