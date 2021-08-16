function get-splittedvalue {
    param (
        [switch] $onlyvalue,
        [Parameter(Mandatory = $true)] $value,
        [Parameter(Mandatory = $true)] $linenumber
    )
    $returnvalue = $null
    if ($onlyvalue){
        $processvalue = $value
        Write-Debug "onlyvalue"
    } else {
        $valueObj = ConvertFrom-StringData -Delimiter ':' -StringData $value
        $key = $($valueObj.Keys[0])
        $processvalue = $($valueObj.values[0])
    }
    # Cleaning key and value, removing - symbol
    $key = $key -replace '^[\s]*-[\s]+',''
    $processvalue = $processvalue -replace '^[\s]*-[\s]+',''
    $processvalue = $processvalue -replace '^[\s]*',''

    Write-Debug "Unprocessed value: [$value]"
    Write-Debug "Processed value: [$processvalue]"
    # If no value it is a key, return hash
    if (!($processvalue -eq "")) { 
        switch -regex ($processvalue) {
            # Processing strings
            # Looks for quotes in the start, denotes a text value
            '^\s*("(.*)"|''(.*)'')\s*$' {
                $returnvalue = $Matches[1]
                $returnvalue = $returnvalue.Substring(1,$returnvalue.Length-2)


                break
            }
            #Processing multiline that preserves NEWLINEs.
            # Find '| some text in one line possibly with \n and paragraphs \n\n in the text' keep it all
            '^\|[\s]*NEWLINE([\S\s]*)' {

                $returnvalue = $($Matches[1].replace("`n",'\n'))
                $returnvalue = $($returnvalue.replace('NEWLINE',"`n"))               
                break
            }
            #Processing multiline that folds NEWLINEs.
            '^>[\s]*NEWLINE([\S\s]*)$' {
                $returnvalue = $($Matches[1].replace("`n",'\n'))
                $returnvalue = $($returnvalue.replace('NEWLINE',"`n"))   
                break
            }
            #Processing False.
            '^[\s]*(?i)(false)[\s]*$' {
                $returnvalue = $false
                break
            }
            #Processing True.
            '^[\s]*(?i)(true)[\s]*$' {
                $returnvalue = $true
                break
            }
            # Processing array
            '^[\s]*\[([\S\s]*)\][\s]*$' {
                try {
                    $returnvalue = @(,$($Matches[0]) | convertfrom-json -Depth 100 -ErrorAction stop)      
                }
                catch {
                    throw "Error on line $linenumber in yaml. $_"
                }
                break
            }
            # Processing hash/json
            '^[\s]*\{([\S\s]*)\}[\s]*$' {
                try {
                    $returnvalue = $($Matches[0] | convertfrom-json -Depth 100 -ErrorAction stop)   
                }
                catch {
                    throw "Error on line $linenumber in yaml. $_"
                }
                break
            }
            default{
                # Processing int's
                try {
                    $returnvalue = [int]$($processvalue)
                }
                # Processing strings
                catch {
                    $returnvalue = $processvalue
                }
            }
        }
    } else { 
        $returnvalue = $processvalue
    }
    if ($onlyvalue){
        return $returnvalue
    } else {
        $valueObj = @{$key = $returnvalue}
        Write-Debug "retruning key $($valueObj.keys[0]) and value $($valueObj.values[0])"
        return $valueObj
    }
    
}

