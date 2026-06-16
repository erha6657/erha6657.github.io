<# :
@echo off
chcp 65001 >nul
color 0A
echo ==============================================
echo      Typora 本地绝对路径图片 自动抓取/替换脚本
echo ==============================================
echo 正在扫描 index.md 并将 C 盘图片复制到当前目录...
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

$content = Get-Content -Path $mdPath -Raw -Encoding UTF8
$successCount = 0

# 正则表达式：匹配类似 ![alt](C:\...\image.png) 的本地绝对路径
# 这里兼容 C盘、D盘 等各种盘符的本地路径
$regex = '!\[([^\]]*)\]\(([A-Za-z]:[^\)]+)\)'
$matches = [regex]::Matches($content, $regex)

if ($matches.Count -eq 0) {
    Write-Host "✅ 没有在 index.md 中找到本地绝对路径的图片。" -ForegroundColor Green
    return
}

Write-Host "📦 共找到 $($matches.Count) 张本地图片，开始复制提取..." -ForegroundColor Cyan
Write-Host "----------------------------------------------"

foreach ($m in $matches) {
    $fullMatch = $m.Groups[0].Value       # 例如: ![img](C:\...\1.png)
    $altText = $m.Groups[1].Value         # 例如: img
    $originalPath = $m.Groups[2].Value    # 例如: C:\...\1.png
    
    # 提取纯文件名
    $fileName = Split-Path $originalPath -Leaf
    
    Write-Host "正在提取 -> $fileName"
    
    if (Test-Path $originalPath) {
        try {
            # 将图片从原路径（如 C盘的临时目录）复制到当前文件夹
            Copy-Item -Path $originalPath -Destination ".\$fileName" -Force
            
            # 替换 Markdown 文本里的绝对路径为相对路径 (文件名)
            $newMatch = "![{0}]({1})" -f $altText, $fileName
            $content = $content.Replace($fullMatch, $newMatch)
            
            Write-Host "  [OK] 复制替换成功！" -ForegroundColor Green
            $successCount++
        } catch {
            Write-Host "  [Error] 复制失败: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [Skip] 找不到原文件，可能已经被删除: $originalPath" -ForegroundColor Yellow
    }
}

Write-Host "----------------------------------------------"
# 将修改后的内容写回 index.md (强制保存为 UTF-8 防止中文乱码)
Set-Content -Path $mdPath -Value $content -Encoding UTF8

Write-Host "🎉 任务完成！成功复制并替换了 $successCount 张本地图片。" -ForegroundColor Green
Write-Host "你可以打开 index.md 检查一下，现在图片路径全是相对路径了！" -ForegroundColor Yellow