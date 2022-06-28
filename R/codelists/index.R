# Programmatically require libraries
list.of.packages <- c("data.table", "jsonlite", "httr", "XML", "tidyr", "reshape2", "stringr", "here")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)

# Set working directory
wd = here()
setwd(wd)
rm(list.of.packages, new.packages, wd)

# Set version to 2.03 and language to English
VERSION = "2.03"
LANGUAGE = "en"
STANDARD = "activity"

# A function to convert xpath names to Datastore field names
convertNameToCanonical = function(xpath) {
  retval = xpath
  retval = gsub("//iati-activities/", "", retval)
  retval = gsub("//iati-activity/", "", retval)
  retval = gsub("//iati-organisations/", "", retval)
  retval = gsub("//iati-organisation/", "", retval)
  retval = gsub("//@", "", retval)
  retval = gsub("/text()", "", retval, fixed=T)
  if(startsWith(retval, "@")){
    retval = substr(retval, 2, nchar(retval))
  }
  retval = gsub("/@", "@", retval)
  retval = gsub("-", "_", retval)
  retval = gsub(":", "_", retval)
  retval = gsub("/", "@", retval)
  retval = gsub("@", "_", retval)
  
  return(retval)
}
convertNameToCanonical = Vectorize(convertNameToCanonical)


# Pull in codelist mapping in XML
mapping_list = list()
mapping_url = paste0(
  "https://raw.githubusercontent.com/IATI/IATI-Codelists/version-",
  VERSION,
  "/mapping.xml"
)
mapping_content = content(GET(mapping_url))
mapping_xml = xmlParse(mapping_content)
mappings = getNodeSet(mapping_xml,"/mappings/mapping")
for(i in 1:length(mappings)){
  mapping = mappings[[i]]
  path = xmlValue(getNodeSet(mapping, "./path")[[1]])
  codelist = xmlAttrs(getNodeSet(mapping, "./codelist")[[1]])[["ref"]]
  condition_node = getNodeSet(mapping, "./condition")
  if(length(condition_node) == 0){
    condition = NA
  }else{
    condition = xmlValue(condition_node[[1]])
  }
  mapping_list[[i]] = data.frame(path, codelist, condition)
}
mapping_df = rbindlist(mapping_list)
mapping_df$datastore_name = convertNameToCanonical(mapping_df$path)
# Special case
mapping_df$datastore_name[which(mapping_df$path=="//iati-activities/@version")] = "dataset_version"


# Find unique codelists and download
cl_list = list()
unique_codelists = unique(mapping_df$codelist)
cl_count = 1
pb = txtProgressBar(max=length(unique_codelists), style=3)
for(codelist in unique_codelists){
  setTxtProgressBar(pb, cl_count)
  codelist_url = paste0(
    "https://cdn.iatistandard.org/prod-iati-website/reference_downloads/",
    gsub(".","",VERSION,fixed=T),
    "/codelists/downloads/clv3/json/",
    LANGUAGE,
    "/",
    codelist,
    ".json"
  )
  tmp_codelist_df = fromJSON(codelist_url)$data
  tmp_codelist_df$codelist = codelist
  cl_list[[cl_count]] = tmp_codelist_df
  cl_count = cl_count + 1
}
close(pb)
codelist_df = rbindlist(cl_list, fill=T)

codelist_df$name[which(is.na(codelist_df$name))] = codelist_df$code[which(is.na(codelist_df$name))]

# Split out conditional and unconditional mappings
unconditional_mappings = subset(mapping_df, is.na(condition))
conditional_mappings = subset(mapping_df, !is.na(condition))
conditional_mappings$path = as.character(conditional_mappings$path)
conditional_mappings$condition = as.character(conditional_mappings$condition)

# A function to remove attributes from xpath
stripAttributePath = function(xpath){
  split_xpath = strsplit(xpath, split="/")[[1]]
  if(startsWith(split_xpath[length(split_xpath)], "@")){
    split_xpath = split_xpath[c(1:(length(split_xpath)-1))]
  }
  return(paste(split_xpath, collapse="/"))
}
stripAttributePath = Vectorize(stripAttributePath)

