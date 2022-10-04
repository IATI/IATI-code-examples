list.of.packages <- c("data.table","dotenv", "httr", "dplyr", "jsonlite")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)
rm(list.of.packages,new.packages)

# Make sure to add your API_KEY to a .env file for this to function
load_dot_env()
api_key = Sys.getenv("API_KEY")

publisher_id = "wbtf"

registry_url = paste0(
  "https://iatiregistry.org/api/3/action/package_search?rows=1000&q=organization:",
  publisher_id
)

registry_res = content(GET(registry_url))

res_count = registry_res$result$count

stopifnot(res_count < 1000)

registry_dataset_list = list()
registry_dataset_index = 1
for(dataset in registry_res$result$results){
  tmp = data.frame(id=dataset$id, name=dataset$name)
  registry_dataset_list[[registry_dataset_index]] = tmp
  registry_dataset_index = registry_dataset_index + 1
}

registry_datasets = rbindlist(registry_dataset_list)

validation_list = list()
validation_index = 1

pb = txtProgressBar(max=nrow(registry_datasets), style=3)

for(i in 1:nrow(registry_datasets)){
  setTxtProgressBar(pb, i)
  registry_dataset = registry_datasets[i,]
  dataset_name = registry_dataset$name
  validator_api_url = paste0(
    "https://api.iatistandard.org/validator/report?showerrors=true&id=",
    registry_dataset$id
  )
  req = GET(
    URLencode(validator_api_url),
    add_headers(`Ocp-Apim-Subscription-Key` = api_key)
  )
  res = content(req)
  activities = res$report$errors
  for(activity in activities){
   activity_title = activity$title
   activity_id = activity$identifier
   activity_error_cats = activity$errors
   for(activity_error_cat in activity_error_cats){
     error_category = activity_error_cat$category
     errors = activity_error_cat$errors
     for(error in errors){
       error_id = error$id
       error_severity = error$severity
       error_message = error$message
       error_context = error$context[[1]]$text
       tmp = data.frame(
         dataset_name,
         activity_title,
         activity_id,
         category=error_category,
         severity=error_severity,
         id=error_id,
         message=error_message,
         context=error_context
       )
       validation_list[[validation_index]] = tmp
       validation_index = validation_index + 1
     }
   }
  }
}

close(pb)

all_validation = rbindlist(validation_list)
fwrite(all_validation,paste0("~/", publisher_id, "_all_validation.csv"))
