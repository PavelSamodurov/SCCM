#$ResultList = @()
$fileCSV = 'C:\Script\SQLVersions\SqlVersions.csv'
New-Item -Path $fileCSV -Force | Out-Null

$URI = "https://sqlserverbuilds.blogspot.com/"
$HTML = Invoke-WebRequest -Uri $URI -UseBasicParsing
$Content = $html.RawContent
# Create HTML file Object
$HTMLObject = New-Object -Com "HTMLFile"
# Write HTML content according to DOM Level2 
$HTMLObject.IHTMLDocument2_write($Content)

$ListHTML = $HTMLObject.getElementsByTagName('tr') | Select-Object innerHTML

foreach ($item in $ListHTML) {
    $dataList = $item.innerHTML -split "`n" | ForEach-Object {New-Object PSObject -Property ([Ordered] @{"Data" = $_.Trim()})}
    $result = New-Object PSObject -Property ([Ordered] @{
            "Build" = $dataList[0].Data -replace '<[^>]+>',''
            #"Build1" = $list[0].Data.Split(">")[1]
            #"Build2" = $dataList[1].Data -replace '<[^>]+>',''
            "FileVersion" = $dataList[2].Data.Split(">")[1]
            "SQLVersion" = $dataList[2].Data.Split(">")[1].Split(".")[0]
            #"Q" = $dataList[3].Data -replace '<[^>]+>',''
            "KB" = $dataList[4].Data -replace '<[^>]+>',''
            "Link" = $dataList[5].Data.Split("`"")[1]
            "UpdateName" = $dataList[5].Data.Split(">")[2].Trim('</A')
            "ReleaseDate" = $dataList[6].Data.Split("`"")[3]
        })
    #$ResultList += $result
    Add-Content -Path $fileCSV -Value "$($result.Build)|$($result.FileVersion)|$($result.SQLVersion)|$($result.KB)|$($result.Link)|$($result.UpdateName)|$($result.ReleaseDate)"
}
#$ResultList | Export-Csv -Path 'C:\TEMP\SqlVersions.csv' -Delimiter ";"
