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
# Relative Path PowerShell Code (Compatible with MD & HTML img)
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

# 同时兼容 Markdown 格式 ![](URL) 与 HTML 格式 <img src="URL" ...> 的正则表达式
$pattern = '!\[.*?\]\((https?://[^)]+)\)|<img\s+[^>]*src=["''](https?://[^"'']+)["''][^>]*>'
$regex = [regex]$pattern

$evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
    param($match)
    
    # 提取有效 URL
    $url = ""
    if ($match.Groups[1].Success -and $match.Groups[1].Value -ne "") {
        $url = $match.Groups[1].Value  # 匹配到 Markdown 语法
    } elseif ($match.Groups[2].Success -and $match.Groups[2].Value -ne "") {
        $url = $match.Groups[2].Value  # 匹配到 HTML img 语法
    }

    # 如果没有成功提取到 URL，保留原内容
    if (-not $url) {
        return $match.Value
    }

    # 提取文件名
    $uri = [System.Uri]$url
    $filename = [System.IO.Path]::GetFileName($uri.LocalPath)
    
    # 过滤掉非法的 Windows 文件名字符
    $filename = $filename -replace '[\\/:\*\?"<>\|]', '_'

    # 兜底：如果无法获取文件名，则随机生成
    if (-not $filename) {
        $filename = "image_" + (Get-Random) + ".png"
    }

    # 直接使用相对路径作为下载目标
    $targetPath = ".\$filename"
    if (-not (Test-Path $targetPath)) {
        Write-Host "[+] Downloading: $filename" -ForegroundColor Cyan
        try {
            # 下载文件并存放在当前目录
            Invoke-WebRequest -Uri $url -OutFile $targetPath -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        } catch {
            Write-Host "[-] Failed to download: $url" -ForegroundColor Red
        }
    } else {
        Write-Host "[v] Skip (Already exists): $filename" -ForegroundColor DarkGray
    }

    # 统一替换为当前目录的标准 Markdown 相对路径
    return "![]($filename)"
}

# 处理正则替换
$newContent = $regex.Replace($content, $evaluator)

# 写回原文件（覆盖）
[System.IO.File]::WriteAllText($mdFile, $newContent, [System.Text.Encoding]::UTF8)

Write-Host "`n[*] Done! All images downloaded to the current folder and format converted." -ForegroundColor Green