function new-helpIndex {
    param (
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$data
    )
    #$stringPattern = '^(((?!:(\s|$)).)+|\s*(\-\s+)?("([^"]*)"|''([^'']*)''))$'
    $valuePattern = '^(((?!:(\s|$)).)+|\s*(\-\s+)?("([^"]*)"|''([^'']*)''|{(.*)}|\[(.*)\]))$'
    $ignoretPattern = '(^[\s]*#.*$)|(^\s*$)'
    $arrayPattern= '^\s*-\s+.*'
    $notMultilinePattern = '^((((?!:\s(\||>)).)+|\s*(\-\s+)?("([^"]*)"|''([^'']*)''))|\s*)$'
    $onlySpacesPattern = '^\s*$'
    $nonIndentedWithValuePattern = '^[^#\s][\s\S]*$'
    $keyPattern = '^[^:]+?:(\s+("([^"]*)"|''([^'']*)''|(?!:.*:\s.*)|[^"'']*\S+[^"'']*)\s*$|$)'
    [System.Collections.ArrayList]$helpIndex = @()
    # Looping through data and creating help index
    $foundNonIndentedLine = $false
    for($i =0; $i -lt $data.count; $i++ ) {
        $whitespace = $null
        $vartype    = $null
        
        if($data[$i] -match $nonIndentedWithValuePattern) {
            $foundNonIndentedLine = $true
        }
        # Setting vartype to ignore if containing # or empty line (will be removed from the list).
        if($data[$i] -match $ignoretPattern) {
            Write-Debug "on line $i in ignore match"
            $vartype    = "ignore"
        }
        
        # Setting the whitespace count for lines that will be kept
        $whitespace = $($($data[$i]).Length - $($($data[$i]) -replace "^\s*","").Length)
        $indent = $($($data[$i]).Length - $($($data[$i]) -replace "^\s*(-\s+)?","").Length)

        # Creating and adding the item to help index list. Setting the original line number (Needed because some lines will be removed).
        $indexItem = [PSCustomObject]@{
            Indent     = $indent
            whitespace = $whitespace
            vartype    = $vartype
            lineNumber = $i
        }
        [void]$helpIndex.add($indexItem)
    }
    if( -not $foundNonIndentedLine){
        throw "Did not find any non indented lines. Yaml is not valid"
    }
    # Finding multilines. Empty multilines should not be removed
    for($i =0; $i -lt $data.count; $i++ ) {
        if ($data[$i]) {
            
        }
        # If multiline:
        if (-not ($data[$i] -match $notMultilinePattern) ) {
            $helpIndex[$i].vartype = "dictionary"
            $firstMline = $i+1
            # Getting all the multilines
            for ($mline = $firstMline; $mline -lt $data.count; $mline++) {
                if ( ($helpIndex[$mline].whitespace -ge $helpIndex[$firstMline].whitespace) -or (($data[$mline] -match $onlySpacesPattern) -and $helpIndex[$mline+1].whitespace -ge $helpIndex[$firstMline].whitespace) ) {
                    $helpIndex[$mline].vartype = "multiline"
                    $helpIndex[$mline].indent = $helpIndex[$firstMline].indent
                } else {
                    # Not part of multiline. Setting $i to $mline -1 to skip multilines in outer loop (need to check this again)
                    $i = $mline -1
                    break
                }
            }
        }
    }
    # Removing lines that should be ignored
    for($i = $data.count -1; $i -ge 0; $i-- ) {
        if ($helpIndex[$i].vartype -eq "ignore") {
            [void]$data.RemoveAt($i)
            [void]$helpIndex.RemoveAt($i)
        }
    }
    # Setting the vartype on every item in the list
    for($i =0; $i -lt $data.count; $i++ ) {
        # If dictionary has multiple lines

        if ($null -eq $helpIndex[$i].vartype) {
        
            if ( -not ($data[$i] -match $valuePattern) ) {
                # Checking if array or dictionary
                if ($data[$i+1] -match $arrayPattern ) {
                    # Indent
                    if ($helpIndex[$i].indent -lt $helpIndex[$i+1].indent) {
                        $helpIndex[$i].vartype = "array"
                    } else {
                        $helpIndex[$i].vartype = "dictionary"
                    }
                } else {
                    $helpIndex[$i].vartype = "dictionary"
                }
                
            } elseif ($data[$i] -match $valuePattern ) {
                $helpIndex[$i].vartype = "value"
            }
        }
    }
    return [PSCustomObject]@{
        inputDataDirty  = $data
        helpIndexDirty  = $helpIndex
    }
}

