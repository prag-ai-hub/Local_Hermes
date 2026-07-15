@echo off
rem Windows launcher (PowerShell / cmd). POSIX shells use ./hermes instead.
setlocal
set "HERE=%~dp0"
set "HERMES_HOME=%HERE%.hermes"
set "HERMES_BUNDLED_SKILLS=%HERE%.hermes-skills\skills"
if exist "%HERE%.hermes-skills\optional-skills" set "HERMES_OPTIONAL_SKILLS=%HERE%.hermes-skills\optional-skills"
"%HERE%.venv\Scripts\hermes.exe" %*
