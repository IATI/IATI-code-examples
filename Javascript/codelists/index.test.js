const main = require("./index");

test("sample data values to be recoded", async () => {
  await main('../data/sample.json').then((sample_data) => {
    expect(sample_data[0]["country_budget_items_budget_item_code"][0]).toBe(
      "5.1.1"
    );
    expect(
      sample_data[0]["country_budget_items_budget_item_code_recode"][0]
    ).toBe("Health - policy, planning and administration");
    expect(sample_data[0]["dataset_version"]).toBe("2.03");
    expect(sample_data[0]["dataset_version_recode"]).toBe("2.03");
  });
});
