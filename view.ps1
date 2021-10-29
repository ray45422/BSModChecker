Set-StrictMode -Version Latest

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -Name 'Window' -Namespace 'Win32Functions' -MemberDefinition @"
[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr handle, int state);
[DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr handle);
"@

$DownloadDir = 'Downloads'
$tempDir = 'temp'
$credentialPath = 'credential.txt'
$modListPath = 'modList.txt'


if(!(Test-Path $DownloadDir)) {
    $null = New-Item -ItemType Directory -Path $DownloadDir
}

if(!(Test-Path $tempDir)) {
    $null = New-Item -ItemType Directory -Path $tempDir
}

class ModItem {
    [string]$Name
    [string]$URL
    [string]$ReleaseTitle
    [string]$ReleaseDesc
    $EventRepo
    $EventDownload
    $EventInstall
    $APIResult
}

function Get-RequestHeader($Uri) {
    $header = @{}
    if(Test-Path $credentialPath) {
        [object[]]$creds = Get-Content $credentialPath -Encoding UTF8 | Where-Object {$_ -ne '' -and $_ -match '.+:.+'}
        $cred = $creds[0]
        $cred = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($cred))
        $cred = "Basic $cred"
        $header.Authorization = $cred
    }
    return $header
}
function Get-ModList() {
    $releaseEndPoint = "https://api.github.com/repos"
    
    $list = [System.Collections.Generic.List[ModItem]]::new()

    if(!(Test-Path -LiteralPath $modListPath)) {
        throw 'modList.txt がありません'
    }
    
    Get-Content -LiteralPath $modListPath -Encoding UTF8 | ForEach-Object {
        $url = $_
    
        if($url -notmatch 'https://github.com/\w+/\w+/?.*') {
            "invalid URL: $_" | Write-Host -ForegroundColor Red
            return
        }
    
        $e = $url -split '/'
    
        $i = [ModItem]::new()
        $list.Add($i)
        $i.Name = $e[3] + "/" + $e[4]
        $i.URL = $url
    
        $api = "{0}/{1}/releases/latest" -f $releaseEndPoint, $i.Name
    
        $result = Invoke-WebRequest -Uri $api -Headers (Get-RequestHeader)
        if($result.StatusCode -ne 200) {
            $i.ReleaseTitle = '取得失敗'
            "情報の取得に失敗: $" | Write-Host -ForegroundColor Red
            return
        }
        $result = $result.Content | ConvertFrom-Json
        $i.ReleaseTitle = $result.name
        $i.ReleaseDesc = $result.body
        $i.APIResult = $result
    }
    
    return $list
}

function Get-AssetName($url) {
    $name = $url -split '/'
    $name = $name[$name.Length - 1]
    return [System.Web.HttpUtility]::UrlDecode($name)
}

function Download-Asset() {
    process {
        $url = $_
        $name = Get-AssetName $url
        $path = "$DownloadDir\$name"
        $r = Invoke-WebRequest -Uri $url -OutFile $path -Headers (Get-RequestHeader)
        $url | Write-Host -ForegroundColor Green
    }
}

function Install-Plugin() {
    process {
        $item = Get-Item "$DownloadDir\$_"
        switch ($item.Extension) {
            '.zip' {
                Expand-Archive -LiteralPath $item.FullName -DestinationPath $tempDir -Force
            }
            '.dll' {
                $null = Copy-Item -LiteralPath $item.FullName -Destination "$tempDir\Plugins" -Force
            }
            Default {
                "not implemented asset type: $_" | Write-Host -ForegroundColor Red
            }
        }
    }
}

