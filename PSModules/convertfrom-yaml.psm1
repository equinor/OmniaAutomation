function get-splittedvalue {
    param (
        [Parameter(Mandatory = $true)]$value,
        [Parameter(Mandatory = $true)]$linenumber
    )
    $hash = [ordered]@{}

    $valueObj = ConvertFrom-StringData -Delimiter ':' -StringData $value
    
    # If no value it is a key, return hash
    if (!($($valueObj.values) -eq "")) { 
    
    switch -regex ($($valueObj.Values)) {
        # Looks for quotes in the start, denotes a text value
        '^"(.*)"[\s]*$' {
            $valueObj = @{$($valueObj.Keys[0]) = $Matches[1]}
            #$hash.add($($valueObj.Keys[0]),$Matches[1])
            break
        }
        # Find '- "value1" - value2' if there are quotes around the value then they are removed
        '^-(.*)$' {
            #$hash.add($($valueObj.Keys[0]),$Matches[1].split('- ').replace('"','').Trim())
            $valueObj = @{$($valueObj.Keys[0]) = $Matches[1].split('- ').replace('"','').Trim()}
            break
        }
        # Find '| some text in one line possibly with \n and paragraphs \n\n in the text' keep it all
        '^\|[\s](.*)$' {
            $hash.add($($valueObj.Keys[0]), $matches[1])            
            break
        }
        # Find '
        '^[\s]*\[(.*)\][/s]*$' {
            #$hash.add($($valueObj.Keys[0]), $matches[1].split(',').replace('"',''))
            $array = $matches[1] | convertfrom-json
            $valueObj = @{$($valueObj.Keys[0]) = $array}
            break
        }
        '^>(.*)$' {
            throw "> not supported yet, check line $linenumber"
        }
        default{
            try {
                $valueObj = @{$($valueObj.Keys[0]) = [int]$($valueObj.Values) } 
                Write-host "after the try"
                #$test22 = [int]$($valueObj.Values)
                #return $valueOjb
            }
            catch {
                # Not overwritign hash 
            }
        }
    }
<#  switch -regex ($valueObj[$valueObj.keys][0]) {
        # Find '   test: - "value1" - "value2"'
        #'[\s]*[\S]+:[\s]+-[\s]+.*' {
        '^[\s]+-[\s]+.*' {
            #write-host "first-matches: $($matches[0])"
            [System.Collections.ArrayList] $key = @()
            [System.Collections.ArrayList] $newvalue = @()
            #write-host "key with list"
            $key = $matches[0].substring($whitespace) -replace '[ ""]',''
            $newvalue = $key[1].split("-")
            $newvalue.removeat(0)
            #for ($i = 1; $i -lt $array2.Length; $i++ ){
            #    $array3.add($array2[$i].replace('"',''))
            #}
            #write-host "matches: $matches"
            $hash.add($key[0], $newvalue)
            break
        }
        # Find '    key: | this is a \n new text'
        #'[\s]*[\S]+:[\s]+\|.*' {
        '^[\s]+\|.*' {
            #write-host "second-matches: $($matches[0])"
            [System.Collections.ArrayList] $key = @()
            #write-host "key with list"
            $key = $matches[0].substring($whitespace).split("|") #-replace '[]',''
            #for ($i = 1; $i -lt $array2.Length; $i++ ){
            #    $array3.add($array2[$i].replace('"',''))
            #}
            #write-host "matches: $matches"
            $hash.add($key[0], $key[1].TrimStart())
            break
        }
        # Find '    key: > this\n is\n\n a \n new text'
        # Need to fix this one
        #'[\s]*[\S]+:[\s]+>.*' {
        '^[\s]+>.*' {
            #write-host "second-matches: $($matches[0])"
            [System.Collections.ArrayList] $key = @()
            [System.Collections.ArrayList] $newvalue = @()
            #write-host "key with list"
            $key = $matches[0].substring($whitespace).split(">") #-replace '[]',''
            $temp = $key[1].replace('\n\n',';NL-repLACE;')
            $temp = $temp.replace('\\n',';inlNL-repLACE;')
            $temp = $temp.replace('\n','')
            $temp = $temp.replace(';NL-repLACE;','\n')
            #$temp = $temp.replace(';inlNL-repLACE;','\\n')
            $hash.add($key[0], $temp)
            break
        }
        # Find '    test: {value1,value2}'
        #'[\s]*[\S]+:[\s]+{.*' {
        '^[\s]+{.*' {
            #write-host "third-matches: $($matches[0])"
            [System.Collections.ArrayList] $key = @()
            [System.Collections.ArrayList] $newvalue = @()
            #write-host "key with list"
            $key = $matches[0].substring($whitespace).split(":") -replace '[ "{}"]',''
            $newvalue = $key[1].split(",")
            #$newvalue.removeat(0)
            #for ($i = 1; $i -lt $array2.Length; $i++ ){
            #    $array3.add($array2[$i].replace('"',''))
            #}
            #write-host "matches: $matches"
            $hash.add($key[0], $newvalue)
            break
        }
        # Find '      key: "value"'
        #'[\s]*[\S]+:[\s]+[\S]+.*' {
        '^[\s]+[\S]+.*' {
            #write-host "fourth-matches: $($matches[0])"
            [System.Collections.ArrayList] $key = @()
            [System.Collections.ArrayList] $newvalue = @()
            #write-host "key with list"
            $key = $matches[0].substring($whitespace).split(":") -replace '[ ""]',''
            #for ($i = 1; $i -lt $array2.Length; $i++ ){
            #    $array3.add($array2[$i].replace('"',''))
            #}
            #write-host "matches: $matches"
            $hash.add($key[0], $key[1])
            break
        }
        # Find '   key: ' 
        #'[\s]*[\S]+:[\s]*'{
        '^[\s]*'{
            #write-host "lastmatches: $($matches[0])"
            #write-host "Heading (key)"
            $array = $matches[0].substring($whitespace).split(":")
            $hash.add($array[0],"")
            break
        }
        default{ write-host "No match"}
    } #>
    }
    return $valueObj
}

