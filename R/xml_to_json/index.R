# Programmatically require libraries
list.of.packages <- c("data.table", "jsonlite", "XML", "here")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)

# Set working directory
wd = here()
setwd(wd)
rm(list.of.packages, new.packages, wd)

recursiveJsonNest = function(element, output){
  elementName = xmlName(element)
  if(elementName != "text"){
    elementList = list()
    elementAttrs = xmlAttrs(element)
    for(attrKey in names(elementAttrs)){
      elementList[[paste0("@", attrKey)]] = elementAttrs[[attrKey]]
    }
    elementChildren = xmlChildren(element)
    for(child in elementChildren){
      elementList = recursiveJsonNest(child, elementList)
    }
    if(elementName %in% names(output)){
      childCount = length(output[[elementName]])
      output[[elementName]][[childCount + 1]] = elementList
    }else{
      output[[elementName]][[1]] = elementList
    }
  }else{
    elementText = trimws(xmlValue(element))
    if(elementText != ""){
      output[["text()"]] = elementText
    }
  }
  
  return(output)
}

root = xmlRoot(xmlParse("data/sample.xml"))
output = recursiveJsonNest(root, list())

jsonString = toJSON(output,pretty=TRUE,auto_unbox=TRUE)


stopifnot(
  (output[['iati-activities']][[1]][['iati-activity']][[1]][['iati-identifier']][[1]][['text()']] == 'DAC-1601-INV-003731'),
  (output[['iati-activities']][[1]][['iati-activity']][[1]][['default-flow-type']][[1]][['@code']] == '30')
)
