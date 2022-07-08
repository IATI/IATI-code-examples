const { main, fetch_field } = require("./index");

test("sample data values to be recoded", () => {
  const transaction_results = main("../data/sample_transactions.json", "transaction");
  const budget_results = main("../data/sample_budgets.json", "budget");
  expect(fetch_field(transaction_results[69], "transaction_value")).toBe(
    200000
  );
  expect(fetch_field(transaction_results[69], "transaction_value_usd")).toBe(
    286800
  );
  expect(fetch_field(budget_results[29], "budget_value")).toBe(200000);
  expect(fetch_field(budget_results[29], "budget_value_usd")).toBe(282940);
});
