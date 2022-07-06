const { main, fetch_field } = require('./index');

test('sample data values to be recoded', () => {
    const results = main();
    expect(fetch_field(results.transactions[69], "transaction_value")).toBe(200000);
    expect(fetch_field(results.transactions[69], "transaction_value_usd")).toBe(286800);
    expect(fetch_field(results.budgets[29], "budget_value")).toBe(200000);
    expect(fetch_field(results.budgets[29], "budget_value_usd")).toBe(282940);
});