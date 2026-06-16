<# :
@echo off
chcp 65001 >nul
color 0A
echo ==============================================
echo       Markdown 网络图片全自动下载替换脚本
echo ==============================================
echo 正在启动下载引擎，请稍候...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content '%~f0' -Raw -Encoding UTF8)))"
echo.
pause
exit /b
#>

# ---- 下面是 PowerShell 核心逻辑，不要修改 ----

$mdPath = "index.md"

if (-Not (Test-Path $mdPath)) {
    Write-Host "❌ 找不到 index.md！请确保本脚本和 index.md 放在同一个文件夹下。" -ForegroundColor Red
    return
}

Write-Host "🔍 正在读取 index.md ..." -ForegroundColor Yellow
$content = Get-Content -Path $mdPath -Raw -Encoding UTF8
$urls = @()

# 提取正文里的 Markdown 图片链接: ![alt](https://...)
$matchesMd = [regex]::Matches($content, '!\[([^\]]*)\]\((https?://[^\)]+)\)')
foreach ($m in $matchesMd) { $urls += $m.Groups[2].Value }

# 提取顶部前言 (Front Matter) 的封面图链接: image: "https://..."
$matchesFm = [regex]::Matches($content, 'image:\s*"(https?://[^"]+)"')
foreach ($m in $matchesFm) { $urls += $m.Groups[1].Value }

# 去重
$urls = $urls | Select-Object -Unique

if ($urls.Count -eq 0) {
    Write-Host "✅ 没有找到需要下载的网络图片链接。" -ForegroundColor Green
    return
}

Write-Host "📦 共找到 $($urls.Count) 张网络图片，开始下载..." -ForegroundColor Cyan
Write-Host "----------------------------------------------"

$successCount = 0

foreach ($url in $urls) {
    # 从网址中提取文件名，并进行 URL 解码（把 %E5%B0%81 还原成中文）
    $fileName = [System.IO.Path]::GetFileName([uri]::new($url).LocalPath)
    $fileName = [uri]::UnescapeDataString($fileName)
    
    Write-Host "正在下载 -> $fileName"
    
    try {
        # 下载图片
        Invoke-WebRequest -Uri $url -OutFile $fileName -UseBasicParsing
        # 替换 Markdown 文本里的网址为本地文件名
        $content = $content.Replace($url, $fileName)
        Write-Host "  [OK] 下载成功！" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  [Error] 下载失败: $_" -ForegroundColor Red
    }
}

Write-Host "----------------------------------------------"
# 将修改后的内容写回 index.md (强制保存为 UTF-8 防止中文乱码)
Set-Content -Path $mdPath -Value $content -Encoding UTF8

Write-Host "🎉 任务完成！成功下载并替换了 $successCount 张图片。" -ForegroundColor Green
Write-Host "你可以打开 index.md 检查一下，现在它们全是本地路径了！" -ForegroundColor Yellow