#[ test: testing, testing: one ]
#- test: testing
#  testing: one
#[ test, teset2, test3 ]
# { test: testing, what: blah}

#$test = '  SubscriptionContext: s5   --asdløkfkjjsdf'
#$test = '  SubscriptionContext:     "- test - test2 - test3"'
#$test = '  SubscriptionContext:     -     te  ,st - te   st2       - test3'
#$test = '  SubscriptionContext: 1'
#$test = ' fsfdsdf: | sdfsdf sdf sdf sdf sdf\n asdfsdaf\n\n sdfsdf'
#$test = ' fsfdsdf: > sdfsdf\n sdf sd\\nf sdf sdf\n asdfsdaf\n\n sdfsdf'
#$test = ' Key1: [ "some vaøaskdjføksdjflue", "another value" ]'
#$valueObj = ConvertFrom-StringData -Delimiter ':' -stringdata $test
$output = get-splittedvalue -value $test -linenumber 10

function new-helpIndex {
    param (
        [Parameter(Mandatory = $true)]$data
    )
    $multiline = $false
    $firstInline = $null
    $helpIndexDirty = @()
    # Looping through data and creating help index
    for($i =0; $i -lt $data.Length; $i++ ) {
        $indent = 0
        $whitespace = 0
        # Ignore is default (if only whitespaces)
        $vartype = "ignore"
        for($n =0; $n -lt $data[$i].Length; $n++ ) {
            if ($data[$i][$n] -eq " ") {
                $indent++
                $whitespace++
            } else {
                if ($data[$i][$n] -eq "-" -and $data[$i][$n+1] -eq " ") { # Should look for more than one space. Need to fix this
                    $vartype = "arrayStart"
                    $indent += 2
                } elseif ($data[$i][$n] -eq "#") {
                    #$dataList.RemoveAt($i)
                    $vartype = "ignore"
                } else {
                    $vartype = "dictionary"
                }
                break
            }
        }
        # Checking if line is part of multiline:
        if ($multiline) {
            if (!$firstInline) {
                $firstInline = $i
            }
            if ( $whitespace -ge $helpIndexDirty[$firstInline].whitespace ) {
                $vartype = "multiline"
            } else {
                $multiline = $false
                $firstInline = $null
            }
        }
        else {
            for($n =$data[$i].length -1; $n -ge 0; $n-- ) {
                if ($data[$i][$n] -eq "|" -or $data[$i][$n] -eq ">") {
                    $multiline = $true
                } elseif ($data[$i][$n] -eq " ") {
                    continue
                }
                break
            }
        }
        $helpIndexDirty += [PSCustomObject]@{
            Indent      = $indent
            whitespace = $whitespace
            vartype    = $vartype 
            lineNumber = $i
        }
    }
    $helpIndexDirty
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
    for($i = $data.count -1; $i -ge 0; $i-- ) {
        if ($helpIndex[$i].vartype -eq "multiline") {
            if ($helpIndex[$i-1].vartype -eq "multiline") {
                $currentMvalue = $($data[$i-1].substring($helpIndex[$i].whitespace))
            } else {
                $currentMvalue = $($data[$i-1])
            }
            if ($mValue) {     
                $mValue = "$currentMvalue" + '\n' + "$mValue"
            } else {
                $mValue = "$currentMvalue" + '\n' + "$($data[$i])"
            }
            [void]$data.RemoveAt($i)
            [void]$helpIndex.RemoveAt($i)
        } else {
            if($mValue) {
                $data[$i] = $mValue
                $mValue = $null
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
                throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). While parsing a block mapping, found multipe types"
            }
        } elseif ( -not ($data[$i] -Match "^[\s]*[\S]+.*:[\s]*[\S]*")) {
            # If key does not contain value on line, allow vaule on next line
            # Space after semicolon not required
            throw "Error on line $($helpIndex[$i].lineNumber), $($inputDataDirty[$($helpIndex[$i].lineNumber)]). While scanning a simple key, could not find key name or ':'"
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
    $vartype = $($helpIndex[$startRow+1]).vartype
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

                    $value = get-splittedvalue -value $($inputData[$blockLine]) -whitespace $helpIndex[$blockLine].whitespace
                    if($value.values -and $value.values -ne ""){
                        throw "Error, contains value: $($value.values)"
                    } else {
                        # Adding value from sub block:
                        $returnedObject =Get-ParsedTree -inputData $inputData -helpIndex $helpIndex -startRow $blockLine -endRow $($blockLine + $subBlockCount)
                        $hash.Add($($value.keys),$returnedObject)
                    }

                } else {
                    # Does not contain sub block. $vaule.value should contain the value.
                    $value = get-splittedvalue -value $($inputData[$blockLine]) -whitespace $helpIndex[$blockLine].whitespace
                    if ($($helpIndex[$blockLine]).vartype -eq "dictionary") {
                        $hash += $value
                    } elseif (($($helpIndex[$blockLine]).vartype -eq "arrayStart")) {
                        
                        # Getting all lines that should be included in the element before adding it to the array
                        for ($arrayLine = $blockLine+1; $arrayLine -lt $endRow; $arrayLine++) {
                            if ($($helpIndex[$arrayLine]).vartype -eq "arrayStart" -or $($helpIndex[$arrayLine]).Indent -ne $($helpIndex[$blockLine]).Indent) {
                                break
                            } else {
                                $valueNext = get-splittedvalue -value $($inputData[$arrayLine]) -whitespace $helpIndex[$arrayLine].whitespace
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
        ####Write-Host "runnign"
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

            $value = get-splittedvalue -value $($inputDataClean[$i]) -whitespace $helpIndexClean[$i].whitespace
            # Do we need to double check if children if key contains string?
            if($value.values -and $value.values -ne ""){
                $returnedObject = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow $i -endRow $($endRow)
                $hash.Add($value)
            } else {
                $returnedObject = Get-ParsedTree -inputData $inputDataClean -helpIndex $helpIndexClean -startRow $i -endRow $($endRow)
                $hash.Add($($value.keys),$returnedObject)
            }
        }
    }
    $hash
}