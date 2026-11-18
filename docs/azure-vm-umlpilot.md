# Creación de la VM `vm-umlpilot2` en Azure for Students

Documentación paso a paso de todos los comandos ejecutados (PowerShell 7 / `pwsh` en Windows).

- Fecha: 2026-11-11
- Suscripción: `Azure for Students` (`c069e4eb-4667-4c0f-9697-f4ace3bfa9b6`)
- Región final: `southcentralus`
- Resultado: VM `vm-umlpilot2`, Ubuntu 24.04, `Standard_B2ls_v2`, IP pública `52.141.90.74`

> Todos los comandos de este documento se ejecutan en **PowerShell**, salvo los que van
> precedidos de `ssh ...` (que se ejecutan en la VM vía SSH).

---

## 1. Diagnóstico de la suscripción

```powershell
az version
az account show --output json
az account list --output table
```

```powershell
az provider list --query "[?registrationState=='Registered'].namespace" -o tsv | Select-String -Pattern "Compute|Network|Storage"
```

```powershell
az group list --output table
```

Salida relevante: ya existía el grupo `rg-umlpilot` en `eastus`.

```powershell
az vm list-usage --location eastus --output table
```

Este comando mostró las cuotas disponibles (por ejemplo `Standard Bsv2 Family vCPUs: 0/10`,
`Total Regional vCPUs: 0/6`), lo que descartó un problema de cuota.

```powershell
az vm image list --publisher Canonical --offer ubuntu-24_04-lts --sku server --all --output table
```

```powershell
Get-ChildItem "$env:USERPROFILE\.ssh" -ErrorAction SilentlyContinue | Select-Object Name, Length
```

> Nota: `az vm list-skus` (cualquier variante) tarda más de 5 minutos y termina en timeout
> en esta suscripción. Por eso el tamaño de VM se validó con `az vm create --validate`.

---

## 2. Descubrimiento del bloqueo real (política de regiones)

El primer intento de validación en `eastus` falló con `RequestDisallowedByAzure`.

```powershell
$p = "Tmp!" + [guid]::NewGuid().ToString("N").Substring(0,16) + "aA9"
az vm create -g rg-umlpilot -n vm-test-validate --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2s --location eastus --admin-username azureuser --admin-password $p --validate -o json
```

Error obtenido:

```
(RequestDisallowedByAzure) Resource 'vm-test-validateVNET' was disallowed by Azure:
This policy maintains a set of best available regions where your subscription can deploy resources...
```

Se consultó la política asignada a la suscripción:

```powershell
az policy assignment list --disable-scope-strict-match -o json
```

Regiones permitidas por la política `Allowed resource deployment regions`:

```
spaincentral, northcentralus, westus2, canadacentral, southcentralus
```

> `eastus` NO está permitido en Azure for Students. Ese era el motivo del bloqueo inicial.

Validación en `spaincentral` con `Standard_B2s` (falló por capacidad):

```powershell
$p = "Tmp!" + [guid]::NewGuid().ToString("N").Substring(0,16) + "aA9"
az vm create -g rg-umlpilot -n vm-test-validate2 --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2s --location spaincentral --admin-username azureuser --admin-password $p --validate -o json
```

Error obtenido:

```
(SkuNotAvailable) ... Standard_B2s ... not available in location 'SpainCentral'
```

Cuotas en `spaincentral`:

```powershell
az vm list-usage --location spaincentral --query "[?contains(name.value,'CPUs') || contains(name.value,'Family')].{Name:name.localizedValue, Current:currentValue, Limit:limit}" -o table
```

Validaciones que sí pasaron (se ejecutan una por una):

```powershell
# B2ats_v2 -> OK
$p = "Tmp!" + [guid]::NewGuid().ToString("N").Substring(0,16) + "aA9"
az vm create -g rg-umlpilot -n vm-test-validate3 --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2ats_v2 --location spaincentral --admin-username azureuser --admin-password $p --validate -o json
```

```powershell
# B2ls_v2 -> OK
$p = "Tmp!" + [guid]::NewGuid().ToString("N").Substring(0,16) + "aA9"
az vm create -g rg-umlpilot -n vm-val-b2ls --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2ls_v2 --location spaincentral --admin-username azureuser --admin-password $p --validate -o json
```

