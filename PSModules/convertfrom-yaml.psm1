function get-splittedvalue {
    param (
        [switch] $onlyvalue,
        [Parameter(Mandatory = $true)] $value,
        [Parameter(Mandatory = $true)] $linenumber
    )
    $hash = [ordered]@{}
    $returnvalue = $null
    if ($onlyvalue){
        $processvalue = $value
    } else {
        $valueObj = ConvertFrom-StringData -Delimiter ':' -StringData $value
        $key = $($valueObj.Keys[0])
        $processvalue = $($valueObj.values[0])
    }
    # Cleaning key and value, removing - symbol
    $key = $key -replace '^[\s]*-[\s]+',''
    $processvalue = $processvalue -replace '^[\s]*-[\s]+',''

    write-host "Unprocessed value: [$value]"
    write-host "Processed value: [$processvalue]"
    # If no value it is a key, return hash
    if (!($processvalue -eq "")) { 
        switch -regex ($processvalue) {
            # Processing strings
            # Looks for quotes in the start, denotes a text value
            '^"([\S\s]*)"[\s]*$' {
                $returnvalue = $Matches[1]
                
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
        Write-host "retruning key $($valueObj.keys[0]) and value $($valueObj.values[0])"
        return $valueObj
    }
    
}

function new-helpIndex {
    param (
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$data
    )
    [System.Collections.ArrayList]$helpIndex = @()
    # Looping through data and creating help index
    for($i =0; $i -lt $data.count; $i++ ) {
        $whitespace = $null
        $vartype    = $null
        # Setting vartype to ignore if containing # or empty line (will be removed from the list).
        if($data[$i] -match '(^[\s]*#)|(^\s*$)') {
            $vartype    = "ignore"
        }
         else {
            # Setting the whitespace count for lines that will be kept
            $whitespace = $($($data[$i]).Length - $($($data[$i]) -replace "^\s*","").Length)
            $indent = $($($data[$i]).Length - $($($data[$i]) -replace "^\s*(-\s+)?","").Length)
        }

        # Creating and adding the item to help index list. Setting the original line number (Needed because some lines will be removed).
        $indexItem = [PSCustomObject]@{
            Indent     = $indent
            whitespace = $whitespace
            vartype    = $vartype
            lineNumber = $i
        }
        [void]$helpIndex.add($indexItem)
    }

    # Setting the vartype on every item in the list
    for($i =0; $i -lt $data.count; $i++ ) {
        # If dictionary has multiple lines
        if ($data[$i] -match ':\s+[\|>]\s*$' ) {
            $helpIndex[$i].vartype = "dictionary"
            $firstMline = $i+1
            # Getting all the multilines
            for ($mline = $firstMline; $mline -lt $data.count; $mline++) {
                if ( $helpIndex[$mline].whitespace -ge $helpIndex[$firstMline].whitespace ) {
                    $helpIndex[$mline].vartype = "multiline"
                    $helpIndex[$mline].indent = $helpIndex[$firstMline].indent
                } else {
                    # Not part of multiline. Setting $i to $mline -1 to skip multilines in outer loop (need to check this again)
                    $i = $mline -1
                    break
                }
            }
            
        } elseif ($data[$i] -match '^.*:.*' ) {
            # Checking if array or dictionary
            if ($data[$i+1] -match '^[\s]*[-][\s]+' ) {
                # Indent of next line shoul be greater
                if ($helpIndex[$i].indent -lt $helpIndex[$i+1].indent) {
                    $helpIndex[$i].vartype = $vartype = "array"
                } else {
                    throw "Error on line $($helpIndex[$i].lineNumber). Should be indented"
                }
            } else {
                $helpIndex[$i].vartype = "dictionary"
            }
            
        } elseif ($data[$i] -match '^\s*-\s+(?!.*:).*$' ) {
            $helpIndex[$i].vartype = $vartype = "value"
        } 
    }
    $helpIndex
}

function Get-CleanData {
    param (
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$helpIndex,
        [Parameter(Mandatory = $true)][System.Collections.ArrayList]$data
    )
    for($i = $data.count -1; $i -ge 0; $i-- ) {
        if ($helpIndex[$i].vartype -eq "ignore") {
            [void]$data.RemoveAt($i)
            [void]$helpIndex.RemoveAt($i)
        }
    }
    $mValue = $null
#    $sValue = $null
    for($i = $data.count -1; $i -ge 0; $i-- ) {
        if ($helpIndex[$i].vartype -eq "multiline") {
            if ($helpIndex[$i-1].vartype -eq "multiline") {
                $currentMvalue = $($data[$i-1].substring($helpIndex[$i-1].indent))
            } else {
                $currentMvalue = $($data[$i-1])
            }
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
        # if ($data[$i] -Match "^[\s]*[\S]+.*:[\S]+") {
        #     # If key contains value on line, space after semicolon required
        #     throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). Missing space after ':'"
        # }
        #elseif ($data[$i] -Match "^[\s]*[\S]+.*:[\s]+[\S]+") {
        if ($data[$i] -Match "^[\s]*[\S]+.*:[\s]+[\S]+") {   
            # If key contains value on line, do not allow value on next line ( no indent)
            if ($($helpIndex[$i+1].Indent) -gt $($helpIndex[$i].Indent) ) {
                #throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). While parsing a block mapping, found multipe types"
            }
        } elseif ( -not ($data[$i] -Match "^[\s]*[\S]+.*:[\s]*[\S]*")) {
            # If key does not contain value on line, allow vaule on next line
            # Space after semicolon not required
            #temp# throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). While scanning a simple key, could not find key name or ':'"
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
    [System.Collections.ArrayList] $array = @()
    $vartype = $($helpIndex[$startRow]).vartype
    for($i = $startRow; $i -le $endRow; $i++ ) {
        
        $blockStart = $i+1
        $blockLevel = $helpIndex[$blockStart].Indent

        # Processing block
        $headerLevel = $helpIndex[$i].Indent
        for($blockLine = $i+1; $blockLine -le $endRow; $blockLine++ ) {

            # Should break out if finished with current block:
            if ($helpIndex[$blockLine].Indent -le $headerLevel) {
                break
            }
            #Should continue if still on block level:
            elseif ( $helpIndex[$blockLine].Indent -eq $($blockLevel)) {

                # Getting area to include when parsing (if line on block has a sub block)
                $subBlockCount = $null
                for($z = $blockLine+1; $z -le $endRow; $z++ ) {
                    if ($helpIndex[$z].Indent -le $blockLevel) {
                        # This is not a sub block. Breaking"
                        break                    
                    } elseif ( $helpIndex[$z].Indent -gt $blockLevel) {
                        # This is sub block
                        $subBlockCount++
                    }
                }
                # If the key contains sub keys (block), then we need to parse
                if ($subBlockCount -gt 0) {
                    # Splitting line into key and value (value should be empty because the key contains sub block (keys))
                    ##
                    ##
                    Write-host "blockline is $blockline"
                    $value = get-splittedvalue -value $($inputData[$blockLine]) -lineNumber $helpIndex[$blockLine].lineNumber
                    if($value.values -and $value.values -ne ""){
                        throw "Error, contains value: $($value.values)"
                    } else {
                        Write-host "This is happening, $($value.keys[0])"
                        # Adding value from sub block:
                        $returnedObject =Get-ParsedTree -inputData $inputData -helpIndex $helpIndex -startRow $blockLine -endRow $($blockLine + $subBlockCount)
                        if ($vartype -eq "dictionary") {
                            write-host "dictionary hit. Blockline:$blockline. I am $($value.keys[0]) and I retrieved $($returnedObject.keys)"
                            $hash.Add($($value.keys),$returnedObject)
                        } elseif ($vartype -eq "array") {
                            write-host "array hit. Blockline:$blockline. I am $($value.keys[0]) and I retrieved $($returnedObject.keys)"
                            [void]$array.add(@{$($value.keys) = $returnedObject})
                        }
                        
                    }

                } else {
                    # Does not contain sub block. $vaule.value should contain the value.
                    if ($($helpIndex[$blockLine]).vartype -eq "value") {
                        #$value = $($($inputData[$blockLine].substring($helpIndex[$blockLine].indent)))
                        $value = get-splittedvalue -value $($inputData[$blockLine]) -lineNumber $helpIndex[$blockLine].lineNumber -onlyvalue
                    } else {
                        $value = get-splittedvalue -value $($inputData[$blockLine]) -lineNumber $helpIndex[$blockLine].lineNumber
                    }
                    
                    if ($vartype -eq "dictionary") {
                        write-host "I am on line $blockline"
                        write-host "line number $($helpIndex[$blockLine].lineNumber) $($value.gettype())"
                        $hash += $value
                    } elseif ($vartype -eq "array") {
                 
                        # # Getting all lines that should be included in the element before adding it to the array
                        for ($arrayLine = $blockLine+1; $arrayLine -le $endRow; $arrayLine++) {
                            if ($($helpIndex[$arrayLine]).vartype -ne "dictionary" -or $($helpIndex[$arrayLine]).whitespace -le $($($helpIndex[$blockStart]).whitespace)) {
                                # Breaking. Next line is not part of the hash
                                break
                            } else {
                                 $blockLine ++
                                 if ($($helpIndex[$blockLine]).vartype -eq "value") {
                                    #$value = $($($inputData[$blockLine].substring($helpIndex[$blockLine].indent)))
                                    $valueNext = get-splittedvalue -value $($inputData[$arrayLine]) -lineNumber $helpIndex[$arrayLine].lineNumber -onlyvalue
                                } else {
                                    $valueNext = get-splittedvalue -value $($inputData[$arrayLine]) -lineNumber $helpIndex[$arrayLine].lineNumber
                                }
                                $value += $valueNext
                            }
                        }
                        
                        [void]$array.add($value)
                    
                    }
                    
                }
            
            } else {
                $i = $blockLine #Skipping processed block in outer loop (jump to next block).
                # Skipping grandchildren (will be processed by child function). Can't break because there might be other children.
            }
        }

    }

    if ($vartype -eq "dictionary") {
        $hash
    } else {
        Write-host "returning array $($array.count) with value $($($array[0]).values)"
        @(,$array)
    }
}

function convertfrom-yaml-ps {
    param (
        [Parameter(Mandatory = $true)]$Path
    )
    $inputDataDirty = Get-Content -Path $path
    $helpIndexDirty = new-helpIndex -data $inputDataDirty
    $data = Get-CleanData -data $inputDataDirty -helpIndex $helpIndexDirty
    [array]$inputDataClean = $data.inputDataClean
    [array]$helpIndexClean = $data.helpIndexClean 
    $hash = [ordered]@{}
    for($i = 0; $i -le $inputDataClean.Length; $i++ ) {

        if ($($helpIndexClean[$i].Indent) -eq 0 ) {
            $endRow = $null
            for($n = $i; $n -lt $inputDataClean.Length; $n++ ) {
                if (($($helpIndexClean[$n+1].Indent) -eq 0)) {
                    $endRow = $n
                    break
                }
            }
            if (!$endRow) {
                $endRow = $inputDataClean.Length -1
            }
            Write-host "1"
            $value = get-splittedvalue -value $($inputDataClean[$i]) -lineNumber $helpIndexClean[$i].lineNumber
            if($value.values -and $value.values -ne ""){
                Write-host "2"
                $hash += $value
            } else {
                Write-host "3"
                $returnedObject = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow $i -endRow $($endRow)
                if($($returnedObject.Count) -gt 0) {
                    Write-host "4"
                    $hash.Add($($value.keys),$returnedObject)
                } else {
                    Write-host "5"
                    $hash += $value
                }

            }
        }
    }
    $hash
    #$hash | convertto-json -Depth 100 -ErrorAction stop | convertfrom-json -Depth 100 -ErrorAction stop
}
