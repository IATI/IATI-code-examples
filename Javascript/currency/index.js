const fs = require("fs");

// A function to fetch data from a datastore JSON object with ambiguous multi-value
const fetch_field = (datastore_object, field_name, default_return = "") => {
  const result = datastore_object[field_name] || default_return;
  if (Array.isArray(result)) {
    return result[0];
  } else {
    return result;
  }
};

const main = () => {
  const csv_file = fs.readFileSync("../data/rates_06_07_2022.csv", "utf-8");
  let header = [];
  let rates = [];
  csv_file.split("\n").forEach((row, i) => {
    if (i === 0) {
      header = row.split(",");
    } else {
      let cell_obj = {};
      row.split(",").forEach((cell, j) => {
        const cell_name = header[j];
        cell_obj[cell_name] = cell;
      });
      cell_obj.Date = Date.parse(cell_obj.Date);
      cell_obj.Rate = parseFloat(cell_obj.Rate);
      rates.push(cell_obj);
    }
  });
  const rates_date = Date.parse("2022-07-06");

  // Load sample transactions
  const transactions_file = fs.readFileSync("../data/sample_transactions.json");
  let transactions = JSON.parse(transactions_file).response.docs;
  transactions.forEach((transaction, i) => {
    const default_currency = fetch_field(transaction, "default_currency");
    let currency = fetch_field(transaction, "transaction_value_currency");
    if (currency === "") {
      currency = default_currency; // Default currency if explicit is not available
    }
    let transaction_value_date = fetch_field(
      transaction,
      "transaction_value_value_date"
    );
    const transaction_iso_date = fetch_field(
      transaction,
      "transaction_transaction_date_iso_date"
    );
    if (transaction_value_date === "") {
      // Try to use canonical value date, as the standard specifies this is the date to be used for conversion
      // But failing that, use the transaction date
      transaction_value_date = transaction_iso_date;
    }
    const transaction_value = fetch_field(transaction, "transaction_value");
    if (
      (transaction_value !== "") &
      (currency !== "") &
      (transaction_value_date !== "")
    ) {
      transaction_value_date = Date.parse(transaction_value_date.substr(0, 10));
      const rate = rates.filter((rate) => {
        return (
          (rate.Date === transaction_value_date) & (rate.Currency === currency)
        );
      });
      if (rate.length > 0) {
        const transaction_value_usd = transaction_value * rate[0].Rate;
        transactions[i]["transaction_value_usd"] = transaction_value_usd;
      } else {
        console.log(
          `Warning: No exchange rate found for ${currency} on ${transaction_value_date}`
        );
      }
    }
  });

  // Load sample budgets
  const budgets_file = fs.readFileSync("../data/sample_budgets.json");
  let budgets = JSON.parse(budgets_file).response.docs;
  budgets.forEach((budget, i) => {
    const default_currency = fetch_field(budget, "default_currency");
    let currency = fetch_field(budget, "budget_value_currency");
    if (currency === "") {
      currency = default_currency; // Default currency if explicit is not available
    }
    let budget_value_date = fetch_field(budget, "budget_value_value_date");
    let budget_period_start = fetch_field(
      budget,
      "budget_period_start_iso_date"
    );
    let budget_period_end = fetch_field(budget, "budget_period_end_iso_date");
    const budget_value = fetch_field(budget, "budget_value");
    // Try conversion with budget value date first, as is canonical conversion date
    if (
      (budget_value !== "") &
      (currency !== "") &
      (budget_value_date !== "")
    ) {
      budget_value_date = Date.parse(budget_value_date.substr(0, 10));
      // Check whether budget value is in the bounds of our rates
      if (budget_value_date <= rates_date) {
        const rate = rates.filter((rate) => {
          return (
            (rate.Date === budget_value_date) & (rate.Currency === currency)
          );
        });
        if (rate.length > 0) {
          const budget_value_usd = budget_value * rate[0].Rate;
          budgets[i]["budget_value_usd"] = budget_value_usd;
        } else {
          console.log(
            `Warning: No exchange rate found for ${currency} on ${budget_value_date}`
          );
        }
      }
    } else if (
      (budget_value !== "") &
      (currency !== "") &
      (budget_period_start !== "") &
      (budget_period_end !== "")
    ) {
      // Failing to find budget value date, use the period average for budget period
      budget_period_end = Date.parse(budget_period_end.substr(0, 10));
      // Check whether budget period end is in the bounds of our rates
      if (budget_period_end <= rates_date) {
        budget_period_start = Date.parse(budget_period_start.substr(0, 10));
        const rates_to_average = rates
          .filter((rate) => {
            return (
              (rate.Currency === currency) &
              (rate.Date >= budget_period_start) &
              (rate.Date <= budget_period_end)
            );
          })
          .map((rate) => {
            return rate.Rate;
          });
        if (rates_to_average.length > 0) {
          const average_rate =
            rates_to_average.reduce((a, b) => a + b, 0) /
            rates_to_average.length;
          const budget_value_usd = budget_value * average_rate;
          budgets[i]["budget_value_usd"] = budget_value_usd;
        } else {
          console.log(
            `Warning: No exchange rate found for ${currency} on ${budget_value_date}`
          );
        }
      }
    }
  });

  return { transactions: transactions, budgets: budgets };
};

module.exports = {
  main: main,
  fetch_field: fetch_field,
};
