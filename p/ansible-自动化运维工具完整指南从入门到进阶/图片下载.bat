<# :
@echo off
chcp 65001 >nul
title Markdown Image Downloader

:: 强制将当前工作目录切换到 bat 脚本所在的目录（即 index.md 所在的目录）
cd /d "%~dp0"

echo ==========================================
echo Scanning index.md in the current folder...
echo ==========================================
echo.

:: 复制自身到临时目录作为 .ps1 执行
set "TEMP_PS1=%TEMP%\img_down_%RANDOM%.ps1"
copy /y "%~nx0" "%TEMP_PS1%" >nul

:: 直接执行，不传递任何路径参数，完全依赖相对路径
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"

:: 清理临时文件
if exist "%TEMP_PS1%" del "%TEMP_PS1%"
echo.
pause
exit /b
#>

# ==================================================
# 100% Relative Path PowerShell Code 
# ==================================================
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# 直接使用相对路径指定文件
$mdFile = "index.md"

# 测试当前目录下是否存在 index.md
if (-not (Test-Path $mdFile)) {
    Write-Host "[x] Error: index.md not found in the current folder!" -ForegroundColor Red
    exit
}

# 读取 MD 文件
$content = [System.IO.File]::ReadAllText($mdFile, [System.Text.Encoding]::UTF8)

# 正则表达式匹配 ![](URL) 或 ![xxx](URL)
$pattern = '!\[.*?\]\((https?://[^\)]+)\)'
$regex = [regex]$pattern

$evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
    param($match)
    $url = $match.Groups[1].Value

    # 提取文件名
    $uri = [System.Uri]$url
    $filename = [System.IO.Path]::GetFileName($uri.LocalPath)
    
    # 过滤掉非法的 Windows 文件名字符
    $filename = $filename -replace '[\\/:\*\?"<>\|]', '_'

    # 直接使用相对路径作为下载目标
    $targetPath = ".\$filename"
    if (-not (Test-Path $targetPath)) {
        Write-Host "[+] Downloading: $filename" -ForegroundColor Cyan
        try {
            # 下载文件并存放在当前目录
            Invoke-WebRequest -Uri $url -OutFile $targetPath -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0"}
        } catch {
            Write-Host "[-] Failed to download: $url" -ForegroundColor Red
        }
    } else {
        Write-Host "[v] Skip (Already exists): $filename" -ForegroundColor DarkGray
    }

    # 替换为当前目录的相对路径
    return "![]($filename)"
}

# 处理正则替换
$newContent = $regex.Replace($content, $evaluator)

# 写回原文件（覆盖）
[System.IO.File]::WriteAllText($mdFile, $newContent, [System.Text.Encoding]::UTF8)

Write-Host "`n[*] Done! All images downloaded to the current folder." -ForegroundColor Green