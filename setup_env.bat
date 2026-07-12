@echo off
set ANDROID_HOME=D:\Android\sdk
set ANDROID_SDK_ROOT=D:\Android\sdk
set FLUTTER_ROOT=D:\private-agent\flutter_sdk\flutter
set JAVA_HOME=D:\studio neu\jbr
:: Ensure Flutter's Dart is prioritized to avoid conflicts with external Dart installs
set PATH=D:\private-agent\flutter_sdk\flutter\bin;D:\private-agent\flutter_sdk\flutter\bin\cache\dart-sdk\bin;D:\Android\sdk\platform-tools;D:\Android\sdk\cmdline-tools\latest\bin;%PATH%

echo ====================================================
echo PrivateAgent Environment Configured
echo ====================================================
echo ANDROID_HOME:     %ANDROID_HOME%
echo ANDROID_SDK_ROOT: %ANDROID_SDK_ROOT%
echo FLUTTER_ROOT:     %FLUTTER_ROOT%
echo JAVA_HOME:        %JAVA_HOME%
echo.
echo Flutter and Dart executables are now in your PATH.
echo.
flutter --version
dart --version
echo ====================================================
