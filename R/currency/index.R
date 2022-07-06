# Programmatically require libraries
list.of.packages <- c("data.table", "jsonlite", "here")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)

# Set working directory
wd = here()
setwd(wd)
rm(list.of.packages, new.packages, wd)

stat_mode = function(vector){
  v_tab = table(vector)
  v_tab = v_tab[order(-v_tab)]
  return(
      names(v_tab)[1]
  )
}

rate_list = list()
exchange_rate_url = "http://dataservices.imf.org/REST/SDMX_JSON.svc/CompactData/IFS/M..EDNA_USD_XDC_RATE"
ex_rate_sdmx = fromJSON(exchange_rate_url)
series = ex_rate_sdmx$CompactData$DataSet$Series
for(i in 1:nrow(series)){
  combination = series[i,]
  area = combination$`@REF_AREA`
  obs = data.frame(combination$Obs)
  obs$REF_AREA = area
  rate_list[[i]] = obs
}
rate_df = rbindlist(rate_list, fill=T)

currency_codes = fread("data/currency_codes.csv", na.strings = "")
currency_codes = currency_codes[,c("iso_a2", "cc")]
setnames(currency_codes, "iso_a2", "REF_AREA")

rate_df_x = merge(rate_df, currency_codes, by="REF_AREA")
setdiff(unique(rate_df$REF_AREA), unique(rate_df_x$REF_AREA))
rate_df_x$X.OBS_VALUE[which(rate_df_x$cc=="USD")] = 1 # Enforce USD = 1 for countries with historic changes
rate_df_x$year = as.numeric(substr(rate_df_x$X.TIME_PERIOD, 1, 4))
rate_df_x = subset(rate_df_x, !(cc=="EUR" & year < 1999)) # Ignore EUR prior to 1999
rate_df_x = rate_df_x[,c("cc","X.TIME_PERIOD","X.OBS_VALUE")]
names(rate_df_x)=c("cc","month","value")
# dups = rate_df_x[which(duplicated(rate_df_x[,c("cc","X.TIME_PERIOD")])),]
# dups_count = dups[,.(count=length(unique(X.OBS_VALUE))),by=c("cc","X.TIME_PERIOD")]
# dups_count = subset(dups_count, count > 1)
unique_rates = rate_df_x[,.(value=stat_mode(value)), by=.(cc, month)]
unique_rates$value = as.numeric(unique_rates$value)
