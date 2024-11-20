$manifest = Import-LocalizedData -FileName powerAPS.psd1

write-host "Importing module: " -NoNewLine
write-host "powerAPS $($manifest.ModuleVersion)" -foregroundcolor Magenta