function Show-MainWindow() {
    [xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MODChecker"
    SizeToContent="WidthAndHeight"
    MinWidth="500"
    Margin="5"
>
<Window.Resources>
    <DataTemplate x:Key="ItemTemplate">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition />
                <ColumnDefinition />
                <ColumnDefinition />
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition />
                <RowDefinition />
                <RowDefinition />
                <RowDefinition />
                <RowDefinition />
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="3" Text="{Binding Path=Name}" FontSize="16" Margin="5,0,0,0" />
            <Button Grid.Row="1" Grid.Column="0" Content="OpenRepo" Command="{Binding EventRepo}" CommandParameter="{Binding Path=URL}" />
            <Button Grid.Row="1" Grid.Column="1" Content="DownloadAsset" Command="{Binding EventDownload}" CommandParameter="{Binding Path=APIResult}" />
            <Button Grid.Row="1" Grid.Column="2" Content="Install" Command="{Binding EventInstall}" CommandParameter="{Binding Path=APIResult}" />
            <TextBlock Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Text="{Binding Path=ReleaseTitle}" FontSize="16" Margin="5,0,0,0" />
            <TextBlock Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" Text="{Binding Path=ReleaseDesc}" FontSize="12" Margin="5,0,0,0" />
            <Separator Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,5,0,5" />
        </Grid>
    </DataTemplate>
</Window.Resources>
<Grid Name="mod">
    <Grid.ColumnDefinitions>
        <ColumnDefinition />
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
    <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition />
    </Grid.RowDefinitions>

    <TextBox Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3" Name="BeatSaberPath" VerticalContentAlignment="Center" Height="Auto" FontSize="12" Margin="5,0,5,5" AllowDrop="true"></TextBox>
    <ScrollViewer Name="ScrollViewer" Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3"
        VerticalScrollBarVisibility="auto"
        HorizontalScrollBarVisibility="auto">
        <ItemsControl
            Name="MODList"
            MinWidth="400"
            ItemTemplate="{StaticResource ItemTemplate}">
        </ItemsControl>
    </ScrollViewer>
</Grid>
</Window>
'@

    Add-Type -TypeDefinition @'
using System;
using System.Windows.Input;
public class DelegateCommand : ICommand
{
    Action<Object> execute;
    public DelegateCommand(Action<Object> execute)
    {
        this.execute = execute;
    }
    public bool CanExecute(Object obj)
    {
        return true;
    }
    public void Execute(Object obj)
    {
        execute(obj);
    }
    public event EventHandler CanExecuteChanged;
    public void RaiseCanExecuteChanged()
    {
        var d = CanExecuteChanged;
        if(d != null)
        {
            d(this, EventArgs.Empty);
        }
    }
}
'@

    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    $window=[Windows.Markup.XamlReader]::Load($reader)

    $modList = $window.FindName("MODList")
    $list = Get-ModList
    $eventRepo = [DelegateCommand]::new({
        explorer $args[0]
    })
    $eventDownload = [DelegateCommand]::new({
        $args[0].assets | ForEach-Object {
            $_.browser_download_url
        } | Download-Asset
    })
    $eventInstall = [DelegateCommand]::new({
        $args[0].assets | ForEach-Object {
            $name = Get-AssetName $_.browser_download_url
            if(Test-Path "$DownloadDir\$name") {
                return $name
            }
            $null = $_.browser_download_url | Download-Asset
            return $name
        } | Install-Plugin
    })
    foreach($i in $list) {
        $i.EventRepo = $eventRepo
        $i.EventDownload = $eventDownload
        $i.EventInstall = $eventInstall
    }
    $modList.ItemsSource = $list

    $null = [Win32Functions.Window]::ShowWindow($script:wHandle, 0)
    $window.ShowDialog() | Out-Null
}

$script:original = $null
$script:wHandle = (Get-Process -Id $pid).MainWindowHandle
$proc_id = $pid
for($i = 0; $i -lt 100 -and $script:wHandle -eq 0; $i++) {
    if($PSVersionTable.PSVersion.Major -gt 5) {
        $pproc = Get-CimInstance -Class win32_process -Filter "processid=$proc_id"
    } else {
        $pproc = Get-WmiObject -Class win32_process -Filter "processid=$proc_id"
    }
    $proc_id = $pproc.ParentProcessId
    $script:wHandle = (Get-Process -Id $proc_id).MainWindowHandle
}

Show-MainWindow

trap {
    $null = [Win32Functions.Window]::ShowWindow($script:wHandle, 1)
    $_ | Out-String | Write-Host -ForegroundColor Red
    $e = $_.Exception
    while($null -ne $e.InnerException) {
        $e, $e.StackTrace | Out-String | Write-Host -ForegroundColor Red
        $e = $e.InnerException
    }
    $null = $Host.UI.RawUI.ReadKey()
    exit
}