function Get-CleanData {
    param (
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$helpIndex,
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$data
    )
    $mValue = $null
#    $sValue = $null
    $onlySpacesPattern = '^\s*$'
    $stringPattern = '^(((?!:(\s|$)).)+|\s*(\-\s+)?("([^"]*)"|''([^'']*)''))$'
    $inArrayPattern = '^\s*-\s+.*$'
    #$keyPattern = '^[^:]+?:(\s+("([^"]*)"|''([^'']*)''|(?!:.*:\s.*)|[^"'']*\S+[^"'']*)\s*$|$)'
    $keyOnlyPattern = '^[^:]+?:\s*$'
    for($i = $data.count -1; $i -ge 0; $i-- ) {
        if ($helpIndex[$i].vartype -eq "multiline") {
            if ($helpIndex[$i-1].vartype -eq "multiline") {
                
                if ($helpIndex[$i-1].whitespace -ge $helpIndex[$i-1].indent) {
                    $currentMvalue = $($data[$i-1].substring($helpIndex[$i-1].indent))
                } else {
                    $currentMvalue = $($data[$i-1].substring($helpIndex[$i-1].whitespace))         
                }

            } else {
                $currentMvalue = $($data[$i-1])
            }
            # if ($helpIndex[$i+1].linenumber -gt $helpIndex[$i].linenumber +1 {

            # }
            if ($mValue) {     
                $mValue = "$currentMvalue" + 'NEWLINE' + "$mValue"
            } else {
                $mValue = "$currentMvalue" + 'NEWLINE' + "$($data[$i].substring($helpIndex[$i].indent))"
            }
            [void]$data.RemoveAt($i)
            [void]$helpIndex.RemoveAt($i)
            
        } else {
            if($mValue) {
                $data[$i] = $mValue + 'NEWLINE'
                $mValue = $null
            } elseif ($sValue) {
                $data[$i] = $sValue
                $sValue = $null
            }
        }
    }

    # Loop and check for errors in yaml (syntax error)
    for($i =0; $i -lt $data.count; $i++ ) {
        #elseif ($data[$i] -Match "^[\s]*[\S]+.*:[\s]+[\S]+") {
        if (-not ($data[$i] -Match $keyOnlyPattern)) {   
            # If key contains value on line, do not allow value on next line ( no indent)
            if ($($helpIndex[$i+1].Indent) -gt $($helpIndex[$i].Indent) ) {
                throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). While parsing a block mapping, found multipe types"
            }
        } elseif ( $data[$i] -Match $stringPattern -and (-not ($data[$i] -Match $inArrayPattern) ) ) {
            # If string/value is no in an array, throw error (we do not support it)
            throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). Multiline string is only supported by using | or >"
        } else {
            $blockLevel =$i+1
            for($x = $i+2; $x -lt $data.count; $x++ ) {
                if ($helpIndex[$x].Indent -le $helpIndex[$i].Indent) {
                    break                    
                }
                if ( ($helpIndex[$x].Indent -gt $helpIndex[$i].Indent) -and ($helpIndex[$x].Indent -lt $($helpIndex[$blockLevel].Indent)) ) {
                    throw "Error on line $($helpIndex[$x].lineNumber), $($inputDataDirty[$($helpIndex[$x].lineNumber)]). While sparsing a block mapping, indent error "
                }
            }
        }
    }
    return [PSCustomObject]@{
        inputDataClean      = $data
        helpIndexClean = $helpIndex
    }
}

