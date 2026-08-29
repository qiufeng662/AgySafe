@echo off
setlocal

if "%1"=="--version" (
  echo 1.1.22-test
  exit /b 0
)

if "%AGYSAFE_TEST_MODE%"=="edit" (
  > "%CD%\edited_by_fake.txt" echo isolated edit
)

echo FAKE_AGY_OK
exit /b 0
