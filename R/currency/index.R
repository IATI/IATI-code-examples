# Programmatically require libraries
list.of.packages <- c("data.table", "jsonlite", "here")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only=T)

# Set working directory
wd = here()
setwd(wd)
rm(list.of.packages, new.packages, wd)

# Derived from https://www.imf.org/external/np/fin/ert/GUI/Pages/CountryDataBase.aspx
rates = fread("data/rates_06_07_2022.csv")
rates_date = as.Date("2022-07-06")

# Load sample transactions
transactions = fromJSON("data/sample_transactions.json", simplifyDataFrame = F)$response$docs

# Iterate and convert transactions
for(i in 1:length(transactions)){
  transaction = transactions[[i]]
  default_currency = transaction[["default_currency"]]
  currency = transaction[["transaction_value_currency"]]
  if(length(currency) == 0){
    currency = default_currency # Default currency if explicit is not available
  }
  transaction_value_date = transaction[["transaction_value_value_date"]]
  transaction_iso_date = transaction[["transaction_transaction_date_iso_date"]]
  if(length(transaction_value_date) == 0){
    # Try to use canonical value date, as the standard specifies this is the date to be used for conversion
    # But failing that, use the transaction date
    transaction_value_date = transaction_iso_date
  }
  transaction_value = transaction[["transaction_value"]]
  if(
    length(transaction_value) > 0 &
    length(currency) > 0 &
    length(transaction_value_date) > 0
  ){ # Ensure all necessary values are present before attempting to convert
    transaction_value_date = as.Date(substr(transaction_value_date, 1, 10))
    rate = rates$Rate[which(rates$Currency == currency & rates$Date == transaction_value_date)]
    transaction_value_usd = transaction_value * rate
    transactions[[i]][["transaction_value_usd"]] = transaction_value_usd
  }
}

# Load sample budgets
budgets = fromJSON("data/sample_budgets.json", simplifyDataFrame = F)$response$docs

# Iterate and convert budgets
for(i in 1:length(budgets)){
  budget = budgets[[i]]
  default_currency = budget[["default_currency"]]
  currency = budget[["budget_value_currency"]]
  if(length(currency) == 0){
    currency = default_currency # Default currency if explicit is not available
  }
  budget_value_date = budget[["budget_value_value_date"]]
  budget_period_start = budget[["budget_period_start_iso_date"]]
  budget_period_end = budget[["budget_period_end_iso_date"]]
  budget_value = budget[["budget_value"]]
  # Try conversion with budget value date first, as is canonical conversion date
  if(
    length(budget_value) > 0 &
    length(currency) > 0 &
    length(budget_value_date) > 0
  ){
    # Check whether budget value is in the bounds of our rates
    budget_value_date = as.Date(substr(budget_value_date, 1, 10))
    if(budget_value_date <= rates_date){
      rate = rates$Rate[which(rates$Currency == currency & rates$Date == budget_value_date)]
      budget_value_usd = budget_value * rate
      budgets[[i]][["budget_value_usd"]] = budget_value_usd
    }
  # Failing to find budget value date, use the period average for budget period
  }else if(
    length(budget_value) > 0 &
    length(currency) > 0 &
    length(budget_period_start) > 0 &
    length(budget_period_end) > 0
  ){
    # Check whether budget period end is in the bounds of our rates
    budget_period_end = as.Date(substr(budget_period_end, 1, 10))
    if(budget_period_end <= rates_date){
      budget_period_start = as.Date(substr(budget_period_start, 1, 10))
      rate_subset = rates$Rate[which(
        rates$Currency == currency &
          rates$Date >= budget_period_start &
          rates$Date <= budget_period_end
        )]
      average_rate = mean(rate_subset) # Take the daily average for the period
      budget_value_usd = budget_value * average_rate
      budgets[[i]][["budget_value_usd"]] = budget_value_usd
    }
  }
}

stopifnot(
  (transactions[[70]][["transaction_value"]] == 200000),
  (transactions[[70]][["transaction_value_usd"]] == 286800),
  (budgets[[30]][["budget_value"]] == 200000),
  (budgets[[30]][["budget_value_usd"]] == 282940)
)
