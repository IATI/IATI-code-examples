const main = require("./index");

test("sample data values to be recoded", async () => {
  await main('../data/sample.json').then((sample_data) => {
    expect(sample_data[0]["transaction_provider_org_type"][0]).toBe(
      "60"
    );
    expect(
      sample_data[0]["transaction_provider_org_type_recode"][0]
    ).toBe("Foundation");
    expect(sample_data[0]["dataset_version"]).toBe("2.03");
    expect(sample_data[0]["dataset_version_recode"]).toBe("2.03");
  });
});