function Get-ParsedTree {
    param (
        [Parameter(Mandatory = $true)]$helpIndex,
        [Parameter(Mandatory = $true)]$inputData,
        [Parameter(Mandatory = $true)]$startRow,
        [Parameter(Mandatory = $true)]$endRow
    )
    $hash = [ordered]@{}
    for($i = $startRow; $i -le $endRow; $i++ ) {
        Write-Debug "on top. i is $i"
        # Checking if current row contains an array or not (block of arrays)
        if ($($helpIndex[$i]).vartype -eq "array") {
            [System.Collections.ArrayList] $array = @()
            $hashName = get-splittedvalue -value $($inputData[$i]) -lineNumber $helpIndex[$i].lineNumber
            # Should find block to parse. Looping on every array elemen
            # Should call Get-ParsedTree to parse underlying block. Array should be retrived which will be added to the the key on cunnect line $i

            # Finding array space/block
            [array]$arrayList = $null
            [array]$arrayList += for ($z = $i+1; $z -le $endRow; $z++) {
                if ($($helpIndex[$z]).whitespace -le $($helpIndex[$i+1].whitespace)) {
                    $z
                    if ($($helpIndex[$z]).indent -lt $($helpIndex[$i+1].indent)) {
                        #End of Arrayblock
                        break
                    }
                }
                if ($z -eq $endRow) {
                    # Need extra stop row to measure distance (find stoprow)
                    $($z+1)
                }
            }
            # Lopping over the array elements (parsing every element using get-parsedTree)
            for ($a = 0; $a -lt $arrayList.Length -1; $a++) {
                $stopRow = $($arrayList[$a+1]-1)

                Write-Debug "From Get-ParsedTree array element/block ----------------->>>> StartRow:$($arrayList[$a]) EndRow: $stopRow ----------------------------------------------------------------"
                $returnedData = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow $($arrayList[$a]) -endRow $stopRow
                Write-Debug "From Get-ParsedTree array element/block -----------------<<<< StartRow:$($arrayList[$a]) EndRow: $stopRow ----------------------------------------------------------------"
                [void]$array.Add($returnedData)
            }
            
            # Finished retrieving all array members. Retruning the array
            Write-Debug "Finished retrieving all array members. Retruning the array. Array looks like this: : $(@{$($hashName.keys[0]) = $array} | convertto-json -Depth 100)"
            $hash.add($($hashName.keys[0]), $array.ToArray())

            Write-Debug "Setting i to $stopRow. arrayblock is already processed"
            $i = $stopRow

        } elseif ($($helpIndex[$i]).vartype -eq "dictionary") {
            # Should find block to parse
            # Should call Get-ParedTree to parse underlying block. Dictionary should be retived witch wil be added to the key
            $hashData = get-splittedvalue -value $($inputData[$i]) -lineNumber $helpIndex[$i].lineNumber

            # Finding dictionary space/block
            $count = $null
            for ($n = $i+1; $n -le $endRow; $n++) {
                if ($($helpIndex[$n]).indent -gt $($helpIndex[$i].indent)) {
                    $count++
                } else {
                    break
                }
            }
            if ($count -gt 0) {
                Write-Debug "Hash key name containing the dictionary is $($hashData.keys[0]). Sub block count is $count"
                Write-Debug "From Get-ParsedTree dictionary element/block----------------->>>> StartRow:$($i+1) EndRow: $($i + $count ) ----------------------------------------------------------------"
                $returnedData = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow $($i+1) -endRow $($i + $count )
                Write-Debug "From Get-ParsedTree dictionary element/block-----------------<<<< StartRow:$($i+1) EndRow: $($i + $count ) ----------------------------------------------------------------"
                # Finished retrieving the hashtable members. Retruning the hashtable
                Write-Debug "Finished retrieving all hashtable members. Retruning the hashtable. Hashtable looks like this: : $(@{$($hashData.keys[0]) = $returnedData} | convertto-json -depth 100)"
                $hash.add("$($hashData.keys[0])", $returnedData)
            } else {
                write-Debug "No need to parse. No sub block. Hashtable looks like this: : $($hashData | convertto-json -depth 100)"               
                $hash.add("$($hashData.keys[0])", $($hashData.values[0]))
            }
            Write-Debug "Setting i to $($i + $count ). Dictionary block is already processed"
            $i = $i + $count 

            #Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow 0 -endRow $($inputDataClean.Length -1)
        } elseif ($($helpIndex[$i]).vartype -eq "value") {
            # Should call split to get value. How will this be added as value to the dictionary? This cunnrent session should output only this value. Should only happen if startrow -eq endrow. 
            # If multipe lines, should probably add all value rows ($value+$value)
            $value = get-splittedvalue -value $($inputData[$i]) -lineNumber $helpIndex[$i].lineNumber -onlyvalue
            $value
        } else {
            Throw "Error, unknow vartype: $($($helpIndex[$i]).vartype)"
        }
    }
    if ($hash.Count -ne 0) {
        $hash
    }
}

function convertfrom-yamlps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$Path
    )
    [array]$content = Get-Content -Path $path
    # Adding data from Yaml to a hash with key "processedData". This way we know that the Get-ParsedTree will start with a dictionary and don't need logic to check if array.
    for ($i = 0; $i -lt $content.Count; $i++) {
        $content[$i] = "  $($content[$i])"
    }
    $content = @("processedData:") + $content

    $dataDirty = new-helpIndex -data $content
    $dataClean = Get-CleanData -data $dataDirty.inputDataDirty -helpIndex $dataDirty.helpIndexDirty
    [array]$inputDataClean = $dataClean.inputDataClean
    [array]$helpIndexClean = $dataClean.helpIndexClean
    $tree = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow 0 -endRow $($inputDataClean.Length -1)
    $tree.processedData

}