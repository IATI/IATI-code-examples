const libxml = require("libxmljs2");
const axios = require("axios");
const fs = require("fs");

// Set version to 2.03 and language to English
const VERSION = "2.03";
const LANGUAGE = "en";
const STANDARD = "activity";

// A function to convert xpath names to Datastore field names
const convertNameToCanonical = (xpath) => {
  retval = xpath.replace("//iati-activities/", "");
  retval = retval.replace("//iati-activity/", "");
  retval = retval.replace("//iati-organisations/", "");
  retval = retval.replace("//iati-organisation/", "");
  retval = retval.replace("//@", "");
  retval = retval.replace("/text()", "");
  if (retval.startsWith("@")) {
    retval = retval.substring(1);
  }
  retval = retval.replace("/@", "@");
  retval = retval.replace(/-/g, "_");
  retval = retval.replace(/:/g, "_");
  retval = retval.replace(/\//g, "@");
  retval = retval.replace(/@/g, "_");
  return retval;
};

// A function to remove attributes from xpath
const stripAttributePath = (xpath) => {
  split_xpath = xpath.split("/");
  if (split_xpath[split_xpath.length - 1].substring(0, 1).startsWith("@")) {
    split_xpath.pop();
  }
  return split_xpath.join("/");
};

// A function to fetch parent xpaths
const parentPath = (xpath, generations = 1) => {
  split_xpath = xpath.split("/");
  for (var i = 0; i < generations; i += 1) {
    split_xpath.pop();
  }
  return split_xpath.join("/");
};

const main = async (filePath) => {
  // Pull in codelist mapping in XML
  const mapping_list = [];
  const mapping_url = `https://raw.githubusercontent.com/IATI/IATI-Codelists/version-${VERSION}/mapping.xml`;
  const mapping_content = await axios.get(mapping_url);
  const mapping_xml = libxml.parseXml(mapping_content.data).root();
  const mappings = mapping_xml.find("/mappings/mapping");
  mappings.forEach((mapping) => {
    const path = mapping.find("./path")[0].text();
    if (
      ((STANDARD === "activity") &
        (path.startsWith("//iati-activity") |
          path.startsWith("//iati-activities") |
          path.startsWith("//@xml:lang"))) |
      ((STANDARD === "organisation") &
        (path.startsWith("//iati-organisation") |
          path.startsWith("//iati-organisations") |
          path.startsWith("//@xml:lang")))
    ) {
      const codelist = mapping.find("./codelist/@ref")[0].value();
      const condition_nodes = mapping.find("./condition");
      if (condition_nodes.length === 0) {
        const mapping_dict = {
          path: path,
          codelist: codelist,
          datastore_name: convertNameToCanonical(path),
        };
        if (path === "//iati-activities/@version") {
          mapping_dict["datastore_name"] = "dataset_version"; // Special case
        }
        mapping_list.push(mapping_dict);
      } else {
        const condition_string = condition_nodes[0].text();
        let parent_condition_path = stripAttributePath(path);
        if (condition_string.startsWith("..")) {
          parent_condition_path = parentPath(parent_condition_path);
        }
        const conditions = condition_string.split(" or ");
        conditions.forEach((condition) => {
          const condition_attribute = condition.match(/@\w+/g)[0];
          const condition_value_match = condition.match(/= '.+'/g);
          let condition_value = "";
          if (condition_value_match) {
            condition_value = condition_value_match[0]
              .replace(/'/g, "")
              .replace("= ", "");
          }
          const condition_path = `${parent_condition_path}/${condition_attribute}`;
          const mapping_dict = {
            path: path,
            codelist: codelist,
            datastore_name: convertNameToCanonical(path),
            condition_datastore_name: convertNameToCanonical(condition_path),
            condition_value: condition_value,
          };
          mapping_list.push(mapping_dict);
        });
      }
    }
  });

  const cl_list = [];
  const cl_list_promises = [];
  const unique_codelists = Array.from(
    new Set(
      mapping_list.map((m) => {
        return m.codelist;
      })
    )
  );

  unique_codelists.forEach((codelist) => {
    const codelist_url = `https://cdn.iatistandard.org/prod-iati-website/reference_downloads/${VERSION.replace(
      ".",
      ""
    )}/codelists/downloads/clv3/json/${LANGUAGE}/${codelist}.json`;
    const axios_promise = axios.get(codelist_url).then((res) => {
      const codelist_json = res.data.data;
      codelist_json.forEach((cl_d) => {
        cl_d.codelist = codelist;
        if (!Object.keys(cl_d).includes("name")) {
          cl_d.name = cl_d.code;
        }
        cl_list.push(cl_d);
      });
    });
    cl_list_promises.push(axios_promise);
  });

  // Apply codelists to data
  const sample_data = await Promise.all(cl_list_promises).then(() => {
    const sample_data_file = fs.readFileSync(filePath);
    let sample_data = JSON.parse(sample_data_file).response.docs;
    sample_data.forEach((row, i) => {
      const field_names = Object.keys(row);
      field_names.forEach((field_name) => {
        const new_field_name = `${field_name}_recode`;
        let value_codes = row[field_name];
        if (
          mapping_list
            .map((mapping) => {
              return mapping.datastore_name;
            })
            .includes(field_name)
        ) {
          let mapping_subset = mapping_list.filter((mapping) => {
            return mapping.datastore_name === field_name;
          });
          if (
            (mapping_subset.length == 1) &
            !Object.keys(mapping_subset[0]).includes("condition_datastore_name")
          ) {
            // Unconditional
            const codelist_subset = cl_list.filter((codelist_item) => {
              return codelist_item.codelist === mapping_subset[0].codelist;
            });
            codelist_subset.push({ code: "", name: "" });
            let value_names = [];
            const value_codes_is_array = Array.isArray(value_codes);
            if (!value_codes_is_array) {
              value_codes = [value_codes];
            }
            value_codes.forEach((value_code) => {
              const value_name_comp = codelist_subset.filter((cl_item) => {
                return cl_item.code == value_code;
              });
              if (value_name_comp.length > 0) {
                value_names.push(value_name_comp[0].name);
              } else {
                value_names.push(value_code);
                console.log(
                  `Warning: ${value_code} is not in codelist ${mapping_subset[0].codelist}`
                );
              }
            });
            if (value_codes_is_array) {
              sample_data[i][new_field_name] = value_names;
            } else {
              sample_data[i][new_field_name] = value_names[0];
            }
          } else {
            // Conditional
            const conditional_datastore_name =
              mapping_subset[0].condition_datastore_name;
            let cond_compare_values = Array(row[field_name].length - 1).fill(
              ""
            );
            if (Object.keys(row).includes(conditional_datastore_name)) {
              cond_compare_values = row[conditional_datastore_name];
            }
            if (!Array.isArray(cond_compare_values)) {
              cond_compare_values = [cond_compare_values];
            }
            const original_is_array = Array.isArray(row[field_name]);
            if (!original_is_array) {
              row[field_name] = [row[field_name]];
            }
            cond_compare_values.forEach((cond_compare_value, j) => {
              mapping_subset = mapping_subset.filter((mapping) => {
                return mapping.condition_value == cond_compare_value;
              });
              if (mapping_subset.length > 0) {
                // No codelist for this conditional value if 0
                const codelist_subset = cl_list.filter((codelist_item) => {
                  return codelist_item.codelist === mapping_subset[0].codelist;
                });
                codelist_subset.push({ code: "", name: "" });
                const value_code = row[field_name][j];
                const value_name_comp = codelist_subset.filter((cl_item) => {
                  return cl_item.code == value_code;
                });
                let value_name = value_code;
                if (value_name_comp.length > 0) {
                  value_name = value_name_comp[0].name;
                } else {
                  console.log(
                    `Warning: ${value_code} is not in codelist ${mapping_subset[0].codelist}`
                  );
                }
                if (original_is_array) {
                  if (!Object.keys(sample_data[i]).includes(new_field_name)) {
                    sample_data[i][new_field_name] =
                      sample_data[i][field_name].slice();
                  }
                  sample_data[i][new_field_name][j] = value_name;
                } else {
                  sample_data[i][new_field_name] = value_name;
                }
              }
            });
          }
        }
      });
    });
    return sample_data;
  });

  return sample_data;
};

module.exports = main;
