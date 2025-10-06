@echo off
setlocal
set DIR=%~dp0
set APP_BASE_NAME=%~n0
set APP_HOME=%DIR%
set DEFAULT_JVM_OPTS=
set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar

for %%i in (java.exe) do set JAVA_EXE=%%~$PATH:i
if not defined JAVA_EXE goto findJavaFromJavaHome
goto init

:findJavaFromJavaHome
if not defined JAVA_HOME goto findJavaFromPath
set JAVA_EXE=%JAVA_HOME%\bin\java.exe
if exist "%JAVA_EXE%" goto init
goto fail

:findJavaFromPath
for %%i in (java.exe) do set JAVA_EXE=%%~$PATH:i
if defined JAVA_EXE goto init
echo. 1>&2
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH. 1>&2
echo Please set the JAVA_HOME variable in your environment to match the 1>&2
echo location of your Java installation. 1>&2
goto fail

:init
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*
endlocal
exit /b %ERRORLEVEL%

:fail
endlocal
exit /b 1
