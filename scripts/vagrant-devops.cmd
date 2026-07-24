@echo off
setlocal
set VAGRANT_SSH_USER=devops
vagrant %*
exit /b %ERRORLEVEL%
