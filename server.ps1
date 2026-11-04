$port = 8080
$folder = $PSScriptRoot
if (-not $folder) { $folder = (Get-Location).Path }
$ip = [System.Net.IPAddress]::Parse("127.0.0.1")
$listener = New-Object System.Net.Sockets.TcpListener($ip, $port)
$listener.Start()
Write-Host "HTTP Server listening on http://127.0.0.1:$port/"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $requestLine = $reader.ReadLine()
        
        if ($requestLine) {
            $parts = $requestLine.Split(' ')
            if ($parts.Length -ge 2) {
                $rawPath = $parts[1].Split('?')[0].TrimStart('/')
                if ([string]::IsNullOrWhiteSpace($rawPath)) { $rawPath = "index.html" }
                $rawPath = [System.Uri]::UnescapeDataString($rawPath)
                $filePath = Join-Path $folder $rawPath

                if (Test-Path $filePath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $contentType = switch ($ext) {
                        ".html" { "text/html; charset=utf-8" }
                        ".pdf"  { "application/pdf" }
                        ".css"  { "text/css" }
                        ".js"   { "application/javascript" }
                        ".svg"  { "image/svg+xml" }
                        default { "application/octet-stream" }
                    }
                    $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
                    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                    $stream.Write($headerBytes, 0, $headerBytes.Length)
                    $stream.Write($bytes, 0, $bytes.Length)
                } else {
                    $msg = [System.Text.Encoding]::UTF8.GetBytes("<html><body><h1>404 Not Found</h1></body></html>")
                    $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/html`r`nContent-Length: $($msg.Length)`r`nConnection: close`r`n`r`n"
                    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                    $stream.Write($headerBytes, 0, $headerBytes.Length)
                    $stream.Write($msg, 0, $msg.Length)
                }
            }
        }
        $stream.Flush()
        $client.Close()
    }
} finally {
    $listener.Stop()
}