```powershell
# B2als_v2 -> OK
$p = "Tmp!" + [guid]::NewGuid().ToString("N").Substring(0,16) + "aA9"
az vm create -g rg-umlpilot -n vm-val-b2als --image Canonical:ubuntu-24_04-lts:server:latest --size Standard_B2als_v2 --location spaincentral --admin-username azureuser --admin-password $p --validate -o json
```

> `--validate` no crea nada: solo valida la plantilla. No genera costo.

---

## 3. Consulta de precios (API pública de precios, sin autenticación)

Precios de las familias B en `spaincentral`:

```powershell
$f = "serviceName eq 'Virtual Machines' and armRegionName eq 'spaincentral' and priceType eq 'Consumption' and contains(armSkuName,'Standard_B')"
$u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($f)
$r = Invoke-RestMethod $u
$r.Items | Where-Object { $_.productName -like '*B*' -and $_.skuName -notlike '*Spot*' -and $_.skuName -notlike '*Low Priority*' -and $_.meterName -notlike '*Spot*' } |
  Select-Object armSkuName, skuName, meterName, @{n='USD/h';e={$_.retailPrice}}, @{n='USD/mo';e={[math]::Round($_.retailPrice*730,2)}} |
  Sort-Object 'USD/mo' | Format-Table -AutoSize
```

Precio de `Standard_B2ats_v2`:

```powershell
$f = "serviceName eq 'Virtual Machines' and armRegionName eq 'spaincentral' and priceType eq 'Consumption' and armSkuName eq 'Standard_B2ats_v2'"
$u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($f)
(Invoke-RestMethod $u).Items | Select-Object armSkuName, productName, meterName, @{n='USD/h';e={$_.retailPrice}}, @{n='USD/mo';e={[math]::Round($_.retailPrice*730,2)}} | Format-Table -AutoSize
```

Precio del disco E6 (64 GiB SSD Standard):

```powershell
$f = "serviceName eq 'Storage' and armRegionName eq 'spaincentral' and priceType eq 'Consumption' and contains(meterName,'E6')"
$u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($f)
(Invoke-RestMethod $u).Items | Where-Object { $_.meterName -like '*E6*' -and $_.productName -like '*SSD*' } |
  Select-Object productName, meterName, retailPrice | Format-Table -AutoSize
```

Precios finales en `southcentralus` (región definitiva):

```powershell
$f = "serviceName eq 'Virtual Machines' and armRegionName eq 'southcentralus' and priceType eq 'Consumption' and armSkuName eq 'Standard_B2ls_v2'"
$u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($f)
(Invoke-RestMethod $u).Items | Where-Object { $_.productName -notlike '*Windows*' -and $_.meterName -notlike '*Spot*' -and $_.meterName -notlike '*Low Priority*' } |
  Select-Object productName, meterName, @{n='USD/h';e={$_.retailPrice}}, @{n='USD/mo730';e={[math]::Round($_.retailPrice*730,2)}} | Format-Table -AutoSize
```

```powershell
$q = @(
  @{n='Disco E6 LRS'; f="serviceName eq 'Storage' and armRegionName eq 'southcentralus' and priceType eq 'Consumption' and meterName eq 'E6 LRS Disk'"},
  @{n='IP publica Standard'; f="serviceName eq 'Virtual Network' and armRegionName eq 'southcentralus' and priceType eq 'Consumption' and contains(meterName,'Static Public IP')"}
)
foreach ($x in $q) {
  $u = "https://prices.azure.com/api/retail/prices?`$filter=" + [uri]::EscapeDataString($x.f)
  (Invoke-RestMethod $u).Items | Select-Object -First 2 | ForEach-Object {
    "{0,-22} {1,-28} {2}/h  = {3}/mes" -f $x.n, $_.meterName, $_.retailPrice, [math]::Round($_.retailPrice*730,2)
  }
}
```

Costos resultantes (southcentralus, 24/7):

| Concepto | USD/mes |
|---|---|
| VM `B2ls_v2` (2 vCPU, 4 GB, Linux) | 36.43 |
| Disco SSD 64 GB (E6 LRS) | 4.80 |
| IP pública estática Standard | 3.65 |
| Salida de datos (<100 GB/mes) | 0.00 |
| **Total** | **44.88** |

---

## 4. Creación del par de llaves SSH

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\umlpilot_key" -N '""' -C "umlpilot-azure"
```