# A function to fetch parent xpaths
parentPath = function(xpath, generations=1){
  split_xpath = strsplit(xpath, split="/")[[1]]
  split_xpath = split_xpath[c(1:(length(split_xpath)-generations))]
  return(paste(split_xpath, collapse="/"))
}
parentPath = Vectorize(parentPath)

conditional_mappings$condition_path = stripAttributePath(conditional_mappings$path)
conditional_mappings$condition_path[which(startsWith(conditional_mappings$condition, ".."))] = parentPath(
  conditional_mappings$condition_path[which(startsWith(conditional_mappings$condition, ".."))]
)
conditional_mappings = separate(conditional_mappings, col="condition", sep=" or ", into=c("condition_1", "condition_2"))
cm_melt = melt(conditional_mappings, measure.vars=c("condition_1", "condition_2"), value.name = "condition")
cm_melt$variable = NULL
cm_melt = subset(cm_melt, !is.na(condition))
cm_melt$condition_attribute = str_extract(cm_melt$condition, regex("@(\\w)+"))
cm_melt$condition_value = gsub("(=|\\s|')","",str_extract(cm_melt$condition, regex("= '.+'")))
cm_melt$condition = NULL
cm_melt$condition_path = paste(cm_melt$condition_path, cm_melt$condition_attribute, sep="/")
cm_melt$condition_attribute = NULL
cm_melt$condition_datastore_name = convertNameToCanonical(cm_melt$condition_path)
cm_melt = cm_melt[,c("codelist", "path", "datastore_name", "condition_datastore_name", "condition_value")]
unconditional_mappings = unconditional_mappings[,c("codelist", "path","datastore_name")]
joined_mappings = rbindlist(list(unconditional_mappings, cm_melt), fill=T)
joined_mappings$path = as.character(joined_mappings$path)
if(STANDARD=="activity"){
  joined_mappings = subset(
    joined_mappings,
    startsWith(path, "//iati-activity") | startsWith(path, "//iati-activities") | startsWith(path, "//@xml:lang")
  )
}else{
  joined_mappings = subset(
    joined_mappings,
    startsWith(path, "//iati-organisation") | startsWith(path, "//iati-organisations") | startsWith(path, "//@xml:lang")
  )
}

sample_data = fromJSON("data/sample.json", simplifyDataFrame = F)$response$docs
for(i in 1:length(sample_data)){
  row = sample_data[[i]]
  for(j in 1:length(row)){
    value_codes = row[[j]]
    field_name = names(row)[j]
    if(field_name %in% joined_mappings$datastore_name){
      jm_sub = subset(joined_mappings, datastore_name==field_name)
      if(nrow(jm_sub)==1 && is.na(jm_sub$condition_datastore_name)){
        # Unconditional
        cl_sub = subset(codelist_df, codelist==jm_sub$codelist, select=c("code", "name"))
        cl_sub = rbind(cl_sub, data.frame(code="", name=""))
        value_names = merge(data.frame(code=value_codes), cl_sub, by="code")$name
        sample_data[[i]][[j]] = as.character(value_names)
      }else{
        # Conditional
        conditional_datastore_name = unique(jm_sub$condition_datastore_name)
        cond_compare_values = row[[conditional_datastore_name]]
        if(length(cond_compare_values) == 0){
          cond_compare_values = rep(NA, length(sample_data[[i]][[j]]))
        }
        for(k in 1:length(cond_compare_values)){
          if(is.na(cond_compare_values[k]) || cond_compare_values[k]==""){
            jm_sub = subset(jm_sub, is.na(condition_value))
          }else{
            jm_sub = subset(jm_sub, condition_value==cond_compare_values[k])
          }
          if(nrow(jm_sub) == 0){
            next; # No codelist for this dependent value
          }
          cl_sub = subset(codelist_df, codelist==jm_sub$codelist, select=c("code", "name"))
          cl_sub = rbind(cl_sub, data.frame(code="", name=""))
          value_code = sample_data[[i]][[j]][[k]]
          value_name = merge(data.frame(code=value_code), cl_sub, by="code")$name
          if(length(value_name) > 0){
            sample_data[[i]][[j]][[k]] = as.character(value_name)
          }else{
            throw()
            warning(paste(value_code, "is not in codelist", jm_sub$codelist))
          }
        }
      }
    }
  }
}