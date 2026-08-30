@echo off
setlocal

if "%1"=="--version" (
  echo 1.1.22-test
  exit /b 0
)

if "%AGYSAFE_TEST_MODE%"=="edit" (
  > "%CD%\edited_by_fake.txt" echo isolated edit
)

if "%AGYSAFE_TEST_MODE%"=="quota" (
  echo Error: Individual quota reached.
  echo Resets in 4h5m0s.
  exit /b 1
)

if "%AGYSAFE_TEST_MODE%"=="incomplete" (
  echo I inspected the project and gathered the findings from several files.
  echo I now have enough evidence and all research findings ready for synthesis.
  echo Let me compile the final review report now.
  exit /b 0
)

echo FAKE_AGY_OK
exit /b 0