> **Error cometido:** en PowerShell `-N '""'` pasa como contraseña la cadena literal `""`
> (dos comillas), no una contraseña vacía. La llave quedó protegida con esa contraseña y
> el login SSH en modo no interactivo fallaba con `Permission denied (publickey)`.
> Se detectó así:

```powershell
ssh-keygen -y -P '""' -f "$env:USERPROFILE\.ssh\umlpilot_key"
ssh-keygen -y -P ''   -f "$env:USERPROFILE\.ssh\umlpilot_key"
```

> El primer comando funcionó (la contraseña era `""`), el segundo falló
> (`incorrect passphrase supplied to decrypt private key`).

Se eliminó la contraseña de forma correcta:

```powershell
ssh-keygen -p -f "$env:USERPROFILE\.ssh\umlpilot_key" -P '""' -N ""
```

Verificación:

```powershell
ssh-keygen -y -P "" -f "$env:USERPROFILE\.ssh\umlpilot_key"
Get-Content "$env:USERPROFILE\.ssh\umlpilot_key.pub"
```

---

## 5. Primera VM (descartada por latencia) en `spaincentral`

Creación:

```powershell
az vm create -g rg-umlpilot -n vm-umlpilot -l spaincentral `
  --image Canonical:ubuntu-24_04-lts:server:latest `
  --size Standard_B2ls_v2 `
  --admin-username azureuser `
  --ssh-key-values "$env:USERPROFILE\.ssh\umlpilot_key.pub" `
  --os-disk-size-gb 64 `
  --storage-sku StandardSSD_LRS `
  --public-ip-sku Standard `
  --nsg-rule SSH `
  --tags proyecto=umlpilot `
  -o json
```

Salida relevante:

```
"location": "spaincentral",
"powerState": "VM running",
"privateIpAddress": "10.0.0.4",
"publicIpAddress": "158.158.37.212"
```

Apertura de puertos (versión inicial, con el puerto equivocado 5433):

```powershell
az vm open-port -g rg-umlpilot -n vm-umlpilot --port 80    --priority 1001 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot --port 443   --priority 1002 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot --port 5433  --priority 1003 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot --port 27017 --priority 1004 -o none
```

```powershell
az network nsg rule list -g rg-umlpilot --nsg-name vm-umlpilotNSG --query "[].{Name:name,Port:destinationPortRange,Source:sourceAddressPrefix,Priority:priority}" -o table
```

Corrección del puerto (5433 -> 5432):

```powershell
az network nsg rule delete -g rg-umlpilot --nsg-name vm-umlpilotNSG -n open-port-5433 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot --port 5432 --priority 1003 -o none
az network nsg rule list -g rg-umlpilot --nsg-name vm-umlpilotNSG --query "[].{Name:name,Port:destinationPortRange,Source:sourceAddressPrefix,Priority:priority}" -o table
```

Verificaciones dentro de la VM:

```powershell
az vm run-command invoke -g rg-umlpilot -n vm-umlpilot --command-id RunShellScript --scripts "cat /home/azureuser/.ssh/authorized_keys" -o json
```

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=20 azureuser@158.158.37.212 "hostname; uname -m; nproc; free -h | head -2; df -h / | tail -1; echo OK-SSH"
```

```powershell
az vm get-instance-view -g rg-umlpilot -n vm-umlpilot --query "{name:name, size:hardwareProfile.vmSize, power:instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0], agent:instanceView.vmAgent.statuses[0].displayStatus}" -o json
```

---

## 6. Medición de latencia desde Bolivia

Prueba ICMP (poco fiable, Azure bloquea ICMP en muchos endpoints):

```powershell
$regions = 'spaincentral','southcentralus','westus2','canadacentral','northcentralus','brazilsouth','eastus2'
foreach ($r in $regions) {
  $h = "$r.blob.core.windows.net"
  $p = Test-Connection -TargetName $h -Count 4 -ErrorAction SilentlyContinue
  if ($p) { "{0,-18} avg {1} ms" -f $r, [math]::Round(($p | Measure-Object -Property ResponseTime -Average).Average) }
  else    { "{0,-18} ICMP bloqueado" -f $r }
}
```

Prueba TCP 443 por hostname (poco fiable por caché DNS):

```powershell
foreach ($r in 'spaincentral','southcentralus','westus2','canadacentral','northcentralus','brazilsouth') {
  $h = "$r.blob.core.windows.net"
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try { $null = [System.Net.Sockets.TcpClient]::new($h, 443).Close() } catch {}
  $sw.Stop()
  "{0,-18} TCP443 {1} ms" -f $r, $sw.ElapsedMilliseconds
}
```

Resolución de IPs para probar por IP (evita caché):

```powershell
foreach ($r in 'spaincentral','southcentralus','westus2','canadacentral','northcentralus','brazilsouth') {
  $ip = (Resolve-DnsName "$r.blob.core.windows.net" -Type A -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress} | Select-Object -First 1).IPAddress
  "{0,-18} {1}" -f $r, $ip
}
```

Latencia real contra la VM de `spaincentral` (5 intentos):

```powershell
1..5 | ForEach-Object {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $c = [Net.Sockets.TcpClient]::new()
    $t = $c.ConnectAsync('158.158.37.212', 22)
    $t.Wait(5000) | Out-Null
    $sw.Stop()
    "intento $_ : $($sw.ElapsedMilliseconds) ms"
    $c.Close()
  } catch { "intento $_ : fallo" }
}
```

Medición por IP contra endpoints de cada región (mediana de 4 intentos):

```powershell
$targets = @{
  'spaincentral'   = 'spaincentral.blob.core.windows.net'
  'southcentralus' = 'southcentralus.blob.core.windows.net'
  'westus2'        = '20.150.90.68'
  'canadacentral'  = '20.209.70.193'
  'northcentralus' = '20.209.39.33'
  'brazilsouth'    = '20.209.1.1'
  'eastus2'        = 'eastus2.blob.core.windows.net'
}
foreach ($k in $targets.Keys) {
  $times = @()
  1..4 | ForEach-Object {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
      $c = [Net.Sockets.TcpClient]::new()
      $t = $c.ConnectAsync($targets[$k], 443)
      if ($t.Wait(5000)) { $sw.Stop(); $times += $sw.ElapsedMilliseconds }
      $c.Close()
    } catch {}
  }
  if ($times.Count) {
    "{0,-18} min {1} / mediana {2} / max {3} ms" -f $k,
      ($times | Measure-Object -Minimum).Minimum,
      [int](($times | Sort-Object)[[int]($times.Count/2)]),
      ($times | Measure-Object -Maximum).Maximum
  } else { "{0,-18} sin respuesta" -f $k }
}
```

Resultado:

| Región permitida | TCP handshake (mediana) |
|---|---|
| spaincentral | ~305 ms |
| southcentralus | ~200 ms |
| westus2 | ~224 ms |
| canadacentral | ~204 ms |
| brazilsouth (no permitida) | ~207 ms |

Comparación final de handshake TCP al puerto 22:

```powershell
function Med($ip) {
  $t = @()
  1..5 | ForEach-Object {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
      $c = [Net.Sockets.TcpClient]::new()
      $x = $c.ConnectAsync($ip, 22)
      if ($x.Wait(5000)) { $sw.Stop(); $t += $sw.ElapsedMilliseconds }
      $c.Close()
    } catch {}
  }
  if ($t.Count) { [int](($t | Sort-Object)[[int]($t.Count/2)]) } else { -1 }
}
"spaincentral (vieja): $(Med '158.158.37.212') ms"
"southcentralus (nueva): $(Med '52.141.90.74') ms"
```

Resultado: `294 ms` -> `223 ms`.

---

## 7. VM definitiva en `southcentralus`

Creación:

```powershell
az vm create -g rg-umlpilot -n vm-umlpilot2 -l southcentralus `
  --image Canonical:ubuntu-24_04-lts:server:latest `
  --size Standard_B2ls_v2 `
  --admin-username azureuser `
  --ssh-key-values "$env:USERPROFILE\.ssh\umlpilot_key.pub" `
  --os-disk-size-gb 64 `
  --storage-sku StandardSSD_LRS `
  --public-ip-sku Standard `
  --nsg-rule SSH `
  --tags proyecto=umlpilot `
  -o json
