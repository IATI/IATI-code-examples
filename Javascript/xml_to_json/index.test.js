const { main } = require("./index");

test("sample XML conversion to JSON", () => {
  const results = main("../data/sample.xml");
  expect(results['iati-activities'][0]['iati-activity'][0]['iati-identifier'][0]['text()']).toBe('DAC-1601-INV-003731');
  expect(results['iati-activities'][0]['iati-activity'][0]['default-flow-type'][0]['@code']).toBe('30');
});
