Write-Host "==> Checking VM status"
vagrant status

Write-Host "`n==> Checking backend container on app-01"
vagrant ssh app-01 -c "sudo docker ps --filter name=infrastructure-insight-backend"

Write-Host "`n==> Checking frontend container on web-01"
vagrant ssh web-01 -c "sudo docker ps --filter name=infrastructure-insight-frontend"

Write-Host "`n==> Checking frontend container on web-02"
vagrant ssh web-02 -c "sudo docker ps --filter name=infrastructure-insight-frontend"

Write-Host "`n==> Checking backend metrics locally on app-01"
vagrant ssh app-01 -c "curl -s http://localhost:3000/metrics"

Write-Host "`n==> Checking backend access from web-01"
vagrant ssh web-01 -c "curl -s http://localhost/api/metrics"

Write-Host "`n==> Checking backend access from web-02"
vagrant ssh web-02 -c "curl -s http://localhost/api/metrics"

Write-Host "`n==> Checking load balancer round-robin"
1..10 | ForEach-Object {
    curl.exe -s http://192.168.56.10/server-info.json
}

Write-Host "`n==> Checking dashboard through load balancer"
curl.exe -I http://192.168.56.10