```

Salida relevante:

```
"location": "southcentralus",
"powerState": "VM running",
"privateIpAddress": "10.0.0.4",
"publicIpAddress": "52.141.90.74"
```

Apertura de puertos (con 5432 correcto):

```powershell
az vm open-port -g rg-umlpilot -n vm-umlpilot2 --port 80    --priority 1001 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot2 --port 443   --priority 1002 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot2 --port 5432  --priority 1003 -o none
az vm open-port -g rg-umlpilot -n vm-umlpilot2 --port 27017 --priority 1004 -o none
```

```powershell
az network nsg rule list -g rg-umlpilot --nsg-name vm-umlpilot2NSG --query "[].{Name:name,Port:destinationPortRange,Priority:priority}" -o table
```

Verificación de SSH y hardware:

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=20 azureuser@52.141.90.74 "hostname; nproc; free -h | head -2; df -h / | tail -1"
```

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=20 azureuser@52.141.90.74 "echo OK-SSH; uptime"
```

Estado final:

```powershell
az vm get-instance-view -g rg-umlpilot -n vm-umlpilot2 --query "{name:name, region:location, size:hardwareProfile.vmSize, power:instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0], agent:instanceView.vmAgent.statuses[0].displayStatus}" -o json
```

Salida:

```json
{ "agent": "Ready", "name": "vm-umlpilot2", "power": "VM running", "region": "southcentralus", "size": "Standard_B2ls_v2" }
```

---

## 8. Eliminación de la VM anterior y sus recursos

Listado de recursos del grupo:

```powershell
az resource list -g rg-umlpilot --query "[].{Name:name,Type:type,Location:location}" -o table
```

Borrado ordenado (primero la VM, luego sus dependencias):

```powershell
az vm delete -g rg-umlpilot -n vm-umlpilot --yes -o none
az disk delete -g rg-umlpilot -n vm-umlpilot_OsDisk_1_97d341aa50bd4ae9aa1cc5908ff5d88c --yes -o none
az network nic delete -g rg-umlpilot -n vm-umlpilotVMNic -o none
az network public-ip delete -g rg-umlpilot -n vm-umlpilotPublicIP -o none
az network nsg delete -g rg-umlpilot -n vm-umlpilotNSG -o none
az network vnet delete -g rg-umlpilot -n vm-umlpilotVNET -o none
```

Verificación:

```powershell
az resource list -g rg-umlpilot --query "[].{Name:name,Type:type,Location:location}" -o table
```

Solo quedaron los recursos `vm-umlpilot2*` en `southcentralus`.

---

## 9. Problema de red: DNS de Azure roto para dominios de Canonical

Síntoma: `sudo apt update` tardaba minutos con `Temporary failure resolving 'archive.ubuntu.com'`
y `snap` respondía `unable to contact snap store`; `certbot` no se encontraba en apt.

### 9.1 Diagnóstico dentro de la VM

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 "cat /etc/resolv.conf; echo '--- resolv status ---'; resolvectl status 2>/dev/null | head -30; echo '--- route ---'; ip route; echo '--- ping gw dns ---'; ping -c 2 -W 2 168.63.129.16; echo '--- nslookup azure dns ---'; nslookup archive.ubuntu.com 168.63.129.16; echo '--- ip directo ---'; timeout 8 curl -sI http://91.189.91.81/ | head -3; echo EXIT=\$?"
```

Hallazgos:

- `nameserver 127.0.0.53` (systemd-resolved) -> upstream `168.63.129.16` (Azure DNS).
- `168.63.129.16` devolvía **SERVFAIL** para `archive.ubuntu.com`.
- Una conexión HTTP directa a `91.189.91.81` sí funcionaba (salida a Internet OK).

