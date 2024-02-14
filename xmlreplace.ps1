foreach($xmlName in $xmlNames) {
    $uri = 'https://raw.githubusercontent.com/palantir/windows-event-forwarding/master/wef-subscriptions/' + $xmlName
    $outFile = $env:TEMP + '\' + $wefDirectory + '\' + $xmlName
    Invoke-WebRequest -Uri $uri -OutFile $outFile
    $xmlContents = Get-Content $outFile -Raw
    # use Regex "(?<=<LogFile>)[^<]*(?=<\/LogFile>)" to replace the contents of the xml tag named "<LogFile>example</LogFile>" with the value "<LogFile>ForwardedEvents</LogFile>" 
    $xmlContents = $xmlContents -replace '(?<=<LogFile>)[^<]*(?=<\/LogFile>)', 'ForwardedEvents'
    Set-Content $outFile $xmlContents
    # Get all subscription names
    $subscriptions = wecutil es
    # Loop through each subscription and delete it
    foreach ($subscription in $subscriptions)
    {
        wecutil ds $subscription
    }
}