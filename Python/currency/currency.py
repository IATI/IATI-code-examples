import csv
import json
import statistics
from datetime import datetime

# A function to fetch data from a datastore JSON object with ambiguous multi-value
def fetch_field(datastore_object, field_name, default_return=""):
    result = datastore_object.get(field_name, default_return)
    if type(result) is list:
        return result[0]
    else:
        return result

def main(file_path, data_type="transaction"):
    with open("../data/rates_06_07_2022.csv", "r") as csv_file:
        csv_reader = csv.DictReader(csv_file)
        rates = list(csv_reader)
    rates_date = datetime.strptime("2022-07-06", "%Y-%m-%d")
    for i in range(0, len(rates)):
        rates[i]["Date"] = datetime.strptime(rates[i]["Date"], "%Y-%m-%d")
        rates[i]["Rate"] = float(rates[i]["Rate"])

    if data_type == "transaction":
        with open(file_path, "r") as transactions_file:
            transactions = json.load(transactions_file)["response"]["docs"]
        
            # Iterate and convert transactions
            for i in range(0, len(transactions)):
                transaction = transactions[i]
                default_currency = fetch_field(transaction, "default_currency")
                currency = fetch_field(transaction, "transaction_value_currency")
                if currency == "":
                    currency = default_currency # Default currency if explicit is not available
                transaction_value_date = fetch_field(transaction, "transaction_value_value_date")
                transaction_iso_date = fetch_field(transaction, "transaction_transaction_date_iso_date")
                if transaction_value_date == "":
                    # Try to use canonical value date, as the standard specifies this is the date to be used for conversion
                    # But failing that, use the transaction date
                    transaction_value_date = transaction_iso_date
                transaction_value = fetch_field(transaction, "transaction_value")
                if transaction_value != "" and currency != "" and transaction_value_date != "":
                    transaction_value_date = datetime.strptime(transaction_value_date[0:10], "%Y-%m-%d")
                    try:
                        rate = [rate["Rate"] for rate in rates if rate["Date"] == transaction_value_date and rate["Currency"] == currency][0]
                        transaction_value_usd = transaction_value * rate
                        transactions[i]["transaction_value_usd"] = transaction_value_usd
                    except IndexError:
                        print("Warning: No exchange rate found for {} on {}".format(currency, transaction_value_date))
        return transactions

    if data_type == "budget":
        with open(file_path, "r") as budgets_file:
            budgets = json.load(budgets_file)["response"]["docs"]
        
            # Iterate and convert budgets
            for i in range(0, len(budgets)):
                budget = budgets[i]
                default_currency = fetch_field(budget, "default_currency")
                currency = fetch_field(budget, "budget_value_currency")
                if currency == "":
                    currency = default_currency # Default currency if explicit is not available
                budget_value_date = fetch_field(budget, "budget_value_value_date")
                budget_period_start = fetch_field(budget, "budget_period_start_iso_date")
                budget_period_end = fetch_field(budget, "budget_period_end_iso_date")
                budget_value = fetch_field(budget, "budget_value")
                # Try conversion with budget value date first, as is canonical conversion date
                if budget_value != "" and currency != "" and budget_value_date != "":
                    budget_value_date = datetime.strptime(budget_value_date[0:10], "%Y-%m-%d")
                    # Check whether budget value is in the bounds of our rates
                    if budget_value_date <= rates_date:
                        try:
                            rate = [rate["Rate"] for rate in rates if rate["Date"] == budget_value_date and rate["Currency"] == currency][0]
                            budget_value_usd = budget_value * rate
                            budgets[i]["budget_value_usd"] = budget_value_usd
                        except IndexError:
                            print("Warning: No exchange rate found for {} on {}".format(currency, budget_value_date))
                elif budget_value != "" and currency != "" and budget_period_start != "" and budget_period_end != "":
                    # Failing to find budget value date, use the period average for budget period
                    budget_period_end = datetime.strptime(budget_period_end[0:10], "%Y-%m-%d")
                    # Check whether budget period end is in the bounds of our rates
                    if budget_period_end <= rates_date:
                        budget_period_start = datetime.strptime(budget_period_start[0:10], "%Y-%m-%d")
                        rates_to_average = [
                            rate["Rate"] for rate in rates if rate["Currency"] == currency and
                            rate["Date"] >= budget_period_start and
                            rate["Date"] <= budget_period_end
                        ]
                        if len(rates_to_average) > 0:
                            average_rate = statistics.mean(rates_to_average)
                            budget_value_usd = budget_value * average_rate
                            budgets[i]["budget_value_usd"] = budget_value_usd
                        else:
                            print("Warning: No exchange rate found for {} on {}".format(currency, budget_value_date))
        return budgets

if __name__ == '__main__':
    main("../data/sample_transactions.json", "transaction")
    main("../data/sample_budgets.json", "budget")