Comparación de resolvers:

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 "echo '--- 8.8.8.8 ---'; nslookup archive.ubuntu.com 8.8.8.8; echo '--- 1.1.1.1 ---'; nslookup archive.ubuntu.com 1.1.1.1; echo '--- azure dns microsoft.com ---'; nslookup microsoft.com 168.63.129.16; echo '--- fecha ---'; date -u"
```

`8.8.8.8` y `1.1.1.1` resolvían correctamente; `168.63.129.16` solo fallaba con dominios
de Canonical (`ubuntu.com`, `snapcraft.io`).

Prueba por dominio contra el DNS de Azure:

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'for d in archive.ubuntu.com security.ubuntu.com snapcraft.io api.snapcraft.io google.com microsoft.com pypi.org registry.npmjs.org; do printf "%-26s " $d; timeout 6 nslookup $d 168.63.129.16 2>&1 | grep -Eo "Address: [0-9.]+|SERVFAIL|REFUSED|NXDOMAIN|timed out" | tail -1; done'
```

Resultado: fallaban `archive.ubuntu.com`, `security.ubuntu.com`, `snapcraft.io`, `api.snapcraft.io`;
resolvían `google.com`, `microsoft.com`, `pypi.org`, `registry.npmjs.org`.

### 9.2 Solución aplicada: DNS a nivel de VNet

```powershell
az network vnet update -g rg-umlpilot -n vm-umlpilot2VNET --dns-servers 1.1.1.1 8.8.8.8 -o none
az network vnet show   -g rg-umlpilot -n vm-umlpilot2VNET --query dhcpOptions -o json
```

Reinicio para que la VM tome el nuevo DNS por DHCP:

```powershell
az vm restart -g rg-umlpilot -n vm-umlpilot2 -o none
Start-Sleep -Seconds 25
az vm get-instance-view -g rg-umlpilot -n vm-umlpilot2 --query "instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0]" -o tsv
```

Verificación del DNS tras el reinicio:

```powershell
Start-Sleep -Seconds 15
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=no azureuser@52.141.90.74 'resolvectl status | grep -A2 "Link 2"; echo "--- pruebas ---"; for d in archive.ubuntu.com security.ubuntu.com snapcraft.io api.snapcraft.io; do printf "%-24s " $d; timeout 8 getent hosts $d | head -1 || echo FALLA; done'
```

Resultado: `Current DNS Server: 1.1.1.1`, `DNS Servers: 1.1.1.1 8.8.8.8` y todos los dominios resuelven.

### 9.3 Verificación de apt y certbot

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'time sudo apt-get update -qq 2>&1 | tail -5; echo "EXIT=$?"'
```

Resultado: `real 0m10.570s`.

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'time sudo apt-get install -y certbot >/tmp/certbot.log 2>&1; echo "apt_EXIT=$?"; tail -3 /tmp/certbot.log; certbot --version'
```

Resultado: `apt_EXIT=0`, `certbot 2.9.0`.

### 9.4 Snap store: problema distinto, no resuelto

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'time sudo snap refresh core; echo "snap_EXIT=$?"; sudo snap version | head -3'
```

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'time sudo snap install core; echo "EXIT=$?"; snap list'
```

Resultado: `error: unable to contact snap store` tras 40 s.

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'getent ahostsv4 api.snapcraft.io | head -2; echo ---; timeout 20 curl -sS -o /dev/null -w "https code=%{http_code} tcp=%{time_connect}s total=%{time_total}s\n" https://api.snapcraft.io/v2/snaps/info/core; echo ---; sudo systemctl is-active snapd; sudo journalctl -u snapd -n 15 --no-pager | tail -10'
```

Prueba de conectividad TCP a IPs específicas:

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'for t in "185.125.188.54 443" "91.189.91.81 80" "142.250.72.36 443" "20.70.246.20 443"; do set -- $t; if timeout 8 bash -c "cat < /dev/null > /dev/tcp/$1/$2" 2>/dev/null; then echo "$1:$2 OK"; else echo "$1:$2 FALLA"; fi; done; echo ---; curl -sS -m 15 -o /dev/null -w "https google=%{http_code}\n" https://www.google.com; curl -sS -m 15 -o /dev/null -w "https microsoft=%{http_code}\n" https://www.microsoft.com'
```

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'echo "A records:"; getent ahostsv4 api.snapcraft.io | awk "{print \$1}" | sort -u; echo ---; for ip in $(getent ahostsv4 api.snapcraft.io | awk "{print \$1}" | sort -u); do for p in 80 443; do if timeout 6 bash -c "cat < /dev/null > /dev/tcp/$ip/$p" 2>/dev/null; then echo "$ip:$p OK"; else echo "$ip:$p FALLA"; fi; done; done; echo ---; for ip in 185.125.190.81 185.125.190.82 91.189.91.81; do for p in 80 443; do if timeout 6 bash -c "cat < /dev/null > /dev/tcp/$ip/$p" 2>/dev/null; then echo "$ip:$p OK"; else echo "$ip:$p FALLA"; fi; done; done'
```

Resultado:

- `185.125.188.0/24` (snap store): **todas** las IPs y ambos puertos fallan.
- `185.125.190.x` y `91.189.91.81` (repos Ubuntu): OK en 80 y 443.
- HTTPS a google/microsoft: OK.

Conclusión: el DNS ya está arreglado; el snap store (`185.125.188.0/24`) no es alcanzable
a nivel TCP desde esta VM, por lo que no es un problema de DNS ni del NSG (la salida está
permitida y otros destinos en 443 funcionan). **Workaround: instalar por apt en lugar de snap.**

Comandos auxiliares usados en este diagnóstico:

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'sudo apt-get install -y traceroute >/dev/null 2>&1; sudo timeout 45 traceroute -n -T -p 443 -m 12 185.125.188.54 2>&1 | tail -6'
```

```powershell
ssh -i "$env:USERPROFILE\.ssh\umlpilot_key" -o BatchMode=yes azureuser@52.141.90.74 'echo "-- resolv --"; resolvectl status eth0 | sed -n "2,8p"; echo "-- tcp 20s a snap --"; time timeout 20 bash -c "cat < /dev/null > /dev/tcp/185.125.188.54/443" && echo OK || echo FALLA; echo "-- icmp --"; ping -c 2 -W 3 185.125.188.54 | tail -3'
```

También se probó desde Windows local:

```powershell
curl.exe -sS -m 15 -o NUL -w "local api.snapcraft.io code=%{http_code} connect=%{time_connect}s`n" https://api.snapcraft.io/v2/snaps/info/core
curl.exe -sS -m 15 -o NUL -w "local snapcraft.io code=%{http_code}`n" https://snapcraft.io/
```

Resultado local: no resuelve esos dominios en la red local (problema de DNS del ISP/red local),
por lo que no sirve como punto de comparación.

---

## 10. Operación diaria

Conectarse:

```powershell
ssh -i $env:USERPROFILE\.ssh\umlpilot_key azureuser@52.141.90.74
```

Apagar (deja de cobrar cómputo; el disco y la IP siguen costando ~8.45 USD/mes):

```powershell
az vm deallocate -g rg-umlpilot -n vm-umlpilot2
```

Encender:

```powershell
az vm start -g rg-umlpilot -n vm-umlpilot2
```

Estado:

```powershell
az vm get-instance-view -g rg-umlpilot -n vm-umlpilot2 --query "instanceView.statuses[?starts_with(code,'PowerState')].displayStatus | [0]" -o tsv
```

Reglas del NSG:

```powershell
az network nsg rule list -g rg-umlpilot --nsg-name vm-umlpilot2NSG --query "[].{Name:name,Port:destinationPortRange,Source:sourceAddressPrefix,Priority:priority}" -o table
```

---

## 11. Limpieza total (borrar todo)

```powershell
az group delete -g rg-umlpilot --yes --no-wait
```

> Esto borra la VM, disco, IP, NIC, NSG y VNet del grupo `rg-umlpilot`.

---

## 12. Resumen de decisiones

| Decisión | Motivo |
|---|---|
| Región `southcentralus` | `eastus` bloqueada por política; mejor latencia para Bolivia (~200 ms vs ~300 ms) |
| `Standard_B2ls_v2` | 2 vCPU / 4 GB, ~36 USD/mes; `B2s` no tenía capacidad en spaincentral |
| `StandardSSD_LRS` 64 GB | Suficiente para Docker/imágenes; ~4.80 USD/mes |
| `--public-ip-sku Standard` | SKU Basic retirado; IP estática |
| Llave SSH ed25519 sin passphrase | Acceso no interactivo y automatizable (ver error en sección 4) |
| DNS de VNet `1.1.1.1`/`8.8.8.8` | El DNS de Azure devolvía SERVFAIL para dominios de Canonical |
| `certbot` por apt | El snap store no es alcanzable desde esta VM |
